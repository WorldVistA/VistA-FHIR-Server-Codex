# IRIS cohort load — error analysis and reload runbook (2026-09-10)

Analysis of the first 12-patient common-cohort load on `irisfhir.vistaplex.org`
(FOIA namespace), from the graph-store load log
`^%wd(17.040801,3,DFN,"load")` — 17,471 per-resource rows parsed from
182,861 log lines, dumped ~20:45 ET.

## Headline

**Encounters and labs were never broken.** All 1,400 Encounters and all
8,876 Labs filed with zero errors, on every patient. The visible mess was
four whole domains silently dropping — Procedures, outpatient Medications,
clinical Documents, CarePlan health factors — and all four trace to one root
cause: only `SYNWEBRG` of the 56-routine SYN family had been imported to
IRIS (found the same evening via the blank-note bug; fixed in `8a487a0`).

## Totals

| Outcome | Rows | Share |
|---|---:|---:|
| loaded | 12,637 | 72.3% |
| lost to missing SYN routines (**fixed**) | 4,162 | 23.8% |
| skipped by design | 429 | 2.5% |
| true mapping / reference-table gaps | 243 | 1.4% |

## Every distinct failure, by count

| Count | Domain | Log message | Actual root cause | Status |
|---:|---|---|---|---|
| 2,081 | Procedure | SYNDHP65 is not installed | routine never imported | fixed `8a487a0` |
| 1,217 | Medication | SYNFMED is not installed | routine never imported | fixed `8a487a0` |
| 806 | DocumentReference | "no text/plain attachment data" | **misleading** — data was present; `$$DECODE64^SYNWEBUT` missing, `DOCTEXT^C0FWTIU` silently returned `""` | fixed `8a487a0` + honest message (below) |
| 58 | CarePlan | SYNFHF is not installed | routine never imported | fixed `8a487a0` |
| 192 | Observation | Unable to map vital type | vital-sign map gaps | follow-up |
| 22 | Observation | intraocular pressure L/R (79892-6/79893-4) | no VistA vital type for IOP | decide: map or accept |
| 18 | Condition | no ICD-10/ICD-9 resolvable | SNOMED→ICD-10 map gaps (incl. the 4 from the Aaron697 load) | follow-up |
| 10 | Immunization | inactive in `^AUTTIMM` | FOIA table entries flagged inactive | activate entries |
| 275 | Medication | code companion; filing is on MedicationRequest | correct | by design |
| 152 | Condition | non-diagnosis, retained in fhir-intake | correct | by design |
| 3 | Allergy / SR | already filed (2) · missing SNOMED (1) | dedupe working + data edge | by design / edge |

Per-patient: every DFN lost the same four domains — systemic, not
patient-specific. (DFN 11/12 "error" counts are dominated by the
DocumentReference decode failures.)

## Hardening shipped before the reload (this commit)

1. **Honest missing-routine error** — `LOAD^C0FWTIU` now reports
   `SYNWEBUT is not installed; cannot decode DocumentReference attachment
   data` instead of blaming the data. The three filers that *named* their
   missing routine made this analysis instant; the one silent path cost a
   bug hunt.
2. **Read side can never blank again** — `$$B64^C0FHIR` now falls back to a
   pure-M RFC 4648 encoder (`$$ENC64`) when `SYNWEBUT` is absent. Verified
   byte-identical to `$$ENCODE64^SYNWEBUT` across all 256 byte values on
   IRIS.
3. **Pre-load dependency check** — `DEPCHK^C0FWDOM` runs once per load,
   before filing: any missing filer dependency (`SYNWEBUT`, `SYNFHF`,
   `SYNFMED`, `SYNDHP65`, `SYNDHP63`, `TIUSRVP`) lands as one loud
   `load.missingRoutines` line in the `/addpatient` response and as
   `..."load","_dependencies",<rtn>)="missing"` in the graph log. Advisory —
   filing proceeds; per-resource guards still record exact skips.
4. **Turnkey restore** — `scripts/iris-web-setup.sh` step 0 now re-imports
   the current Codex `src/*.m` from the workstation before registering
   routes (a snapshot restore reverts the container's routines), alongside
   the step-1c SYN import. The script also multiplexes ssh over one
   ControlMaster connection (the droplet runs `ufw limit 22/tcp`).

## Reload runbook (after restoring the pristine snapshot)

Restore **`irisfhir-pristine-cprs+fhir-2026-09-09`** — not either 2026-09-10
snapshot; those carry the half-loaded cohort and reloading over it risks
duplicate visits. Then:

```
# 1. Re-establish everything (Codex src, SYN set, routes, ^%webhome, listeners)
VistA-FHIR-Server-Codex/scripts/iris-web-setup.sh

# 2. Public edge (Caddy + TLS + rehmp UI)
VistA-FHIR-Server-Codex/scripts/iris-public-setup.sh

# 2b. Provider-capable filing user (data change — reverts with every restore).
#     The FOIA image has NO PROVIDER key holders and no person classes, so
#     $$USER^C0FWENC() falls back to DUZ=.5 and everything files as
#     POSTMASTER. Give USER,ONE (DUZ 1) the PROVIDER key + an active person
#     class so TIU/PCE file as a real user:
#       - file 200 PERSON CLASS multiple (200.05) entry w/ effective date
#       - ^XUSEC("PROVIDER",1)="" cross-reference
#     Verify: file a note, confirm ^TIU(8925,DA,12) piece 2 = 1 (not .5).

# 3. Load ONE patient first; check response meta has no load.missingRoutines,
#    then read its load log — Procedure / Medication / DocumentReference /
#    CarePlan domains should now file. First real runtime exercise of
#    SYNDHP65/SYNFMED on IRIS: budget for 1-2 portability bugs of the
#    $TEST/PIPE class before committing to all 12.
#    (load-cohort.sh with a single manifest, or the addpatient curl from
#     IRIS_SIXTH_LANE_2026-09-10.md; remember -H 'Expect:')

# 4. Full cohort + quality re-eval + smoke
HL7-FHIR-quality-testing/scripts/load-cohort.sh   # all 12
#    then REEVALJ^C0FQUAL per measure (TaskMan still unconfigured on IRIS)
VistA-FHIR-Server-Codex/scripts/iris-lane-smoke.sh   # 17 checks

# 5. Retake the droplet snapshot (all current snapshots predate the SYN
#    import, ^%webhome fix, and this hardening)
```

Expected next-load rate: ~97% (only the 243 mapping gaps and 429 by-design
skips remain).

## Evidence (rerunnable)

| Claim | Command |
|---|---|
| Load-log dump behind the numbers | `$QUERY` walk of `^%wd(17.040801,3)` filtered to `"load"` nodes (iris session) |
| ENC64 fallback byte-identical | iris session: compare `$$ENC64^C0FHIR` vs `$$ENCODE64^SYNWEBUT` over `$C(0)..$C(255)` |
| DEPCHK clean when all installed | iris session: `D DEPCHK^C0FWDOM(ROOT,1,.R)` → no `missingRoutines` |
| Note read-back intact | `curl 'https://irisfhir.vistaplex.org/fhir?dfn=11&format=json&refresh=1'` → 944-byte attachment |
| IRIS lane green | `scripts/iris-lane-smoke.sh` (17/17) |
| No GT.M regression | `QUALITY_DEPLOY_TARGETS=vehu10 scripts/deploy-quality-all.sh` (SMOKE OK) |

---

# Reload results (2026-09-11, after pristine-snapshot restore)

The runbook above was executed against a fresh restore of
`irisfhir-pristine-cprs+fhir-2026-09-09`. Outcome, same log, same counter:

| Outcome | Rows | Share |
|---|---:|---:|
| loaded | 8,474 | 48.6% |
| lab rows graph-only (`ISIIMP12` not installed — see below) | 7,172 | 41.1% |
| skipped by design (dedupe, code companions, non-diagnosis) | 1,794 | 10.3% |
| error | **29** | **0.17%** |

The 29 errors are all known mapping gaps: 18 Conditions with no resolvable
ICD-10 (same SNOMED map gaps as before), 10 Procedures on two unmapped SNOMED
codes (169690007 antenatal RhD screening, 167271000 urine protein), and 1
ServiceRequest with no SNOMED coding. **Every domain that was dead on 9/10
now files**: 2,071 Procedures, 804 DocumentReferences (TIU notes), 82
outpatient Medications (+1,410 correct dedupe/no-NDF skips), 54 CarePlan
health-factor sets. `load.missingRoutines` was empty on every POST.

All 804 TIU notes carry author DUZ 1 (USER,ONE) — the POSTMASTER (.5) filing
problem is gone.

Official-CQL re-eval (foreground `REEVALJ^C0FQUAL`, cds1, refresh=1)
reproduced the 9/10 numbers exactly:
CMS122v14 1/1/1 · CMS125v14 1/1/0 · CMS130v14 2/2/0 · CMS138v14 3/3/3 ·
CMS165v14 2/2/1 · CMS2v15 4/4/0. POP curated to IPP members afterward.

## What the pristine image was missing (all now in `iris-web-setup.sh`)

The 9/09 snapshot predates the whole 9/10 sixth-lane build-out. Each gap
found tonight is folded into the setup script so the *next* restore is one
command:

1. **`%WC` routine mapping** (`Config.MapRoutines` FOIA→FOIA) — without it
   `%WC.mac` import fails with "mapped from a database that you do not have
   write permission on" (step 0 now creates it).
2. **`C0SSL` TLS config** (`Security.SSLConfigs`) — needed by `%WC` for
   https calls to cds1 (step 0).
3. **rehmp `C0RG*` routines** — new step 1d imports them from the sibling
   `rehmp/C0RG` and re-registers routes (104 with rehmp, 100 without).
4. **`^C0FQUAL("FHIRBASE")`** — set in step 1d (must include `/fhir`).
5. **Loader environment init** — new step 1e mirrors `EN^SYNINIT` (KIDS-time
   init the GT.M fleet images got at build): creates the `SYNMENU` option
   (PROV points field 201 at it), synthetic provider + pharmacist,
   `IBACTION` (fixes IB ACTION TYPE 350.1 → required by the OUTPATIENT SITE
   field-1003 input transform), the pharmacy site, `ALBUL`, and
   `EN^SYNGBLLD` (builds the `^SYN("2002.030")` mapping globals —
   `sct2os5` is what `PRCADD^SYNDHP65` needs). Two SYNINIT steps are
   deliberately skipped on FOIA: `HL` (crashes in `VISN^SDTMPHLB`,
   `^DIC(4,1,7,1,0)` absent) and `ACRPBUL` (DIERR; bulletin noise only).
   Step 1e also makes USER,ONE provider-capable (runbook step 2b).

## Two portability bugs found and fixed (the predicted budget)

1. **`$ZS` in `DERR^C0FWDOM`** — `$ZS` is `$ZSTATUS` (error text) on GT.M
   but `$ZSTORAGE` (memory limit) on IRIS, so every trapped IRIS adapter
   error reported as `2147483647`. Now XECUTE-dispatched per platform
   (`$ZSTATUS` on GT.M, `$ZE` on IRIS).
2. **Kernel KILLs `RXN` under `FILEPS^C0FWMED`** — the PSO chain kills
   common local names; the med filer crashed at its own success-log line
   (`<UNDEFINED> *RXN`) *after* filing the Rx. Same class as the September
   sprint `LAST` bug; fixed by snapshotting into `C0FWSAV(...)` around the
   Kernel call.

Also fixed: `iris-public-setup.sh` now waits for unattended-upgrades to
release the dpkg lock (a freshly restored droplet holds it for minutes and
the Caddy install died silently), and multiplexes ssh like the web setup.

## ISI VistA DataLoader KIDS install (2026-09-11 evening)

Installed the **ISI VistA DataLoader 3.1** KIDS distribution
(`VistA-DataLoader/VistA/VISTA_DATALOADER_3P1.KID`, 663 KB, self-contained —
no required builds) so `$$LAB^ISIIMP12` (the engine `LABADD^SYNDHP63` calls)
is present. 77 `ISI*` routines, file #9001 (ISI PT IMPORT TEMPLATE), RPCs, and
options loaded; install status 3. Now folded into `iris-web-setup.sh` step 1f
(idempotent: skips when `ISIIMP12` is present).

The install is a normal two-step KIDS flow (`D ^XPDIL` load, `D ^XPDI`
install) with one IRIS-only prerequisite:

- **HOME device for a piped session.** A piped `iris session` runs on
  principal device `"00"`, which `HOME^%ZIS` resolves through the
  sign-on/virtual-terminal path — `^%ZIS(1,"G","SYS.<vol>.<$I>")` plus the
  device's field `TYPE="VTRM"`. The stock FOIA device file has no such entry,
  so KIDS aborts with `HOME DEVICE (00) DOES NOT EXIST IN THE DEVICE FILE`.
  Fix: file a virtual-terminal device (#3.5) with `$I="00"`, set its `TYPE`
  node to `VTRM`, and add the `G` cross-references (`SYS..00` and
  `SYS.PLA.00`). `HOME^%ZIS` then returns `POP=0`. Automated in step 1f.

Getting the lab import path to actually run then surfaced three more
IRIS-portability fixes (all shipped):

1. **SYN import needs two passes + first-line-label repair.** `SYNGRAPH`
   (first-line label `SYNFGRAPH`) and `SYNHTM` (`%yottahtm`) were UNENTERABLE
   on IRIS — GT.M keys a routine by filename, but IRIS needs the INT
   first-line label to equal the routine name, else `$$label^RTN` throws
   `<SUBSCRIPT>`/`<COMMAND>`. And several SYN routines only compile on a
   second `ImportDir` pass (inter-routine ordering). Step 1c now rewrites the
   first-line label to the routine name and compiles twice.
2. **`$$TEST^C0FWLAB` graphmap guard.** The third LOINC→#60 lookup calls
   `$$graphmap^SYNGRAPH("loinc-lab-map",…)`. When the SYN loader graph store
   (file 2002.801) is absent — as on FOIA — `setroot^SYNGRAF` builds a null
   subscript and throws `<SUBSCRIPT>`; the inline `$ETRAP` there cannot unwind
   it from an extrinsic frame (cascades to an uncatchable `<FRAMESTACK>`).
   Added `$$LMAPOK()` — only call graphmap when
   `^SYNGRAPH(2002.801,"B","loinc-lab-map")` exists. The primary map
   (`$$MAP^SYNQLDM`) is unaffected.
3. **Lab-key privileges for the filing user.** ISI files each result with
   `ENTERED_BY=DUZ`; USER,ONE (DUZ 1) lacked lab keys → `Invalid ENTERED_BY
   (#200,.01). Insufficient privilages.` Step 1e now grants DUZ 1 `LRVERIFY`,
   `LRLAB`, `LRSUPER`.

**Result:** the ISI import path is live end-to-end — a GLUCOSE result filed
through `LABADD^SYNDHP63 / $$LAB^ISIIMP12` for DFN 1.

## Lab accessioning configured (2026-09-11)

The FOIA image ships the 22 file #68 accession areas but leaves the Lab
package unconfigured: almost no #60 test is linked to an area (subfile 60.11
empty → `<test> does not have an appropriate accession area`), no area has a
numeric identifier (#68 field .4 → `You must enter a 'Numeric Identifier' in
field .4 of the Accession file!!`), and rollover has never run. Fixed by
mirroring the working vehu10 reference config (file #60 node 8, inst 500) onto
FOIA institution 1 (PLATINUM) via the committed artifact
`scripts/artifacts/C0FZLACC.mac`, applied by `iris-web-setup.sh` step 1g:

1. **EN** — 522 subfile 60.11 rows added via `UPDATE^DIE`
   (`INSTITUTION=1, ACCESSION AREA=<vehu10's area>` per test); 45 vehu-only
   areas and 198 name-mismatched tests skipped safely.
2. **IDS** — numeric identifier (#68 .4 = ien) on all 22 areas, per
   `SetAccessionIDs^SYNLINIT`.
3. **FIX2** — LDL CHOLESTEROL (#60 ien 901) had an **empty SUBSCRIPT** (ISI
   requires `CH`); eight tests (EOSINO, BASO, RDW, PCO2, PO2, BICARBONATE,
   TCO2, LDL) had no collection sample (#60.03) at all → added BLOOD /
   ARTERIAL BLOOD rows (per `docs/LAB_ACCESSION_REMEDIATION_WORKFLOW.md` in
   VistA-FHIR-Data-Loader).
4. **ROLL** — foreground `D ^LROLOVER` (Taskman does not run on IRIS): all 22
   areas rolled over; the `ROLLOVER HAS NOT RUN` spam is gone.
5. **`UANORM^C0FWLAB`** — Synthea urinalysis qualitative results arrive as
   long SNOMED finding displays (`"Urine nitrite negative (finding)"`) that
   overflow VistA's 8-char free-text / set-of-codes answers; added
   contains-based `NEGATIVE→NEG` / `POSITIVE→POS` rules (XINDEX clean).

**Evidence (rerunnable):** re-filing labs for all 12 cohort bundles via
`RELAB^C0FZLACC` ended with **zero lab errors** (~8,900 loaded; DFN 1 went
53 errors → 0, `^LR` CH nodes 6 → 318+). FHIR read-back for DFN 1 returns
123 Observations over https. `iris-web-setup.sh` re-run is idempotent
(`added=0 alreadyHad=532`, `ROLLOVER NOT REQUIRED`); `iris-lane-smoke.sh`
passes; vehu10 sync + smoke unaffected.

## Remaining known gaps (accepted)

- The 29 mapping-gap errors above; the 9/10 vital-type list still applies
  to skips inside Observation.
- The 29 mapping-gap errors above; the 9/10 vital-type list still applies
  to skips inside Observation.
- Let's Encrypt issuance hit the known 01:00–02:00 UTC secondary-validation
  DNS window during setup; Caddy retries until it lands. `FHIRBASE` ran the
  re-eval via `http://…:9080/fhir`; flip back to https once the cert is up.
- TaskMan still unconfigured on IRIS (foreground `REEVALJ` remains the path).
