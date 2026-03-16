# Documentation Index

This directory stores detailed project documentation for implementation tracking.

- `PROJECT_CONTEXT_PUBLIC.md`: Repository-safe project goals, scope, and constraints.
- `FHIR_SOURCE_FINDINGS.md`: Findings from source corpus analysis and implementation implications.
- `VPR_CONTAINER_FHIR_MAPPING.md`: VPR container/domain mapping to FHIR resources with source file numbers.
- `NAMING_CONVENTIONS.md`: Namespace standards for routines and DDE entities.
- `BUNDLE_REQUIREMENTS.md`: Single-bundle response behavior and query modes.
- `TEST_SERVER_VALIDATION.md`: How to use the test VPR endpoint (`dfn`) for bundle parity checks, including `%webreq` startup/listener recovery steps for new containers.
- `CPT_HAPPY_PATH_VALIDATION_2026-03-15.md`: Cross-repo encounter/procedure CPT happy-path fixes and fresh-patient validation results, including confirmation that fallback remains available while `410620009` now maps to `3282K`.
- `VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`: Exact VEHU direct-deploy, file `81`/Lex refresh, `addPatient` registration, Dockerized Synthea generation, and host-local import workflow used to prepare for a fresh patient test.
- `M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`: Maintainer-facing root-cause analysis and validated hotfix for `%webrsp` runaway `mumps -direct` worker leaks.
- `STEPS_TAKEN.md`: Chronological log of work completed.
- `OPEN_QUESTIONS.md`: Questions that still need answers before or during implementation.
- `UNRESOLVED_ISSUES.md`: Known issues, blockers, and remaining gaps.
- `SYNTHETIC_PATIENT_1631_FOUR_URL_ANALYSIS.md`: End-to-end crosswalk of VPR, FHIR, graph JSON, and load-log views for one synthetic patient.
- `MULTIREPO_WORKSPACE_GUIDE.md`: Workspace profiles, repo roles (`SYNTHEA`/`ISI`/`SYN`/`FHIR`/`SOURCE`), and cross-repo validation workflow.
- `SYN_GAP_REPAIR_WORKFLOW.md`: Analyze ingested-patient gaps and selectively rerun `SYN` loader categories after routine improvements.

Update these files as work progresses so implementation state is always clear.
