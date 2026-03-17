# M Web Server CLOSE_WAIT Leak — Fix Outline (2026-03-16)

This note outlines the fix strategy for the **server-side CLOSE_WAIT leak** in `%webreq` / `%webrsp`: workers that do not close their side of the socket after the client disconnects, so they remain in CLOSE_WAIT and consume CPU.

It complements the earlier analysis in `M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md` (which addressed the SENDATA global-traversal leak) and the incident log in `FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`.

---

## 1. Observed state (post–incident check)

- **Sockets**: Multiple connections in **CLOSE_WAIT** on port `9080` (client has closed; server side still open).
- **Processes**: Several `mumps -direct` workers with high CPU (~28–67%), long runtimes (hours), and `PPID=1`.
- **FHIR**: Endpoint still returns `200` when hit directly on `9080`, but worker count grows over time.
- **Conclusion**: Clients are closing; the server-side worker is **not** closing the socket and exiting, so the OS keeps the connection in CLOSE_WAIT and the worker keeps running (likely in a read or retry loop).

---

## 2. Root cause (refined)

- When the **client closes first**, the TCP connection moves to **CLOSE_WAIT** on the server.
- The worker may be:
  - in **WAIT** (`R TCPX:10`), waiting for the next request on a keep-alive connection, and the read may not immediately return an error or EOF when the client has closed; or
  - stuck in another path (e.g. a read loop or error path) that never runs `C %WTCP` and `HALT`.
- So the worker never closes its side of the socket and never exits, and the connection stays in CLOSE_WAIT while the process keeps using CPU.

---

## 3. Fix strategy (outline)

### 3.1 Already in place (on fhirdev at time of incident)

- **Connection: close**: Server sends `Connection: close` and, after sending the response, the worker takes the existing “exit on close” path: `C %WTCP` and `HALT`. That prevents **new** keep-alive reuse on that connection; it does not by itself fix workers already stuck in WAIT or in a read loop after a client disconnect.
- **SENDATA**: Subtree-boundary fix in `%webrsp` (non-gzip and gzip) so traversal does not leak due to empty-string nodes.
- **Error trap ETSOCK**: On device error (e.g. socket error), control goes to `ETSOCK^%webreq`, which does `C %WTCP` and `HALT`. So if the platform raises an error on read when the client has closed, the worker should exit. If the read blocks or returns “empty” without raising, the worker may not hit ETSOCK.

### 3.2 Gaps to address

1. **WAIT / read loop**
   - In **WAIT**, after `R TCPX:10`:
     - If `'$T` (timeout) and we have already sent at least one response on this connection, treat as “client likely idle or gone”: **close and exit** (go to ETDC: `C %WTCP`, `HALT`) instead of looping to NEXT.
     - If `'$L(TCPX)` and we expected a request line, treat as **EOF / disconnect**: go to ETDC.
   - Optionally **shorten** the wait timeout (e.g. 5–10 seconds) for the “next request” read so we don’t hold the connection indefinitely; on timeout, close and exit.

2. **Explicit disconnect handling**
   - Ensure that any code path that detects “no data” or “connection closed” (e.g. zero-length read, or platform-specific socket status) goes to the same cleanup as ETDC: `K ^TMP($J)`, `C %WTCP`, `HALT`, so the worker always closes its side and exits.

3. **Platform behavior**
   - Confirm on GT.M/YottaDB whether a read on a socket in CLOSE_WAIT returns immediately with 0 bytes or error, or blocks. If it blocks, the above timeout is essential so we don’t leave workers stuck in `R TCPX:10` forever.

---

## 4. Code locations (reference)

All in **`%webreq`** (routine `_webreq.m` in the M Web Server):

| Label / area   | Purpose |
|----------------|--------|
| **CHILD**      | Entry for each worker; sets device, then `G NEXT`. |
| **NEXT**       | Top of per-request loop; clears request/response. |
| **WAIT**       | `R TCPX:10` — wait for first line of next request. Here we can add: on timeout or empty, if we’re in “next request” (already sent a response), go to ETDC. |
| **ETDC**       | “Error trap” for client disconnect: `C %WTCP`, `HALT`. Target for “client closed, we should exit.” |
| **ETSOCK**     | Device error trap: `C %WTCP`, `HALT`. Already correct; ensure it’s used for socket errors. |
| **Connection: close** | After `SENDATA`, check `HTTPREQ("header","connection")`; if "close" (or TRACE), run `C %WTCP` and `HALT`. Already present; ensures we don’t loop for “next request” when we’ve told the client we’re closing. |

No change required in **`%webrsp`** for this CLOSE_WAIT fix; the SENDATA and Connection header behavior are already as above.

---

## 5. Validation (after implementing)

1. **Baseline**: Restart listener; confirm only one `mumps -direct` (listener) and no CLOSE_WAIT sockets.
2. **Normal request**: `GET /fhir?dfn=...` with `Connection: close` — worker exits after response; no extra worker left in CLOSE_WAIT.
3. **Client closes first**: Open connection, send `GET /fhir?dfn=...`, then close client side before or during response; confirm server-side socket and worker disappear (no CLOSE_WAIT pile).
4. **Idle keep-alive**: If keep-alive is still used anywhere, open connection, send one request, then leave connection open without sending a second request; after the chosen timeout, confirm server closes and worker exits.

---

## 6. Trial on fhirdev (2026-03-17)

The following changes were applied to **source** on `fhirdev.vistaplex.org` in `/home/vehu/p/_webreq.m`:

1. **RDLEN** — On body-read timeout (`'$T`), **G ETDC^%webreq** instead of returning with partial body, so the worker closes the socket and exits instead of continuing with incomplete request state.
2. **WAIT** — First-line read timeout shortened from **10** to **5** seconds (`R TCPX:5 I '$T G ETDC`) so idle or closed connections release sooner.

**Limitation:** The container’s `_webreq.m` includes Cache-specific device syntax. GT.M/YottaDB fails to compile it (`DEVPARPARSE` / `JOBPARUNK` on Cache branches). The **running** process therefore still uses the **pre-existing object** (`/home/vehu/p/r2.00_x86_64/_webreq.o`). The patched source is in place for any future build that uses a GT.M-only (or otherwise compilable) copy of the routine; the object was left unchanged and kept newer than the source so restarts do not trigger a recompile and failure.

**Update:** User ran `ZLINK "_webreq"`, `stop^%webreq`, `go^%webreq`; the `.o` was replaced (recompile with warnings) and the listener restarted with the new object. RDLEN→ETDC and WAIT 5s are now active. **Leak continued** (e.g. 16 workers, 14 CLOSE_WAIT after browsing), so workers are likely stuck in another path: response write (SENDATA) or header read (RDCRLF) when the client has already closed.

---

## 7. Next steps (when leak continues after §6 fixes)

1. **RDCRLF** (`_webreq.m`) — Header read uses `R X:1` in a loop (up to 10 retries). On timeout with no data, treat as disconnect:
   - **Applied on fhirdev:** After the loop, `I RETRY>10,'$L(LINE) G ETDC^%webreq` so that if we spent 10 seconds with no header data (client closed), the worker closes and exits instead of returning `LINE=""` and continuing.
   - Optional: inside the loop, if `$T` and `$L(X)=0` (0-byte read = EOF), **G ETDC^%webreq**.

2. **SENDATA / device error** — When writing the response, if the client has closed, the **W** may block or retry instead of raising. Ensure the socket device has **ioerror="ETSOCK"** (already set in CHILD) so that any write failure (e.g. SIGPIPE / broken pipe) invokes ETSOCK and the worker does `C %WTCP` and HALT. If the platform does not deliver write errors to the process, consider a non-blocking or timeout write path, or closing the socket immediately after the last FLUSH and exiting so we don’t linger in a write loop.

3. **Processlog for stack** — To see where a stuck worker is, use `mupip intrpt <pid>` then read the interrupt stack. JOBEXAM stores it in `^%webhttp("processlog",+$H,$P($H,",",2),$J)`; the second subscript is seconds-of-day (numeric), not "". Use that when querying from M to avoid NULSUBSC.

4. **Operational — clearing runaway workers**  
   **Restarting the listener does not clear workers.** `stop^%webreq` only tells the listener process to stop; workers were JOB'd off and run under init (PPID=1), so they are not terminated. To clear the pile you must **kill the processes** from the OS, then start the listener again:
   - On fhirdev (from host):  
     `ssh root@fhirdev.vistaplex.org "docker exec fhirdev pkill -TERM -f 'mumps -direct'; sleep 2; docker exec fhirdev pkill -KILL -f 'mumps -direct'; sleep 1"`
   - Then start the listener (in an M session): `d go^%webreq`  
   Or from the container as root: `pkill -TERM -f "mumps -direct"`, wait, `pkill -KILL -f "mumps -direct"` if needed, then have vehu run `go^%webreq`.

---

## 8. References

- `docs/M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md` — SENDATA traversal leak and subtree-boundary fix.
- `docs/FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md` — Malware cleanup and CLOSE_WAIT / worker pile observation.
- M Web Server source (e.g. `_webreq.m`, `_webrsp.m`) — upstream or site-specific copy; fixes should be applied there and/or via KIDS/local patch. On fhirdev, ZLINK "_webreq" replaced the .o; see §6 and §7.
