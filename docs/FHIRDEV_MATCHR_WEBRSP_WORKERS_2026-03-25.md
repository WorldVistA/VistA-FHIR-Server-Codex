# fhirdev: `%webrsp` `MATCHR` worker accumulation (2026-03-25)

## Purpose

This note **characterizes** a live observation on **`fhirdev.vistaplex.org`**: multiple **`mumps -direct`** HTTP workers spending large amounts of CPU in **`MATCHR+8^%webrsp`** (and briefly in **`URLDEC^%webutils`**) while the **`%webreq`** listener on **port 9080** remains active.

It complements:

- **`docs/FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`** — malicious root persistence (separate issue) and introduction of the `%webreq` worker leak
- **`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`** — server-side disconnect / `WAIT` / `ETDC` strategy so workers close sockets and exit
- **`docs/M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`** — `%webrsp` **`SENDATA`** global-traversal runaway (different code path)

---

## Classification

| Aspect | Characterization |
|--------|------------------|
| **Layer** | M Web Server stack: **`%webreq`** (listener) and **`%webrsp`** / **`%webutils`** (workers) |
| **Not** | Reinfection by the **2026-03-16** `/tmp`-style malicious binaries (those were identifiable by path, cron, and ELF artifacts) |
| **Not** | Primary evidence of bugs in **`C0FHIR`** application routines — ZSY showed workers still in **routing / URL handling**, not in `GETFHIR^C0FHIR` or similar |
| **Relationship to CLOSE_WAIT leak** | Same **family** of failure: **workers that do not finish and exit**, so process count and CPU grow under load. Whether **`MATCHR`** is a *symptom* of half-dead sockets, pathological URLs, or an internal loop in **`%webrsp`** requires source-level follow-up alongside socket lifecycle fixes |

---

## Environment

- **Host:** `fhirdev.vistaplex.org`
- **Container:** `fhirdev`
- **VistA user:** `vehu`
- **Listener:** `http://127.0.0.1:9080` (`BG-S9080` in ZSY)

---

## OS-level picture (same session)

From **`ps`** inside the container (representative):

- **`mumps -dir`** on a **`pts/*`** terminal — interactive programmer
- **`mumps -direct`** with **`PPID 1`**, state **`R`**, **~25–41% CPU each** — reparented worker processes typical of the web stack
- Count on the order of **eight to ten** such workers while the listener remained up

This aligns with **GT.M System Status** below: many **`BG-0`** jobs are **`mumps -direct`** workers, not the **`BG-S9080`** listener.

---

## Evidence: GT.M System Status (ZSY)

Stats reflect the **DEFAULT** region only (ZSY banner).

### Snapshot A — 25-MAR-26 19:10:33

```text
PID   PName   Device       Routine            Name                CPU Time OP/READ   NTR/NTW        NR0123    #L   %LSUCC  %CFAIL
441   mumps   /dev/pts/6   INTRPTALL+8^ZSY    PROGRAMMER,ONE      00:00:00 99.07     12k/0k         0/0/0/0   1    1/1     0.00%
447   mumps   BG-S9080     LOOP+19^%webreq                        00:00:00 75.00     152/2          0/0/0/0   0    0/0     0/5
461   mumps   BG-0         MATCHR+8^%webrsp                       00:07:13 0.00      8/1            0/0/0/0   0    1/1     0/1
471   mumps   BG-0         MATCHR+8^%webrsp                       00:06:35 0.00      8/1            0/0/0/0   0    1/1     0/2
491   mumps   BG-0         URLDEC+4^%webutils                     00:06:08 0.00      8/1            0/0/0/0   0    1/1     0/2
493   mumps   BG-0         MATCHR+8^%webrsp                       00:06:06 0.00      8/1            0/0/0/0   0    1/1     0/2
651   mumps   BG-0         MATCHR+8^%webrsp                       00:03:15 2.00      8/1            0/0/0/0   0    1/1     0/5
669   mumps   BG-0         URLDEC^%webutils                       00:02:58 0.00      8/1            0/0/0/0   0    1/1     0/2
687   mumps   BG-0         MATCHR+8^%webrsp                       00:02:02 2.00      8/1            0/0/0/0   0    1/1     0/5
697   mumps   BG-0         URLDEC+6^%webutils                     00:01:48 0.00      8/1            0/0/0/0   0    1/1     0/2
```

**Total:** 10 users (processes).

### Snapshot B — 25-MAR-26 19:20:53 (~10 minutes later)

```text
PID   PName   Device       Routine            Name                CPU Time OP/READ   NTR/NTW        NR0123    #L   %LSUCC  %CFAIL
441   mumps   /dev/pts/6   INTRPTALL+8^ZSY    PROGRAMMER,ONE      00:00:00 99.10     12k/0k         0/0/0/0   1    1/1     0.00%
447   mumps   BG-S9080     LOOP+19^%webreq                        00:00:00 55.00     240/318        0/0/0/0   0    0/0     0.00%
461   mumps   BG-0         MATCHR+8^%webrsp                       00:09:37 0.00      8/1            0/0/0/0   0    1/1     0/1
471   mumps   BG-0         MATCHR+8^%webrsp                       00:08:59 0.00      8/1            0/0/0/0   0    1/1     0/2
491   mumps   BG-0         MATCHR+8^%webrsp                       00:08:33 0.00      8/1            0/0/0/0   0    1/1     0/2
493   mumps   BG-0         MATCHR+8^%webrsp                       00:08:31 0.00      8/1            0/0/0/0   0    1/1     0/2
651   mumps   BG-0         MATCHR+8^%webrsp                       00:05:39 2.00      8/1            0/0/0/0   0    1/1     0/5
669   mumps   BG-0         MATCHR+8^%webrsp                       00:05:22 0.00      8/1            0/0/0/0   0    1/1     0/2
687   mumps   BG-0         MATCHR+8^%webrsp                       00:04:26 2.00      8/1            0/0/0/0   0    1/1     0/5
697   mumps   BG-0         MATCHR+8^%webrsp                       00:04:12 0.00      8/1            0/0/0/0   0    1/1     0/2
1349  mumps   BG-0         MATCHR+8^%webrsp                       00:00:59 0.00      8/1            0/0/0/0   0    1/1     0/2
1405  mumps   /dev/pts/4   +1^GTM$DMOD        PROGRAMMER,ONE      00:00:00 19.13     621/3          0/0/0/0   0    1/1     0/36
1414  mumps   BG-0         MATCHR+8^%webrsp                       00:00:20 0.00      8/1            0/0/0/0   0    1/1     0/2
```

---

## Interpretation

1. **Listener (447)** — **`LOOP+19^%webreq`** on **`BG-S9080`** is the **9080** accept loop. Low **CPU Time** on the listener itself is normal; **OP/READ** and **NTR/NTW** changed between snapshots (**152/2** → **240/318**), consistent with **ongoing connection and traffic** while workers remain stuck.

2. **Workers (`BG-0`)** — Almost all show **`MATCHR+8^%webrsp`**: time is being spent in the **HTTP route matcher** in **`%webrsp`**, before (or instead of) dispatch into application code such as **`C0FHIR`**.

3. **Pipeline shift (A → B)** — In snapshot **A**, three workers were in **`URLDEC*`^`%webutils`**; in **B**, those PIDs had moved to **`MATCHR+8^%webrsp`**. So the same jobs progressed from **URL decoding** into **route matching** and **remained there**.

4. **Monotonic CPU on stable PIDs** — **CPU Time** on **461–697** rose by roughly **two minutes** over **~10 minutes** wall time, i.e. **sustained CPU use**, not idle waiting on I/O at the M level (ZSY still attributes the current PC to **`MATCHR`**).

5. **Growth of worker set** — New PIDs **1349** and **1414** appeared, both in **`MATCHR+8^%webrsp`**. The older workers had **not** exited. That is **accumulation** under continued requests.

6. **Programmer rows** — **441** (`ZSY` on **pts/6**) and **1405** (`GTM$DMOD` on **pts/4**) are **interactive sessions**, not part of the HTTP worker leak. The **`%CFAIL`** column on **1405** is a **cache** statistic for that session; interpret with ZSY/version documentation.

---

## Hypotheses (for engineering follow-up)

These are **not** mutually exclusive:

1. **Socket / lifecycle** — Workers tied to **client disconnects** or **keep-alive** edge cases never reach **`ETDC`** / clean **`HALT`**, and remain in request processing (here, visible as **`MATCHR`**). This is the same **problem class** as the **CLOSE_WAIT** outline.

2. **Pathological input** — Certain **URLs or headers** cause **expensive or non-terminating** behavior inside **`MATCHR`** (table size, pattern matching, or logic bug).

3. **Concurrency** — Multiple overlapping slow matches amplify CPU; the **listener** keeps accepting connections (**NTR/NTW** rises) while old workers stay alive.

**Next step if `MATCHR` persists after WAIT/ETDC fixes:** inspect **`%webrsp`** at **`MATCHR+8`**, route registration globals, and reproduce with a minimal **`curl`** request set.

---

## Operational mitigation

- **Immediate relief:** In a **mumps** session as the container VistA user, run **`d stop^%webreq`** then **`d go^%webreq`** (see **`docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`** listener section). Expect **worker PIDs to drop**; clients may see brief errors during the restart.
- **Structural mitigation:** Track **`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`** (trial section and validation checklist).

---

## Incident summary (one paragraph)

On **2026-03-25**, **`fhirdev`** showed a **pile of `mumps -direct` processes** spending **large CPU times** in **`MATCHR+8^%webrsp`**, with the **9080** listener still in **`LOOP+19^%webreq`**. Earlier workers had passed through **`URLDEC^%webutils`** and then **stalled in `MATCHR`**. New workers **continued to appear** while old ones **remained**. This pattern **characterizes** a **%webreq/%webrsp worker lifecycle and routing** problem, **not** a **`C0FHIR`** regression and **not** the **March 2026** malware chain. **Restarting the listener** clears the pile temporarily; **closing the socket lifecycle gaps** (and, if needed, **auditing `MATCHR`**) addresses the underlying issue.
