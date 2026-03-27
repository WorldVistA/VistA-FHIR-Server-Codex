# Steps Taken

Use this file as a chronological log of concrete implementation work.

## 2026-03-03
- Established source convention: MUMPS routines go in `src/`.
- Established documentation convention: detailed tracking files go in `docs/`.
- Established namespace convention: use `C0FHIR` for all new MUMPS routines and new DDE entities.
- Added starter routine scaffold in `src/C0FHIR.m`.
- Added bundle dispatcher entry point `GETBNDL^C0FHIR`.
- Added bundle orchestration scaffold routine `src/C0FHIRBU.m`.
- Added documentation tracking structure in `docs/`.
- Added namespace reference documentation in `docs/NAMING_CONVENTIONS.md`.
- Added a Phase 1 resource naming map for routine names and DDE entity patterns.
- Added bundle response requirements in `docs/BUNDLE_REQUIREMENTS.md`.
- Added `docs/PROJECT_CONTEXT_PUBLIC.md` as a repository-safe context document.
- Selected `ENCODE^XLFJSON` as the JSON encoding standard and added `GETBNDLJ^C0FHIR` / `TOJSON^C0FHIRBU` scaffolding.
- Added web service entry point `GETFHIR^C0FHIR(RTN,FILTER)` with URL-parameter mapping (for example `FILTER("dfn")=dfn`).
- Updated patient builder contract to `GETPAT^C0FHIR(RTN,DFN)` so bundle generators pass the full in-flight bundle array by reference.
- Read and analyzed the `FHIR-source-files` reference corpus (DDE, VPR, and sample bundles) to drive first-version design.
- Implemented first-version transaction bundle builder with de-duplicated `Patient` and `Encounter` entries.
- Added encounter-centric and date-range encounter loading (`^AUPNVSIT("AET",DFN,...)`) into `BYENC^C0FHIRBU` and `BYDATE^C0FHIRBU`.
- Added `docs/FHIR_SOURCE_FINDINGS.md` to document analysis findings from `FHIR-source-files` and resulting implementation decisions.
- Added `docs/VPR_CONTAINER_FHIR_MAPPING.md` mapping all listed VPR container domains to FHIR resources and source file numbers.
- Updated mode resolution so requests with no encounter/date filters default to all-encounters date-range behavior.
- Added first-pass `Condition` and `Observation` resource builders and wired them into encounter/date-range bundle generation.
- Added first-pass `AllergyIntolerance` and `MedicationRequest` resource builders and wired them into encounter/date-range bundle generation.
- Added first-pass `Immunization` and laboratory (`Observation`) resource builders and wired them into encounter/date-range bundle generation.
- Added `docs/TEST_SERVER_VALIDATION.md` to document `dfn`-based VPR test server parity checks and a baseline validation case.
- Added `^DPT("B")` `gtree` endpoint guidance to document how to discover patient `dfn` values from the test server.
- Added graph-store `DFN` index guidance (`^%wd(17.040801,3,"DFN",DFN,IEN)`) for tracing patients back to original imported Synthea source records.
- Added explicit graph-store JSON retrieval pattern (`gtree/%25wd(17.040801,3,<IEN>,%22json%22)`) with example IEN lookup workflow.
- Added graph-store load log retrieval pattern (`gtree/%25wd(17.040801,3,<IEN>,%22load%22)`) and documented how it supports import-vs-mapping parity debugging.
- Replaced fragile `VPRDLR` helper calls in lab extraction with direct normalized line building from `^TMP("LRRR",...)` to avoid hidden local-variable assumptions.
- Normalized non-canonical FileMan time components (overflow seconds/minutes) before FHIR `dateTime` serialization.
- Switched response envelope semantics for `GET /fhir` to `Bundle.type="collection"`, removed transaction request metadata, and moved entry `fullUrl` generation to valid `urn:uuid:<uuid>` values.
- Added post-encoding JSON normalization for numeric-literal `id` and `code` keys so those fields emit as JSON strings.
- Added RPC entry points `RPCFHIR^C0FHIR` (scalar params) and `RPCFHIRA^C0FHIR` (array params) as wrappers to the existing `GETFHIR^C0FHIR` request flow.
- Added RPC gateway routine `src/C0FHIRGF.m` with `GENFULL^C0FHIRGF` for Broker-compatible parameter naming (`DFN,ENCPTR,SDT,EDT,MAX,MODE`).
- Added environment setup routine `src/C0FHIRSE.m` to register/update RPC `C0FHIR GET FULL BUNDLE` and context option `C0FHIR CONTEXT` in files `#8994` and `#19`.
- Added optional domain filtering (`domains`) so bundles can be requested by domain (`encounter`, `condition`, `vitals`, `allergy`, `medication`, `immunization`, `labs`) across web and RPC entry points.
- Refactored oversized `C0FHIR` logic into helper routines (`C0FHIRD`, `C0FHIRM`, `C0FHIRL`) while preserving public entry points in `C0FHIR`.
- Added first-pass `Procedure` resource builders (surgery, radiology, clinical procedures, and V-CPT sources) and wired `procedures` domain filtering into encounter/date-range bundle generation, RPC descriptions, and requirements docs.

## 2026-03-15
- Filtered encounter-coded V CPT rows out of exported FHIR `Procedure` resources in `src/C0FHIRP.m`, including `410620009` (`Well child visit`) in the encounter-only filter set.
- Added `410620009` to `codes/encounter_sct.json` so the repo-level encounter code list matches observed Synthea source data used in validation.
- Diagnosed and validated complementary SYN loader fixes in `VistA-FHIR-Data-Loader` for encounter CPT happy-path behavior: `SYNDHP61` mapping/blank-index guards, `SYNQLDM` GT.M-safe `MAPERR`, and `SYNOS5D4` mapping `410620009 -> 3282K` while retaining the existing `6456Q` fallback for genuinely unmapped encounter codes.
- Revalidated current patient `DFN 1642` and confirmed `/fhir` no longer exports encounter placeholder rows such as `OUTPATIENT ENCOUNTER` as `Procedure`.
- Loaded a fresh cloned Cody-based patient (`DFN 1645`) through the normal `FILE^SYNFHIR` path and confirmed `encounters 58/58`, `procedures 49/49`, exported placeholder procedures `0`, exported `6456Q` procedures `0`, and raw V CPT `6456Q` rows `0`.
- Added `docs/CPT_HAPPY_PATH_VALIDATION_2026-03-15.md` to capture the cross-repo fixes, runtime deployment steps, and fresh-patient validation evidence for this work.

## 2026-03-16
- Deployed the current `FHIR` and `SYN` routine set directly into the VEHU `fhirdev` container at `/home/vehu/p`, ran `XINDEX`, and completed the direct-copy post-deploy rebuild with `EN^SYNGBLLD`.
- Verified on VEHU that the OS5 reload restored `$$COUNT^SYNOS5LD=1041`, `410620009 -> 3282K`, file `81` IEN `200000319`, and Lex IEN `3000000320`, and confirmed the host-local FHIR listener returned HTTP `200`.
- Added `docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md` to document the exact VEHU deployment path, the `addPatient` registration and host-local POST workflow, Dockerized Synthea generation, and the live import notes from real VEHU runs.
- Confirmed two live-run findings while preparing a fresh patient test: `Sergio619 Manzanares924` already existed on VEHU as `DFN 101088`, and `Abbie917 Leighann368 Harris789` exposed a SYN lab-loader bug that was later fixed in `SYNDHP63`.
- Successfully imported `Francesco636 Daugherty69` into VEHU as `DFN 101090` / `ICN 4263043815V188953`, then verified `GET /fhir?dfn=101090` returned `Patient 1`, `Encounter 34`, `Condition 19`, `Observation 156`, `DiagnosticReport 14`, `MedicationRequest 2`, `Immunization 5`, `Procedure 103`, with exported placeholder procedures `0`.
- Investigated reported host PIDs `773252` and `773859` and confirmed they were not M web workers but root-owned `/tmp/linux` processes inside the `fhirdev` container; identified companion binaries `/etc/kswpad`, `/usr/bin/.sshd`, and `/usr/lib/libgdi.so.0.8.2`, plus cron persistence `*/1 * * * * root /.mod`.
- Removed the malicious persistence chain from the live `fhirdev` container, killed the associated processes, verified the suspicious binaries were gone, and documented the incident plus the still-separate `%webreq` worker leak in `docs/FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`.
- Rechecked `fhirdev` after client closure: confirmed six sockets in CLOSE_WAIT and six hot workers (server-side leak). Added `docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md` outlining the fix (WAIT/ETDC, timeout, disconnect handling) and updated the incident doc with post–sleep findings and a pointer to the outline.

## 2026-03-25
- Deployed the full current `C0FHIR` routine set (nine `src/C0FHIR*.m` files) into the VEHU `fhirdev` container at `/home/vehu/p` via `scp` to the host and `docker cp` into `fhirdev` (host staging under `/tmp/c0fhir-deploy-*`).
- Ran `QUICK^XINDX6` in two batches (M direct-mode line-length limit) so all `C0FHIR*` routines were cross-referenced; second batch reported no errors or warnings; first batch reported the usual `C0FHIR` SACC/size and cross-reference notices consistent with prior runs.
- Smoke-tested from the host: `GET http://127.0.0.1:9080/fhir` and `GET http://127.0.0.1:9080/fhir?dfn=101090` both returned HTTP `200` with a JSON bundle prefix on the bundle request.
- Captured GT.M ZSY on `fhirdev` showing multiple `BG-0` workers in `MATCHR+8^%webrsp` (and briefly `URLDEC^%webutils`) with rising CPU times while `LOOP+19^%webreq` held `BG-S9080`; documented the characterization in `docs/FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md` and cross-linked from `docs/FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`.

## 2026-03-27
- Documented a fresh-start GT.M ZSY baseline for live container `fhirdev22` on `fhirdev.vistaplex.org` (single `LOOP+19^%webreq` on `BG-S9080`, no `MATCHR^%webrsp` pile, TaskMan/Mailman/HL7 `HLCSTCP1` on link 5001) in `docs/FHIRDEV22_FRESH_START_ZSY_SNAPSHOT_2026-03-27.md` for comparison to the 2026-03-25 incident snapshot and future regressions.

## Template For New Entries
- Date:
- Change:
- Files touched:
- Reason:
- Validation performed:
- Next follow-up:
