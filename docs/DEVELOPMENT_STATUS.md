# Development Status and Gap Analysis — VistA-FHIR-Server-Codex

Status date: 2026-10-27 (previous: 2026-08-07)
Branch at time of writing: `master` (62 routines in `src/`, 41 scripts)

This document summarizes the current state of development in this repository and
provides a gap analysis. Companion documents:

- `Vista-on-FHIR/docs/PROJECT_OVERVIEW.md` — what the overall system is and why it matters.
- `Vista-on-FHIR/docs/APPROACH_AND_BENEFITS.md` — why we build the way we build.
- `Vista-on-FHIR/docs/PATH_FORWARD.md` — recommended sequencing to minimize rework.
- `Vista-on-FHIR/docs/sprint/` — what shipped, by period, each line with a
  rerunnable check (`SPRINT_REPORT_2026-09.md`, `_2026-10.md`,
  `_2026-10-27.md`).
- `AGENTS.md` — the working agreement, fleet, and the gate before commit.

## Since 2026-08-07

Three periods, each recorded in `Vista-on-FHIR/docs/sprint/`:

**September sprint (2026-09-09).** The standard clinical write route
`patient.fhir.write` (CFH-WRITE-001 v1) landed as `C0FWWRT`, proven by a
13-assertion harness and deployed fleet-wide. `scripts/ci-roundtrip-local.sh`
made correctness mechanical: fresh container → Synthea → `/addpatient` →
read-back parity → write harness, ~3–4 minutes, dated report in
`docs/ci-reports/`; it caught a Kernel `KILL` of the unnamespaced `LAST`
mid-bundle on its first day. `scripts/check-artifacts.sh` guards vendored
TJSON/C0TS with sha256 manifests and refuses empty VSAC overwrites. The IRIS
portability audit (`docs/iris/IRIS_PORTABILITY_AUDIT_2026-09.md`) found 3
items in 94 routines; all were shimmed through `C0FWOS.m` the same day.

**Between sprints (09-10 → 10-07).** Production moved to WorldVistA EHR 3.0
(`wvehr`, user `wv`, https://fhir.vistaplex.org; the old `fhir` container
stays stopped for rollback). FHIR JSON encoding moved to rehmp's
`C0RGJSNE`/`C0RGFENC` (`GETBNDLJ^C0FHIR` calls `ENCODE^C0RGFENC`, so those
routines ship with every Codex deploy); TOJSON double-encode and output
leaking ahead of HTTP headers fixed (09-30). The leveled VEHU L0–L6 round
trip on stock `worldvista/vehu:latest` (`ci-vehu-roundtrip.sh`, 09-30)
joined the nightly Claude Code lane (cron 01:00/06:30), which also runs the
write harness against fhirdev, the artifact check, fleet smoke with
`QUALITY_SKIP_DEPLOY=1`, the IRIS scan, and the agent-doc convergence gate.
Encounter/OS5 coding: role-split OS5 maps, STD CODES on Encounter read,
visit type filed as V CPT (09-25); Condition resolution dates/status and
UTF-8-safe C0FW responses (10-07). US Core 6.1/7.0 Inferno search, metadata,
and profile builders fixed (09-23/24). `AGENTS.md` + `CLAUDE.md` in every
repo (10-07).

**October (10-08 → 10-27): the read path learned US Quality Core.** Fourteen
routines changed (`C0FHIR`, `C0FHIRD`, `C0FHIRL`, `C0FHIRLG`, `C0FHIRM`,
`C0FHIRP`, `C0FQUAL`, `C0FWADD`, `C0FWALG`, `C0FWCAC`, `C0FWENC`, `C0FWUPD`,
`C0FWVIT`, `C0FWVITR`), each step measured by a hosted Inferno session on
the ZZ cohort (`HL7-FHIR-quality-testing/docs/USQC_INFERNO_SKIP_PLAN.md`):

- Official CVX and LOINC displays; Observation `date` search by effective
  time (10-12). Quality Core fields and graph-carried resources the ZZ
  charts already hold — Coverage, CareTeam, RelatedPerson, Goal, CarePlan,
  ServiceRequest, Provenance — emitted on read (10-12, 10-14); fields served
  even when the example is thin (10-24); the example resources Inferno was
  still skipping (10-26).
- Vitals converted cm/kg/Cel on the GMV path and entered-in-error vitals
  hidden (10-10); vital-sign panels read from the intake graph like lab
  panels (10-11); allergens via #50.416/#50.6, the Inferno immunization shim
  gated, GMV unit repair (10-11).
- One patient indexed into C0X POPIDX on add/update (10-11); office-visit
  CPT 99202 gets a real display and stays off Procedure (10-14).
- Each bundle encoded once so a second pass cannot duplicate the JSON tail;
  a checked-out visit filed as ambulatory so the CPRS cover sheet keeps it
  (10-24).
- `iris2` (https://iris2.vistaplex.org, native IRIS Health on Rocky,
  `scripts/iris-native/`) replaced `irisfhir` as the non-blocking sixth
  fleet lane (10-14); the IRIS web setup is forced onto the JSNE encoder.
  A native YottaDB install and the 2026-10-17 encode comparison are in
  `docs/native/NATIVE_YDB_INSTALL.md` (YDB#1278 patch: `$DATA` ~12× faster,
  encode ~4.6×; measurements in `JSON-with-Mumps`).

Result: the public Show server (`showfhir.vistaplex.org`, a fresh VEHU
container rebuilt from the four package manifests in
`Vista-on-FHIR/dist/packages/` on 10-23, 10-24, and 10-25) passed **US
Quality Core v0.5.0 in full — 438 of 438 tests, 0 skipped, 498 of 498
rows** — on 2026-10-25 against 34 synthetic ZZ charts (session
`2yWbChvQkWt`). The 34 served Bundles are published in
`HL7-FHIR-quality-testing/2026/patients/show-quality-core-2026-10-25/`.
Those manifests (`vista-fhir-server` = 60 `C0F*` routines, plus
`rehmp-chart`, `vista-fhir-load`, `vista-fhir-population`) are now the
software identity for a host; `Vista-on-FHIR/scripts/audit-package-drift.sh`
walks the fleet read-only every night
(`Vista-on-FHIR/docs/PACKAGE_DRIFT_PLAN_2026-10-24.md`).

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
| FHIR browser with TJSON WASM **0.10.1** on vehu10/fhirdev | `docs/FHIR_BROWSER_TJSON_CODEX.md`; vendored `@rfanth/tjson` 0.10.1 |
| reHMP bridge regression (`POST /rehmp` + `GET /fhir`) | `docs/RUNNING_DEMOS.md`, `scripts/demo-rehmp-regression.sh` |
| Stage 1 diagnosis writeback (SNOMED POV, multi-code, problem-selection lists) | `docs/clinical-test-cases/stage1-diagnosis-cases.json`, `scripts/stage1-diagnosis-smoke.mjs` |
| Encounter-note export/import round trip | `docs/FHIR_ENCOUNTER_NOTE_EXPORT_IMPORT.md` |
| AI Consult end-to-end path (bundle → CDS → TIU note) | `docs/AI_CONSULT_TEST_PATH.md` |
| New-patient intake from Synthea via `/addpatient` | `docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`, `docs/SYNTHEA_DOCKER_PATIENT_GENERATION.md` |
| **US Quality Core v0.5.0 server suite, all pass, no skips** (438/438 tests, 498/498 rows) on Show with 34 ZZ charts, 2026-10-25 | Inferno session `2yWbChvQkWt`; `HL7-FHIR-quality-testing/2026/scorecards/inferno/2026-10-25-showfhir-rebuild.md`; weekly iris2 run `scripts/weekly-iris2-inferno.sh` |
| Standard clinical write route `patient.fhir.write` (CFH-WRITE-001 v1) with idempotency, simulation, structured errors | `python3 CPRS-on-FHIR/harness/CFH-WRITE-001/harness.py --base https://devfhir.vistaplex.org` (13 assertions; nightly) |
| Fresh-container round trip (Synthea → `/addpatient` → read-back parity → write harness) and the stock-VEHU L0–L6 lane | `scripts/ci-roundtrip-local.sh`; `scripts/ci-vehu-roundtrip.sh --level 6`; reports in `docs/ci-reports/` |
| Vendored-artifact and VSAC guards | `scripts/check-artifacts.sh` (nightly) |
| Six-host fleet deploy + smoke (fhirdev, vehu10, rpms-candidate, rpmsfhir, wvehr, iris2 non-blocking) with machine-checked quality contracts | `scripts/deploy-quality-all.sh`; `scripts/smoke-quality-host.sh <host>` |
| IRIS portability: audit, `C0FWOS.m` shim, live iris2 lane on native IRIS Health | `docs/iris/IRIS_PORTABILITY_AUDIT_2026-09.md`; `scripts/iris-native/README.md`; `scripts/iris-portability-scan.py` |
| Smoking-status Observations from LCS health factors; CarePlans from SYN CP health factors; CVX 212 Ad26 display alignment | Export commits on this branch |
| Quality dashboards with curated SETPOP cohorts, MeasureReports, CQL re-eval, Clean/Delete cohort actions | `/fhir-quality-dashboards` on fhirdev; `C0FQUAL` seed progression |
| Quality writeback helpers (mammography ServiceRequest, smoking status, Condition hardening) | Writeback + dashboard re-eval loop |
| RPMS graph-lab Observations/panels as lab-of-record; RPMS Procedure (V CPT) and mammo ServiceRequest writeback; broader RPMS-native filing for encounter/POV/vitals/immunization/allergy/HF paths | RPMS dual-stack commits; `rpms-fhir` test gate |
| Synthea ICN dedupe and C0FW directory bulk load | Commit `082403f` (2026-08-07) |
| C0X population IPP deep links from quality measure pages | Index FHIR codes for SPARQL; link to `fhir-triple-store` UI |

Current focus: keeping the US Quality Core result green on every fleet host
(fhirdev and iris2 still skip or fail where Show does not), the January 2027
Connectathon CMS QPP/HQR lane, and the two certification-shaped gaps named
in `Vista-on-FHIR/docs/HTI5_IMPACT_AND_STRATEGY_2026-10-27.md` — SMART App
Launch and Bulk Data `$export`.

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
2. **US Quality Core is green on one host; US Core breadth is not.** The
   full v0.5.0 server suite passes with no skips on Show (2026-10-25), but
   fhirdev sits at 89.6% with skips and iris2's weekly run still shows a
   handful of failures; a host only passes once its cohort carries the
   example resources. US Core 7.0 on `/altfhir` (2026-10-11: 215 pass / 51
   fail / 310 skip) remains open work owned with
   `HL7-FHIR-quality-testing`. No SMART App Launch and no Bulk Data
   `$export` yet — the two pieces an ONC (g)(10) test run would require.
3. **AI Consult is not an order.** It files a TIU note/DiagnosticReport and
   now participates in Quality AI Consult update/re-eval loops, but is not
   connected to VistA consult ordering or the VistA-ordering-service.
4. **Reads remain VPR-heavy.** The RPMS dual-stack plan
   (`docs/RPMS_DUAL_STACK_READ_WRITEBACK_PLAN.md`) still calls for an
   explicit capability/profile layer (`vista` vs `rpms`); substantial RPMS
   progress exists in sibling `rpms-fhir`, but Codex route gating is still
   largely implicit by routine presence.
5. ~~**Write contract is not yet standardized.**~~ **Closed 2026-09-09.**
   `patient.fhir.write` (CFH-WRITE-001 v1) is implemented in `C0FWWRT`,
   harness-proven, and deployed fleet-wide; the rehmp CPRS demo uses it.
   Migration tail: Quality AI Consult filing and reminders-on-fhir still
   use `/updatepatient`; the query route is deprecated per the spec once
   they move.

### Engineering / operational gaps

1. **No automated M unit-test suite — but correctness is now mechanical.**
   `ci-roundtrip-local.sh`, `ci-vehu-roundtrip.sh`, the write harness,
   `check-artifacts.sh`, and the fleet smoke run every night from the
   Claude Code lane with dated reports; the per-routine XINDEX + smoke gate
   before commit is still a manual step. Standing nightly reds as of
   2026-10-27: the VEHU L5 JOHN-SALT level (17 nights, `loadStatus=error`,
   Condition/Encounter counts) and `package-drift` on rpms-candidate
   (misses=12, extra=65) and iris2 (misses=7, extra=28), not yet
   root-caused.
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
6. **No root README.** Onboarding starts at `docs/README.md`; agents start
   at `AGENTS.md` / `CLAUDE.md` (enforced nightly by
   `Vista-on-FHIR/scripts/check-agent-docs.sh`). A human-facing top-level
   README is still missing (partially addressed by
   `Vista-on-FHIR/docs/PROJECT_OVERVIEW.md`).
7. **Fleet deploys are routine-copy, and drift is only observed.** The
   package manifests in `Vista-on-FHIR/dist/packages/` define what a host
   should carry and the nightly audit reports drift, but repair is still a
   daytime `deploy-quality-all.sh`; `docs/iris/*` still name the retired
   `irisfhir` host.

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
| `rehmp` | C0RG gateway + CPRS demo / Quality AI Consult UI; **`C0RGFENC`/`C0RGZYEN` encoder routines must ship with every Codex deploy** |
| `WVEHR-on-FHIR` | WorldVistA EHR 3.0 port notes; the hand-authored ZZ Inferno cohort and Harriet Vance chart; Show rebuild loads |
| `CPRS-on-FHIR` | Write-contract specs (encounter-note simulation bundle) |
| `bsts-vista` / `C0T-terminology-gateway` | Terminology search and SNOMED↔ICD mapping |
| `reminders-on-fhir` | Reminder writeback artifacts via `/writebacksaves` |
| `fhir-triple-store` | C0X SPARQL / population IPP cohort discovery |
| `cds-hooks-on-fhir` | Quality AI Consult / CQL eval sidecar backends |
| `HL7-FHIR-quality-testing` | Inferno scorecards, CQL cohorts, Connectathon evidence |
| `rpms-fhir` | RPMS container bootstrap, sync, and dual-stack test gate |
| `tjson-tooling` | TJSON/`%wd` Rust tooling; browser WASM vendored here |
| `FHIR-source-files` | Source bundles and parity fixtures |
