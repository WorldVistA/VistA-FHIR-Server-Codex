# Development Status and Gap Analysis — VistA-FHIR-Server-Codex

Status date: 2026-08-07
Branch at time of writing: `feature/fhir-writeback-encounter-notes`

This document summarizes the current state of development in this repository and
provides a gap analysis. Companion documents:

- `Vista-on-FHIR/docs/PROJECT_OVERVIEW.md` — what the overall system is and why it matters.
- `Vista-on-FHIR/docs/APPROACH_AND_BENEFITS.md` — why we build the way we build.
- `Vista-on-FHIR/docs/PATH_FORWARD.md` — recommended sequencing to minimize rework.

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
- **Quality / population surfaces**: `/fhir-quality-dashboards`,
  `/fhir-quality-recompute`, MeasureReport serving, and C0X population IPP
  deep links (`src/C0FQUAL.m` and related).
- **Bridges**: `POST /rehmp` (CPRS demo gateway), `/bsts/*` terminology
  (`src/C0TSWS*.m`), reminder writeback saves (`src/C0FWWBS.m`).

## What is working today

| Capability | Evidence |
|---|---|
| Quality dashboards link DEQM Summary MeasureReports | `C0FQUAL` → `/filesystem/quality/measurereports/{CMS}/summary-deqm.json` (official-cql freeze) and DEQM-profiled SETPOP `summary.json` |
| Multi-domain FHIR read with VPR parity workflow | `docs/TEST_SERVER_VALIDATION.md` (baseline DFN 1595) |
| Encounter/procedure CPT happy path | `docs/CPT_HAPPY_PATH_VALIDATION_2026-03-15.md` |
| FHIR browser with TJSON WASM **0.6.5** on vehu10/fhirdev22 | `docs/FHIR_BROWSER_TJSON_CODEX.md`; vendored `@rfanth/tjson` 0.6.5 |
| reHMP bridge regression (`POST /rehmp` + `GET /fhir`) | `docs/RUNNING_DEMOS.md`, `scripts/demo-rehmp-regression.sh` |
| Stage 1 diagnosis writeback (SNOMED POV, multi-code, problem-selection lists) | `docs/clinical-test-cases/stage1-diagnosis-cases.json`, `scripts/stage1-diagnosis-smoke.mjs` |
| Encounter-note export/import round trip | `docs/FHIR_ENCOUNTER_NOTE_EXPORT_IMPORT.md` |
| AI Consult end-to-end path (bundle → CDS → TIU note) | `docs/AI_CONSULT_TEST_PATH.md` |
| New-patient intake from Synthea via `/addpatient` | `docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`, `docs/SYNTHEA_DOCKER_PATIENT_GENERATION.md` |
| US Quality Core Must Support fields for Inferno (Encounter, DocumentReference, Observation lab, Organization/Practitioner/Location, Condition/Procedure shapes) | Hosted Inferno scorecards recorded in `HL7-FHIR-quality-testing`; commits through 2026-07/08 |
| Smoking-status Observations from LCS health factors; CarePlans from SYN CP health factors; CVX 212 Ad26 display alignment | Export commits on this branch |
| Quality dashboards with curated SETPOP cohorts, MeasureReports, CQL re-eval, Clean/Delete cohort actions | `/fhir-quality-dashboards` on fhirdev; `C0FQUAL` seed progression |
| Quality writeback helpers (mammography ServiceRequest, smoking status, Condition hardening) | Writeback + dashboard re-eval loop |
| RPMS graph-lab Observations/panels as lab-of-record; RPMS Procedure (V CPT) and mammo ServiceRequest writeback; broader RPMS-native filing for encounter/POV/vitals/immunization/allergy/HF paths | RPMS dual-stack commits; `rpms-fhir` test gate |
| Synthea ICN dedupe and C0FW directory bulk load | Commit `082403f` (2026-08-07) |
| C0X population IPP deep links from quality measure pages | Index FHIR codes for SPARQL; link to `fhir-triple-store` UI |

Current branch focus: US Quality Core / Inferno conformance, quality dashboard
cohort operations, RPMS dual-stack read/write parity, and C0FW bulk load /
ICN hygiene. Untracked helper scripts under `scripts/C0FGRP*.m` and a local
`tmp/` directory are present but not part of the committed gate.

## Gap analysis

### Functional gaps

1. **Writeback domain coverage is still partial.** Native C0FW filing is real
   for encounters, diagnoses (POV), health factors, and TIU notes. RPMS
   paths now also cover broader native filing (including allergy /
   immunization / vitals / Procedure CPT / mammo ServiceRequest), and labs
   on RPMS prefer graph retention as lab-of-record rather than LR filing.
   On VistA, labs still often file through SYN/ISI helpers on the quality
   path (constraint temporarily loosened). Medication, CarePlan *import*,
   and Appointment adapters remain incomplete or placeholder. The
   completion target remains native C0FW coverage for every domain — no
   SYN or ISI routine required in the solution — after which those repos
   become reference-only. See
   `docs/C0FW_SELECTIVE_SYN_ISI_COMPLETION_PLAN.md`.
2. **US Core / Quality Core conformance advanced but not finished.** Many
   CMS165 leaf fails on `/fhir` have been cleared (including recorded
   zero-fail scorecards after Condition/Encounter/Procedure and CVX fixes),
   but broader skipped resource families and multi-measure Inferno coverage
   remain open work owned with `HL7-FHIR-quality-testing`.
3. **AI Consult is not an order.** It files a TIU note/DiagnosticReport and
   now participates in Quality AI Consult update/re-eval loops, but is not
   connected to VistA consult ordering or the VistA-ordering-service.
4. **Reads remain VPR-heavy.** The RPMS dual-stack plan
   (`docs/RPMS_DUAL_STACK_READ_WRITEBACK_PLAN.md`) still calls for an
   explicit capability/profile layer (`vista` vs `rpms`); substantial RPMS
   progress exists in sibling `rpms-fhir`, but Codex route gating is still
   largely implicit by routine presence.
5. **Write contract is not yet standardized.** Clients still write via
   `/updatepatient` query parameters rather than the bundle-first write
   contract specified in CPRS-on-FHIR.

### Engineering / operational gaps

1. **No automated M test suite.** Validation is smoke-script, Inferno
   scorecard, and curl driven; the required gate (XINDEX + smoke on the
   test server) remains manual.
2. **M web server debt.** CLOSE_WAIT worker leaks and runaway `%webrsp`
   workers are characterized but the upstream fix is an outline
   (`docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`).
3. **Hardcoded / host-specific values.** CDS endpoint
   (`cds1.vistaplex.org`), quality demo host assumptions (`fhirdev`), and
   LOINC maps still need site-parameter treatment before broad second-site
   deployment.
4. **Vendored HTTP client.** `_WC.m` escaping is flagged `TODO: not bullet
   proof`.
5. **Security posture.** Several 2026 incident-response docs record container
   compromises. Containment was applied per incident; a standing hardening
   checklist for new containers is not yet codified in one place.
6. **No root README.** Onboarding starts at `docs/README.md`; a top-level
   pointer would help newcomers (partially addressed by
   `Vista-on-FHIR/docs/PROJECT_OVERVIEW.md`).

### Documentation state

Documentation remains a strength: validation records, quality/Inferno
scorecard cross-links, RPMS dual-stack plans, and runbooks indexed in
`docs/README.md`. State is still spread across dated documents; this file
and `Vista-on-FHIR/docs/PATH_FORWARD.md` are the consolidation points.

## Dependencies on sibling repos

| Repo | Dependency |
|---|---|
| `VistA-FHIR-Data-Loader` (SYN) | Ingest fallback engines; replay/gap-repair; lab filing helpers (transitional) |
| `VistA-DataLoader` (ISI) | Import primitives for SYN (transitional) |
| `rehmp` | C0RG gateway + CPRS demo / Quality AI Consult UI |
| `CPRS-on-FHIR` | Write-contract specs (encounter-note simulation bundle) |
| `bsts-vista` / `C0T-terminology-gateway` | Terminology search and SNOMED↔ICD mapping |
| `reminders-on-fhir` | Reminder writeback artifacts via `/writebacksaves` |
| `fhir-triple-store` | C0X SPARQL / population IPP cohort discovery |
| `cds-hooks-on-fhir` | Quality AI Consult / CQL eval sidecar backends |
| `HL7-FHIR-quality-testing` | Inferno scorecards, CQL cohorts, Connectathon evidence |
| `rpms-fhir` | RPMS container bootstrap, sync, and dual-stack test gate |
| `tjson-tooling` | TJSON/`%wd` Rust tooling; browser WASM vendored here |
| `FHIR-source-files` | Source bundles and parity fixtures |
