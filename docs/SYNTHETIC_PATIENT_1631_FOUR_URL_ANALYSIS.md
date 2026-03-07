# Synthetic Patient 1631: Four-URL Analysis

This document ties together four endpoints that represent different stages of the same synthetic patient data flow.

## Scope

Analyzed endpoints:

1. `http://fhir.vistaplex.org:9080/vpr?dfn=1631`
2. `http://fhir.vistaplex.org:9080/fhir?dfn=1631`
3. `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,1636,%22json%22)`
4. `http://fhir.vistaplex.org:9080/gtree/%25wd(17.040801,3,1636,%22load%22)`

## Endpoint Roles

- `vpr?dfn=1631`: source clinical payload (VPR-style structure).
- `fhir?dfn=1631`: transformed FHIR bundle view served by the FHIR endpoint.
- `gtree ... "json"`: persisted raw imported bundle at graph-store node `^%wd(17.040801,3,1636,"json")`.
- `gtree ... "load"`: ingest/load audit log at `^%wd(17.040801,3,1636,"load")`.

## Identity Crosswalk (Evidence They Are The Same Patient)

Common identity values observed across the four views:

- Patient name: `LUETTGEN467,AHMAD182`
- Administrative patient ID: `DFN 1631`
- SSN value: `999773341`
- Source bundle UUID: `6fe5588b-d489-4883-afe2-159754d5ac23`
- Load-log import return: `1631^999773341^LUETTGEN467,AHMAD182`
- Load-log status: `DFN 1631`, `ICN 2373970753V703537`

Conclusion: all four URLs represent the same synthetic patient record at different processing layers.

## Data Flow View

1. Source clinical data is exposed by `vpr?dfn=1631`.
2. A larger source bundle is persisted in graph storage (`"json"` node, IEN `1636`).
3. That source is ingested by loader routines (documented in `"load"` node logs/status).
4. The FHIR endpoint serves a downstream transformed bundle (`fhir?dfn=1631`).

## Quantitative Parity Snapshot

### VPR domain totals (`vpr?dfn=1631`)

- demographics: `1`
- reactions: `1`
- problems: `4`
- vitals: `9`
- labs: `0`
- meds: `6`
- immunizations: `8`
- visits: `12`

### FHIR endpoint resource mix (`fhir?dfn=1631`)

- `Patient`: `1`
- `Encounter`: `12`
- `Condition`: `4`
- `Observation`: `23`
- `MedicationRequest`: `6`
- `Immunization`: `8`
- Total entries: `54`

### Persisted graph bundle (`... "json"`)

- Bundle type shown in store: `collection`
- Entry count shown in store: `182`
- Includes broader resource set than `/fhir` output (for example `Goal`, `CarePlan`, `Procedure`, `DiagnosticReport`, and `Medication` resources).

## Loader Outcomes From `... "load"`

### Successful domains (examples)

- Patient: loaded (`IMPORTPT^ISIIMP03` return code `0`)
- Encounters: loaded (`ENCTUPD^SYNDHP61`)
- Immunizations: loaded (`IMMUNUPD^ZZDHP61`)
- Medications: loaded (`WRITERXRXN^SYNFMED`)
- Procedures: loaded (`PRCADD^SYNDHP65`)
- CarePlans: loaded (`CPLUPDT^SYNDHP91`)

### Important non-success or partial-success findings

- **Condition not loaded due inactive mapped ICD**
  - Example log text: `1107 is not an active ICD code`
  - Context: SNOMED `26929004` mapped to ICD `294.1` for one encounter, then rejected by loader.

- **Condition not loaded due duplicate diagnosis on visit**
  - Example messages:
    - `Problem with DX code 12823 already exists for visit 14639`
    - `Problem with DX code 500571 already exists for visit 14643`
    - `Problem with DX code 509328 already exists for visit 14644`
    - `Problem with DX code 500734 already exists for visit 14645`

- **BMI observations skipped in vitals loader**
  - Repeated issue: `Snomed Code not found for vitals code: 39156-5 -- skipping`
  - Effect: height/weight/BP/temp load, BMI does not.

## Representation Differences Across Layers

- Blood pressure in source/store appears componentized (`systolic` + `diastolic`), while load path combines to a single `value` string like `181/101` for vitals update.
- `/fhir` output is narrower than `"json"` store content (fewer resource types exposed).
- Some source records are expected to be absent downstream due to loader-level dedupe or terminology constraints (inactive ICD, duplicate visit diagnosis, missing SNOMED map for BMI).

## Practical Use

For debugging one patient end-to-end:

1. Start at `vpr?dfn=<dfn>` for source domain totals.
2. Inspect `"json"` for full stored imported graph payload.
3. Inspect `"load"` for domain-level loader actions and failure reasons.
4. Compare resulting `/fhir` bundle to identify transformation and load-time drop-offs.

