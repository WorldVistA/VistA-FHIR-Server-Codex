# fhirdev22 fresh start — GT.M ZSY baseline snapshot (2026-03-27)

## Purpose

This note records a **baseline GT.M System Status (ZSY)** picture for the **current** VEHU FHIR host runtime after the **`fhirdev` → `fhirdev22`** cutover. Use it as a **fresh-start reference** when comparing against incident or regression snapshots (for example **`docs/FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md`**, which showed many **`MATCHR+8^%webrsp`** workers on the older container).

**What “fresh start” means here:** one **`%webreq`** listener on **`BG-S9080`**, **no** `%webrsp` **`MATCHR`** pile in ZSY, and the expected **TaskMan**, **Mailman/Postmaster**, and **HL7** long jobs visible—**not** a claim that the system is free of all background load (HL7 TCP readers may still show large cumulative **CPU Time**).

---

## Runtime context (same era as this snapshot)

Recorded from operational checks on **`fhirdev.vistaplex.org`** around **2026-03-27** (UTC):

| Item | State |
|------|--------|
| **Docker name `fhirdev`** | **Exited (137)** (not the live M instance for this baseline) |
| **Docker name `fhirdev22`** | **Running**; **`9080/tcp`** mapped for FHIR HTTP |
| **ZSY below** | Taken inside the **live** instance (**`fhirdev22`**), user **`vehu`**, DEFAULT region |

---

## Evidence: GT.M System Status (full table)

```text
PID   PName   Device       Routine            Name                CPU Time OP/READ   NTR/NTW        NR0123    #L   %LSUCC  %CFAIL
29    mumps   BG-0         IDLE+3^%ZTM        Taskman ROU 1       00:00:24 12640.98  617k/18k       1/0/0/0   0    99.96%  0.01%
124   mumps   BG-0         LOOP+7^HLCSLM      POSTMASTER          00:00:13 6728.44   460k/46k       0/0/0/0   2    100.00% 0.01%
126   mumps   BG-0         GO+12^XMTDT        POSTMASTER          00:00:15 768.85    40k/0k         1/0/0/0   2    37/37   0.00%
128   mumps   BG-0         GO+26^XMKPLQ       POSTMASTER          00:00:17 19594.55  383k/0k        1/0/0/0   2    9/9     0/32
130   mumps   BG-0         STARTIN+33^HLCSIN  POSTMASTER          00:00:22 8240.54   451k/10k       0/0/0/0   1    100.00% 0.00%
132   mumps   BG-0         STARTOUT+23^HLCSOUTPOSTMASTER          00:00:18 10450.43  143k/3k        0/0/0/0   1    100.00% 0.00%
445   mumps   /dev/pts/9   INTRPTALL+8^ZSY    PROGRAMMER,ONE      00:00:00 14.58     3840/122       0/0/0/0   1    9/9     0.00%
453   mumps   BG-S9080     LOOP+19^%webreq                        00:00:01 11714.00  11k/0k         0/0/0/0   0    0/0     0/3
3681  mumps   0            RDBLK+62^HLCSTCP1  HLs:5001-3681       16:22:39 0.00      164/11         0/0/0/0   0    11/11   0/11
4181  mumps   0            RDBLK+59^HLCSTCP1  HLs:5001-4181       15:23:31 0.00      164/11         0/0/0/0   0    11/11   0/11
4822  mumps   0            RDBLK+56^HLCSTCP1  HLs:5001-4822       14:24:30 0.00      164/11         0/0/0/0   0    11/11   0/11
11149 mumps   BG-0         GETTASK+3^%ZTMS1                       00:00:05 14056.17  165k/20k       1/0/0/0   1    99.99%  0.00%

Total 12 users.
```

---

## Role summary (baseline interpretation)

| PID | Routine / device | Role |
|-----|------------------|------|
| **29** | `IDLE+3^%ZTM`, `BG-0` | **TaskMan** main loop |
| **11149** | `GETTASK+3^%ZTMS1`, `BG-0` | **TaskMan submanager** |
| **126**, **128** | `XMTDT`, `XMKPLQ`, POSTMASTER | **Mailman** / Postmaster workload |
| **124** | `LOOP+7^HLCSLM` | **HL7** link manager |
| **130**, **132** | `HLCSIN`, `HLCSOUT` | **HL7** inbound / outbound starters |
| **3681**, **4181**, **4822** | `RDBLK^HLCSTCP1`, `HLs:5001-*` | **HL7 TCP** readers on logical link **5001** (high **CPU Time** in this capture—treat as “HL7 hot” signal, not FHIR HTTP) |
| **453** | `LOOP+19^%webreq`, **`BG-S9080`** | **FHIR / M Web Server HTTP listener on port 9080** |
| **445** | `ZSY` on `pts/9` | **Interactive** session (operator running ZSY) |

**Contrast with incident baseline:** In **`docs/FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md`**, multiple **`BG-0`** rows showed **`MATCHR+8^%webrsp`** (and some **`URLDEC^%webutils`**) with **rising CPU Time** while **`LOOP^%webreq`** stayed on **`BG-S9080`**. **This snapshot has no `MATCHR^%webrsp` rows**—that is the intended “clean HTTP worker” side of the fresh-start picture.

---

## How to use this document

1. **After container recycle or listener restart:** capture ZSY again and compare **row count**, presence of **`BG-S9080` `LOOP^%webreq`**, and absence of a **multi-row `MATCHR^%webrsp`** pattern.
2. **When HL7 is in scope:** use the **`HLCSTCP1` / `HLs:5001-*`** rows as the HL7 baseline; investigate link **5001** if counts or **CPU Time** diverge sharply from this reference without an explained traffic change.
3. **Runbooks:** prefer container name **`fhirdev22`** until **`fhirdev`** is intentionally restored or retired; older docs that only say **`fhirdev`** may mean the superseded instance.

---

## Related docs

- **`docs/FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md`** — prior **`fhirdev`** `%webrsp` **`MATCHR`** worker accumulation
- **`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`** — `%webreq` worker / socket lifecycle
- **`docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`** — SSH target, `docker cp`, `%webreq` restart commands (update container name to **`fhirdev22`** when following literally)
