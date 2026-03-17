# FHIRDEV Incident Response (2026-03-16)

## Purpose

This note records two separate issues observed on `fhirdev.vistaplex.org` while
preparing VEHU for fresh-patient validation:

- a root-level malicious process/persistence chain inside the `fhirdev`
  container
- a still-unresolved `%webreq` / `%webrsp` worker leak on port `9080`

The two issues are related operationally because both produce runaway CPU and
process accumulation, but they are technically distinct.

## Environment

- host: `fhirdev.vistaplex.org`
- container: `fhirdev`
- VistA user inside container: `vehu`
- FHIR listener: `http://127.0.0.1:9080`

## Malicious Process Finding

While investigating high CPU and "runaway jobs", two user-reported host PIDs
stood out:

- `773252`
- `773859`

These were **not** VistA or M web-server processes.

### What they were

On the host, both PIDs resolved to root-owned binaries inside the `fhirdev`
container:

```text
root 773252 ... /tmp/linux
root 773859 ... /tmp/linux
```

Container inspection also showed companion root-owned processes:

- `/tmp/linux`
- `/tmp/linux` (second copy/process)
- `/etc/kswpad`
- `/usr/bin/.sshd`

Observed file details:

```text
/tmp/linux                 ELF 32-bit LSB executable, statically linked
/etc/kswpad                ELF 32-bit LSB executable, statically linked
/usr/bin/.sshd             ELF 32-bit LSB executable, statically linked
/usr/lib/libgdi.so.0.8.2   ELF 64-bit LSB executable, statically linked, stripped
```

Observed hashes:

```text
25c34c028f0c119da251ca5d17020df79a030c7c3b86c5a8df699065016a21a2  /tmp/linux
6fddaa099096c0caee183e4bb95e9fe79003e6ae6dc41d6b1aa3b4aec221bd38  /etc/kswpad
6fddaa099096c0caee183e4bb95e9fe79003e6ae6dc41d6b1aa3b4aec221bd38  /usr/bin/.sshd
0ff23a77abba239a50412c720b2e423fcb3fb00e2362189cafa116eeb9bdce27  /usr/lib/libgdi.so.0.8.2
```

## Persistence Chain

The malicious files were being relaunched by cron.

### Cron persistence

`/etc/crontab` contained:

```text
*/1 * * * * root /.mod
```

### Launcher script

`/.mod` contained:

```bash
#!/bin/bash
/usr/lib/libgdi.so.0.8.2
```

So the persistence chain was:

1. cron runs `/.mod` every minute
2. `/.mod` executes `/usr/lib/libgdi.so.0.8.2`
3. additional companion binaries (`/tmp/linux`, `/etc/kswpad`, `/usr/bin/.sshd`)
   were present and running as root

## Remediation Performed

The following actions were performed inside the running `fhirdev` container:

1. removed the cron persistence entry from `/etc/crontab`
2. removed `/.mod`
3. removed `/tmp/linux`
4. removed `/etc/kswpad`
5. removed `/usr/bin/.sshd`
6. removed `/usr/lib/libgdi.so.0.8.2`
7. killed the live malicious processes

Post-cleanup verification showed:

- no remaining processes matching `/tmp/linux`
- no remaining processes matching `/etc/kswpad`
- no remaining processes matching `/usr/bin/.sshd`
- no remaining files at those paths

## FHIR Availability After Cleanup

After removing the malicious process chain:

- `GET http://127.0.0.1:9080/fhir` returned `200`
- `GET http://127.0.0.1:9080/fhir?dfn=101090` returned `200`

So the cleanup did not take down the VEHU FHIR service.

## Separate M Web Worker Leak

The FHIR listener still shows a separate issue on `9080`:

- `mumps -direct` workers under `PPID=1`
- several worker sockets in `CLOSE_WAIT`
- gradual regrowth after listener restart

Important distinction:

- the original `773252` / `773859` problem was **not** this leak
- those PIDs belonged to the malicious `/tmp/linux` processes
- the remaining `mumps -direct` pile is still a `%webreq` / `%webrsp` problem

## Current `%webrsp` Finding

The live non-gzip `SENDATA^%webrsp` code already contains the subtree-boundary
fix previously validated in `docs/M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`:

```mumps
. . . E  I $NA(@HTTPRSP,OL)'=$NA(@ORIG,OL) S HTTPEXIT=1
```

That means the earlier `$Q` traversal bug is **not** absent from the live code.
The current smaller leak pattern likely comes from a different path, with the
gzip branch and/or socket shutdown handling still under investigation.

## Post–sleep check (2026-03-16)

After the client side was closed overnight, a recheck of `fhirdev` showed:

- **Sockets**: One LISTEN on `9080`; **six connections in CLOSE_WAIT** (four from the user’s public IP, one from another client). So the clients had closed; the server-side workers had not.
- **Processes**: Seven `mumps -direct` (one listener, six workers) with high CPU (~28–67%) and long runtimes.
- **Conclusion**: The leak is **server-side**: workers do not close their side of the socket and exit when the client disconnects, so connections stay in CLOSE_WAIT and workers keep running.

A fix outline is documented in **`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`**: detect disconnect/timeout in the WAIT read loop, close the socket, and exit the worker (ETDC) so CLOSE_WAIT does not accumulate.

## Operational Takeaway

At this point there are two separate action tracks:

1. the malicious root-level persistence in the `fhirdev` container has been
   removed from the live runtime
2. the `%webreq` / `%webrsp` CLOSE_WAIT leak has an outlined fix in
   `docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md` (WAIT/ETDC and timeout handling)

Even though the live runtime was cleaned, this incident should be treated as a
container compromise. Rebuilding the container from a trusted image and
reviewing credentials / access paths is strongly recommended.
