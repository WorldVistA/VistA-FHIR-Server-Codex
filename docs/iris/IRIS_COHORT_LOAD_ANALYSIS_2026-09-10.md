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
