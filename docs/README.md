# Documentation Index

This directory stores detailed project documentation for implementation tracking.

- `PROJECT_CONTEXT_PUBLIC.md`: Repository-safe project goals, scope, and constraints.
- Shared `tjson` tooling and `%wd` / `%wdgraph` maintainer material: sibling checkout **`~/work/vista-stack/tjson-tooling`** (symlink to **`~/tjson-tooling`**, git remote **`glilly/tjson-tools`**). Keep Codex focused on FHIR server behavior; browser TJSON vendoring lives in **`vendor/tjson/`** with runbook **`FHIR_BROWSER_TJSON_CODEX.md`**.
- `FHIR_SOURCE_FINDINGS.md`: Findings from source corpus analysis and implementation implications.
- `CURRENT_DOMAIN_EXTRACTION_NOTES.md`: Current in-repo bundle domains, request tokens, and implementation notes for what the server extracts today.
- `VPR_CONTAINER_FHIR_MAPPING.md`: VPR container/domain mapping to FHIR resources with source file numbers.
- `NAMING_CONVENTIONS.md`: Namespace standards for routines and DDE entities.
- `BUNDLE_REQUIREMENTS.md`: Single-bundle response behavior and query modes.
- `TEST_SERVER_VALIDATION.md`: How to use the test VPR endpoint (`dfn`) for bundle parity checks, including `%webreq` startup/listener recovery steps for new containers.
- `CPT_HAPPY_PATH_VALIDATION_2026-03-15.md`: Cross-repo encounter/procedure CPT happy-path fixes and fresh-patient validation results, including confirmation that fallback remains available while `410620009` now maps to `3282K`.
- `VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`: Exact VEHU direct-deploy, file `81`/Lex refresh, `addPatient` registration, Dockerized Synthea generation, and host-local import workflow used to prepare for a fresh patient test.
- `ICN_GENERATION_FHIR_INTAKE.md`: ICN assignment for FHIR intake (`newIcn2^SYNFPAT`): Synthea UUID, FHIR-supplied ICN, SSN pseudo-base (`8` + nine digits), and deploy notes for Data-Loader routines.
- `FHIR_BROWSER_TJSON_CODEX.md`: C0FHIR browser TJSON (WASM) integration: vendoring, `/filesystem/` paths, MIME/gzip pitfalls, `tjson_bg.wasm.b64`, sync scripts, **fhirdev22** (`fhirdev-codex-sync.sh`). Mirror under **`tjson-tools/docs/`** if you maintain that repo separately.
- `FHIR_INTAKE_CURL_RECIPES.md`: Copy-paste curls for container sync, VEHU bundle pull, `POST /addpatient` and `POST /updatepatient`, and smoke checks.
- `VISTA_VISIT_NOTE_ORDERING.md`: PCE visit vs TIU note ordering (visit-first integration vs CPRS note-first workflow), inpatient visit linkage and `ORWPCE1`/`PXRPC`/`PXAI` roles, and SYN/TIU caveats.
- `FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`: Incident note covering the root-level malicious binaries found inside `fhirdev`, the cron persistence chain removed from the container, and the separate `%webreq` CLOSE_WAIT worker leak.
- `FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md`: Characterization of `fhirdev` GT.M ZSY evidence showing HTTP workers accumulating CPU in `MATCHR+8^%webrsp` (and `URLDEC^%webutils`), distinct from malware and from `C0FHIR` application code; links to CLOSE_WAIT fix outline.
- `FHIRDEV22_FRESH_START_ZSY_SNAPSHOT_2026-03-27.md`: Baseline ZSY snapshot for live container `fhirdev22` (TaskMan, Mailman, HL7 on 5001, single `LOOP^%webreq` on `BG-S9080`); contrast reference for the MATCHR incident and post-cutover runbooks.
- `M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`: Fix outline for the server-side CLOSE_WAIT leak (WAIT/ETDC and timeout handling so workers close and exit when the client disconnects).
- `M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`: Maintainer-facing root-cause analysis and validated hotfix for `%webrsp` runaway `mumps -direct` worker leaks (SENDATA traversal).
- `STEPS_TAKEN.md`: Chronological log of work completed.
- `OPEN_QUESTIONS.md`: Questions that still need answers before or during implementation.
- `UNRESOLVED_ISSUES.md`: Known issues, blockers, and remaining gaps.
- `SYNTHETIC_PATIENT_1631_FOUR_URL_ANALYSIS.md`: End-to-end crosswalk of VPR, FHIR, graph JSON, and load-log views for one synthetic patient.
- `MULTIREPO_WORKSPACE_GUIDE.md`: Workspace profiles, repo roles (`SYNTHEA`/`ISI`/`SYN`/`FHIR`/`SOURCE`), and cross-repo validation workflow.
- `SYN_GAP_REPAIR_WORKFLOW.md`: Analyze ingested-patient gaps and selectively rerun `SYN` loader categories after routine improvements.

Update these files as work progresses so implementation state is always clear.
