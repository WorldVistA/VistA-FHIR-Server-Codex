# Test Server Validation Notes

Use the VistA test VPR endpoint as a quick ground-truth source by patient `dfn`.

## DFN lookup

- Name index endpoint: `http://fhir.vistaplex.org:9080/gtree/DPT(%22B%22)`
- This exposes the `^DPT("B")` cross-reference (`PATIENT NAME -> DFN`).
- Use this endpoint to pick a patient and capture the corresponding `dfn`.
- Then run the VPR endpoint with that value: `http://fhir.vistaplex.org:9080/vpr?dfn=<DFN>`.
- Example from the sample index: `BARROWS368,BLAZE527 -> 1595`.
- Patients with numeric suffixes in their names are Synthea-generated synthetic patients (useful for repeatable test scenarios).

## Graph store source lookup

- Graph index endpoint: `http://fhir.vistaplex.org:9080/global/%25wd(17.040801,3,%22DFN%22)`
- This index maps patient DFNs to graph-store record IENs:
  - `^%wd(17.040801,3,"DFN",<DFN>,<IEN>)=""`
- Use it to locate the graph-store IEN for a known `dfn`.
- Then retrieve the original imported JSON payload from:
  - `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,<IEN>,%22json%22)`
- Example using `IEN 1534`:
  - `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,1534,%22json%22)`
- The `json` node contains the stored source bundle content (for example `entry` items) used for import comparison.
- Example observed mapping: `DFN 1595` appears at `IEN 1591`.

## Graph store load log lookup

- Load log endpoint pattern: `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,<IEN>,%22load%22)`
- This exposes the import/load trace written during Synthea-to-VistA ingest for that graph-store `IEN`.
- It includes per-domain loader sections (for example `Patient`, `encounters`, `conditions`, `immunizations`, `labs`, `vitals`) with:
  - `log` lines describing processing details and loader calls
  - `parms` values passed to loader routines
  - `status` nodes including load outcome
  - `vars` nodes with key source values used during import
- Example endpoint: `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,1534,%22load%22)`
- Use this when parity checks fail to determine whether a difference comes from:
  - source payload contents
  - import/load behavior (for example "cannotLoad"/"readyToLoad" cases)
  - FHIR mapping logic in `GETFHIR^C0FHIR`

## Endpoint

- Base pattern: `http://fhir.vistaplex.org:9080/vpr?dfn=<DFN>`
- Example: `http://fhir.vistaplex.org:9080/vpr?dfn=1595`

## Why this helps

- A single `dfn` request returns broad multi-domain VPR content.
- It is useful for quick parity checks while iterating `GETFHIR^C0FHIR`.
- It gives domain totals we can use as minimum/expected count checks.

## Practical workflow

1. Pick a `dfn` and inspect VPR domain totals from the test endpoint.
2. Run local `GET /fhir` for the same `dfn` and equivalent filter window.
3. Compare Bundle entry counts by resource type:
   - `Patient` vs demographics
   - `Encounter` vs visits
   - `Condition` vs problems
   - `Observation` vs vitals + labs
   - `AllergyIntolerance` vs reactions/allergies
   - `MedicationRequest` vs meds
   - `Immunization` vs immunizations
4. Record mismatches and whether they are expected (date/window/max/filter/profile reasons) or true mapping gaps.

## Baseline reference case: DFN 1595

Observed VPR totals from the test server sample:

- demographics: 1
- reactions: 1
- problems: 2
- vitals: 8
- labs: 0
- meds: 3
- immunizations: 14
- visits: 12

Expected first-pass FHIR implications for full-range queries:

- `Patient`: 1
- `Encounter`: up to 12
- `Condition`: up to 2
- `Observation`: at least 8 (vitals) plus labs in range
- `AllergyIntolerance`: up to 1
- `MedicationRequest`: up to 3
- `Immunization`: up to 14

## Notes and caveats

- Counts can differ due to request mode, date windows, and `max` limits.
- Some VPR containers do not map 1:1 to a single FHIR resource in first pass.
- This is a validation aid, not a strict conformance oracle.
- Synthea-derived cohorts are good for deterministic testing, but still validate mappings against non-synthetic patterns when available.
