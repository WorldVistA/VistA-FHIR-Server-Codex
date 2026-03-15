# CPT Happy Path Validation (2026-03-15)

## Goal

Keep encounter CPT fallback behavior available for genuinely unmapped encounter codes while:

- preventing encounter-coded CPT/OS5 rows from being exported as FHIR `Procedure`
- ensuring fresh patient loads use specific encounter OS5 mappings when those mappings exist
- validating procedure CPT/OS5 mapping on a newly loaded patient

## Root Causes Identified

### 1) Encounter-coded V CPT rows leaked into FHIR `Procedure`

`C0FHIRP` was exporting V CPT rows without distinguishing:

- encounter-style CPT/OS5 codes that belong on `Encounter`
- actual procedure CPT/OS5 codes that belong on `Procedure`

This produced placeholder-looking `Procedure` rows such as `OUTPATIENT ENCOUNTER`.

### 2) One common encounter SNOMED still fell through to fallback

Fresh-patient validation showed that encounter SNOMED `410620009` (`Well child visit`) was not present in the `sct2os5` map. The loader therefore used the existing fallback `6456Q`.

The fallback itself was not removed. The gap was that this code should no longer have needed it.

### 3) Two GT.M-specific loader faults interrupted fresh-load validation

Fresh Cody-based validation also exposed two runtime issues in the SYN loader repo:

- `SYNDHP61` could probe `^ICPT("B","")` when a mapping result was blank, causing a null-subscript fault in GT.M direct mode
- `MAPERR^SYNQLDM` used a null-subscript `$ORDER` pattern that failed under GT.M when logging unmapped terminology codes

Those bugs blocked end-to-end validation until fixed.

## Changes Implemented

### FHIR repo changes

In `VistA-FHIR-Server-Codex`:

- `src/C0FHIRP.m`
  - filters encounter-only V CPT rows out of FHIR `Procedure`
  - checks encounter-only SNOMED membership by walking `^SYN("2002.030","sct2os5","inverse",...)`
  - treats `410620009` as an encounter code for export filtering
- `codes/encounter_sct.json`
  - updated to include `410620009` (`Well child visit (procedure)`) so the repo-level encounter code set matches observed source data

### SYN loader repo changes

In `VistA-FHIR-Data-Loader`:

- `src/SYNDHP61.m`
  - correctly handles `$$MAP^SYNDHPMP` return values in `status^code` form
  - guards blank `^ICPT("B",...)` lookups
  - preserves the existing `6456Q` fallback when no specific mapping exists
- `src/SYNQLDM.m`
  - makes `MAPERR` safe for GT.M runtime behavior when recording unmapped terminology codes
- `src/SYNOS5D4.m`
  - adds `410620009^3282K^Well child visit (procedure)`

### Runtime follow-up

After deploying the loader changes into the test runtime:

- `LOADOS5^SYNOS5LD` was rerun
- `EN^SYNOS5PT` was rerun so File 81/Lexicon contained the new OS5 code
- verification showed `$$MAP^SYNDHPMP("sct2os5","410620009")` returned `1^3282K`
- verification showed `^ICPT("B","3282K")` existed in the test runtime

## Validation

### Existing patient export sanity check

Patient `DFN 1642` was rechecked after the `C0FHIRP` filter change.

Observed `/fhir?dfn=1642` result:

- `Patient`: 1
- `Encounter`: 11
- `Observation`: 220
- `Procedure`: 11
- `OUTPATIENT ENCOUNTER` placeholder procedures: 0

This confirmed that encounter-coded CPT rows were no longer leaking into exported `Procedure` resources for the already-loaded patient.

### Intermediate fresh-load diagnosis (`DFN 1644`)

The first fresh Cody load identified the remaining happy-path issues:

- `encounters`: `58/58`
- `procedures`: initially blocked before rerun by the `MAPERR^SYNQLDM` GT.M fault
- after targeted rerun, `procedures`: `49/49`

Most importantly, raw V CPT inspection showed:

- `6456Q` rows: 10
- Cody source encounter SNOMED `410620009` rows: 10

That matched the missing-map hypothesis exactly and confirmed the fallback was being used only because `410620009` was not yet in `sct2os5`.

### Final fresh-load proof (`DFN 1645`)

A cloned Cody bundle with fresh patient identifiers was created locally and loaded through the normal `FILE^SYNFHIR` path to validate a truly new patient after all fixes were in place.

Load result:

- patient name: `Olson653X,Cody990`
- `DFN`: 1645
- graph IEN: 1651

Source-vs-loaded counts:

- `encounters`: `58/58`
- `procedures`: `49/49`
- `immunizations`: `15/15`
- `allergy`: `1/1`
- `meds`: `3/3`
- `careplan`: `5/5`

Observed `/fhir?dfn=1645` result:

- `Patient`: 1
- `Encounter`: 57
- `Observation`: 64
- `Immunization`: 15
- `Condition`: 4
- `AllergyIntolerance`: 1
- `MedicationRequest`: 3
- `Procedure`: 64

Critical CPT validation results for `DFN 1645`:

- exported placeholder `OUTPATIENT ENCOUNTER` procedures: 0
- exported `6456Q` procedures: 0
- raw V CPT rows: 122
- raw V CPT `6456Q` rows: 0
- raw V CPT `3282K` rows: 10

Representative raw V CPT distribution for the fresh patient included:

- `10 | 3282K`
- `41 | 8640I`
- `3 | 5724Q`
- `2 | 5064I`
- `1 | 3447O`
- `1 | 9711L`
- `41 | 9808L`

That confirmed the previously missing well-child encounters now use the specific OS5 mapping (`3282K`) instead of the generic fallback.

## Outcome

- Encounter/procedure export separation now behaves correctly for the validated cases.
- The `6456Q` fallback remains available for genuinely unmapped encounter codes.
- `410620009` no longer needs the fallback because it now has a specific OS5 mapping.
- A fresh patient load proved that encounter and procedure CPT/OS5 mappings both work without exporting encounter placeholders as `Procedure`.

## Remaining Non-CPT Gaps

The fresh patient still shows unrelated ingestion/export gaps that were not part of this CPT happy-path work:

- labs: `20/47`
- vitals: `64/86`
- conditions: `4/6`
- exported `Encounter`: 57 vs loaded `Encounter`: 58

These remain good follow-up candidates, but they are separate from the encounter/procedure CPT mapping fix validated here.
