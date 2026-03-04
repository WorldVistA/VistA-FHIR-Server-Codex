# Unresolved Issues

Track known issues that are not yet solved.

## Current Issues
- Issue: Terminology and profile alignment are still first-pass for newly added `AllergyIntolerance`, `MedicationRequest`, `Immunization`, and laboratory `Observation` mappings.
  - Impact: Core resources are present, but some coding systems and field-level profile details may need refinement for strict US Core/profile validation (for example immunization status/source nuances and lab result/profile constraints).
  - Affected files/components: `src/C0FHIR.m`, `docs/BUNDLE_REQUIREMENTS.md`.
  - Workaround (if any): Use current mappings for functional bundle output and iterate terminology/profile conformance in follow-up updates.
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
