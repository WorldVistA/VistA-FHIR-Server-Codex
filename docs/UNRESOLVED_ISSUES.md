# Unresolved Issues

Track known issues that are not yet solved.

## Current Issues
- Issue: Remaining Phase 1 domains `AllergyIntolerance` and `MedicationRequest` are not yet mapped into bundle output.
  - Impact: Bundle now includes patient, encounter, condition, and observation content, but allergy and medication coverage is still incomplete for Phase 1.
  - Affected files/components: `src/C0FHIR.m`, `src/C0FHIRBU.m`, future domain routines (`C0FHIRAL`, `C0FHIRMR`).
  - Workaround (if any): Use current response for patient/encounter/problem/vitals and add allergy/medication resources in next iterations.
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
