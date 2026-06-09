# Development Status and Gap Analysis — VistA-FHIR-Server-Codex

Status date: 2026-06-09
Branch at time of writing: `feature/fhir-writeback-encounter-notes`

This document summarizes the current state of development in this repository and
provides a gap analysis. Companion documents:

- `docs/PROJECT_OVERVIEW.md` — what the overall system is and why it matters.
- `docs/APPROACH_AND_BENEFITS.md` — why we build the way we build.
- `docs/PATH_FORWARD.md` — recommended sequencing to minimize rework.

## Role of this repository

This repo is the center of the stack: a FHIR R4 server implemented in
VistA-standard M (MUMPS) that runs inside GT.M/YottaDB VistA containers. It
provides:

- **FHIR read**: `GET /fhir` returns one multi-domain `Bundle` per patient,
  encounter, or date range (`src/C0FHIR*.m`).
- **FHIR intake / writeback**: `POST /addpatient`, `POST /updatepatient`
  through the C0FW framework (`src/C0FW*.m`), with a graph store
  (`^%wd`-backed) holding the source-of-truth bundle slices.
- **Browser surface**: `GET /fhir?view=browser` with vendored TJSON WASM
  (`vendor/tjson/`), plus `GET /showfhir` and `GET /tfhir`.
- **AI Consults**: `GET /aiconsult` orchestration to an external CDS service
  with TIU filing (`src/C0FWAIS.m`, `src/C0FWAIC.m`).
- **Bridges**: `POST /rehmp` (CPRS demo gateway), `/bsts/*` terminology
  (`src/C0TSWS*.m`), reminder writeback saves (`src/C0FWWBS.m`).

## What is working today

| Capability | Evidence |
|---|---|
| Multi-domain FHIR read with VPR parity workflow | `docs/TEST_SERVER_VALIDATION.md` (baseline DFN 1595) |
| Encounter/procedure CPT happy path | `docs/CPT_HAPPY_PATH_VALIDATION_2026-03-15.md` |
| FHIR browser with TJSON WASM on vehu10/fhirdev22 | `docs/FHIR_BROWSER_TJSON_CODEX.md` |
| reHMP bridge regression (`POST /rehmp` + `GET /fhir`) | `docs/RUNNING_DEMOS.md`, `scripts/demo-rehmp-regression.sh` |
| Stage 1 diagnosis writeback (SNOMED POV, multi-code, problem-selection lists) | `docs/clinical-test-cases/stage1-diagnosis-cases.json`, `scripts/stage1-diagnosis-smoke.mjs` |
| Encounter-note export/import round trip | `docs/FHIR_ENCOUNTER_NOTE_EXPORT_IMPORT.md` |
| AI Consult end-to-end path (bundle → CDS → TIU note) | `docs/AI_CONSULT_TEST_PATH.md` |
| New-patient intake from Synthea via `/addpatient` | `docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`, `docs/SYNTHEA_DOCKER_PATIENT_GENERATION.md` |

Current branch focus: encounter diagnosis writeback, Stage 1 clinical test
cases, and AI Consult graph-seed evidence. Uncommitted work in `src/C0FHIRD.m`
(LOINC mapping for vitals, BP components) and `src/C0FWAIS.m` (Stage 1/2
evidence acceptance, HTTP hardening) is in progress on this branch.

## Gap analysis

### Functional gaps

1. **Writeback domain coverage is partial.** Native C0FW filing is real for
   encounters, diagnoses (POV), health factors, and TIU notes. Lab, Allergy,
   Medication, Procedure, CarePlan, and Appointment adapters return
   `not_implemented` or are placeholders (`C0FWCP.m`). See
   `docs/C0FW_SELECTIVE_SYN_ISI_COMPLETION_PLAN.md` and
   `docs/CAREPLAN_IMPORT_OPTIONS.md`.
2. **US Core / profile conformance is first-pass** for AllergyIntolerance,
   MedicationRequest, Immunization, and lab Observation terminology
   (`docs/UNRESOLVED_ISSUES.md`). No automated R4/US Core validation tooling is
   in the loop yet (`docs/OPEN_QUESTIONS.md` #3–4).
3. **AI Consult is not an order.** It files a TIU note/DiagnosticReport but is
   not connected to VistA consult ordering or the VistA-ordering-service.
4. **Reads remain VPR-heavy.** The RPMS dual-stack plan
   (`docs/RPMS_DUAL_STACK_READ_WRITEBACK_PLAN.md`) calls for explicit
   capability checks and a profile layer (`vista` vs `rpms`); routes today are
   gated implicitly by routine presence.
5. **Write contract is not yet standardized.** Clients (CPRS demo) write via
   `/updatepatient` query parameters rather than the bundle-first write
   contract being specified in CPRS-on-FHIR.

### Engineering / operational gaps

1. **No automated M test suite.** Validation is smoke-script and curl driven;
   the required gate (XINDEX + smoke on the test server) is manual.
2. **M web server debt.** CLOSE_WAIT worker leaks and runaway `%webrsp`
   workers are characterized but the upstream fix is an outline
   (`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`,
   `docs/M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`).
3. **Hardcoded values.** CDS endpoint (`cds1.vistaplex.org` in `C0FWAIS.m`),
   LOINC vital map in `C0FHIRD.m`, default date ranges. Fine for now; should
   move behind site parameters before any second deployment target.
4. **Vendored HTTP client.** `_WC.m` escaping is flagged `TODO: not bullet
   proof`.
5. **Security posture.** Several 2026 incident-response docs record container
   compromises (exposed in-container SSH, malware persistence). Containment
   was applied per incident; a standing hardening checklist for new containers
   is not yet codified in one place.
6. **No root README.** Onboarding starts at `docs/README.md`; a top-level
   pointer would help newcomers (this gap is partially addressed by
   `docs/PROJECT_OVERVIEW.md`).

### Documentation state

Documentation is a strength: 50+ docs including validation records, runbooks,
incident responses, and integration plans, indexed in `docs/README.md`. The
main weakness is that state is spread across dated documents; this file and
`docs/PATH_FORWARD.md` are the consolidation points.

## Dependencies on sibling repos

| Repo | Dependency |
|---|---|
| `VistA-FHIR-Data-Loader` (SYN) | Ingest fallback engines; replay/gap-repair workflow |
| `VistA-DataLoader` (ISI) | Import primitives for SYN |
| `rehmp` | C0RG gateway implementation + CPRS demo client |
| `CPRS-on-FHIR` | Write-contract specs (encounter-note simulation bundle) |
| `bsts-vista` / `C0T-terminology-gateway` | Terminology search and SNOMED↔ICD mapping |
| `reminders-on-fhir` | Reminder writeback artifacts consumed via `/writebacksaves` |
| `tjson-tooling` | TJSON/`%wd` Rust tooling; browser WASM vendored here |
| `FHIR-source-files` | Source bundles and parity fixtures |
