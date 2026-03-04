# Unresolved Issues

Track known issues that are not yet solved.

## Current Issues
- Issue: Phase 1 domains beyond `Patient` and `Encounter` are not yet mapped into bundle output.
  - Impact: First version is usable for encounter spine generation but does not yet include `Observation`, `Condition`, `AllergyIntolerance`, or `MedicationRequest`.
  - Affected files/components: `src/C0FHIR.m`, `src/C0FHIRBU.m`, future domain routines (`C0FHIROB`, `C0FHIRCO`, `C0FHIRAL`, `C0FHIRMR`).
  - Workaround (if any): Use current response for encounter backbone and add related resources incrementally in next iterations.
  - Owner: George Lilly
  - Target resolution date:
  - Status: Open
- Resolved 2026-03-03: JSON serialization standard selected as `ENCODE^XLFJSON`.

## Template For New Issues
- Issue:
- Impact:
- Affected files/components:
- Workaround (if any):
- Owner:
- Target resolution date:
- Status:
