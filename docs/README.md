# Documentation Index

This directory stores detailed project documentation for implementation tracking.

- `PROJECT_CONTEXT_PUBLIC.md`: Repository-safe project goals, scope, and constraints.
- `FHIR_SOURCE_FINDINGS.md`: Findings from source corpus analysis and implementation implications.
- `VPR_CONTAINER_FHIR_MAPPING.md`: VPR container/domain mapping to FHIR resources with source file numbers.
- `NAMING_CONVENTIONS.md`: Namespace standards for routines and DDE entities.
- `BUNDLE_REQUIREMENTS.md`: Single-bundle response behavior and query modes.
- `TEST_SERVER_VALIDATION.md`: How to use the test VPR endpoint (`dfn`) for bundle parity checks.
- `STEPS_TAKEN.md`: Chronological log of work completed.
- `OPEN_QUESTIONS.md`: Questions that still need answers before or during implementation.
- `UNRESOLVED_ISSUES.md`: Known issues, blockers, and remaining gaps.
- `SYNTHETIC_PATIENT_1631_FOUR_URL_ANALYSIS.md`: End-to-end crosswalk of VPR, FHIR, graph JSON, and load-log views for one synthetic patient.
- `MULTIREPO_WORKSPACE_GUIDE.md`: Workspace profiles, repo roles (`SYNTHEA`/`ISI`/`SYN`/`FHIR`/`SOURCE`), and cross-repo validation workflow.
- `SYN_GAP_REPAIR_WORKFLOW.md`: Analyze ingested-patient gaps and selectively rerun `SYN` loader categories after routine improvements.

Update these files as work progresses so implementation state is always clear.
