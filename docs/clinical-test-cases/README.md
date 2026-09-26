# Clinical test cases

This directory contains staged clinical test fixtures for the diagnosis picker,
Encounter note, and C0FW writeback path.

## Stage 1

`stage1-diagnosis-cases.json` is the first fixture manifest. It models only the
diagnosis interaction:

- ICD-10-CM and SNOMED CT diagnosis identity;
- SNOMED CT findings selected into `Encounter.reasonCode[]`;
- one V POV candidate;
- optional problem-list request;
- note support text;
- expected writeback outcomes.

The manifest intentionally does not model labs, vitals, or medications as
structured resources. Those belong in Stage 2 evidence fixtures using LOINC,
RxNorm, and other domain-specific code systems.

## Patient selection

Do not clean up routine test writebacks as the normal workflow. Treat filed
visits, notes, standard codes, and saved writeback artifacts as an audit trail.
When a patient's chart becomes too noisy to interpret, select a fresh plausible
patient for that case.

Each case includes `plausiblePatientHint` to guide patient choice. If no existing
patient fits the scenario, generate or import a synthetic patient and reuse that
patient until accumulated test history makes the case hard to read.

## Non-interactive smoke runner

Use:

```sh
node scripts/stage1-diagnosis-smoke.mjs --dry-run
node scripts/stage1-diagnosis-smoke.mjs --case t2dm-basic --dfn 418 --post
```

Default behavior is dry-run bundle validation. `--post` sends bundles to
`/updatepatient?dfn=<dfn>&load=1&returngraph=1`.

Important environment variables:

- `STAGE1_DFN`: default patient DFN when `--dfn` is omitted.
- `STAGE1_BASE_URL`: FHIR server base URL, default `http://127.0.0.1:9085`.
- `STAGE1_CASE`: comma-separated case IDs, equivalent to repeated `--case`.
- `STAGE1_POST=1`: post instead of dry-run.

The runner is meant to prove the Stage 1 writeback shape. It does not choose a
patient automatically; choose a plausible patient first, then pass that DFN.
