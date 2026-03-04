# Unresolved Issues

Track known issues that are not yet solved.

## Current Issues
- Issue: Final JSON serialization mechanism for bundle responses is not selected.
  - Impact: Bundle assembly can proceed, but API cannot return final JSON text until serializer approach is finalized.
  - Affected files/components: `src/C0FHIR.m`, `src/C0FHIRBU.m`, response layer.
  - Workaround (if any): Build local M structures first; serialize in a later integration step.
  - Owner: George Lilly
  - Target resolution date:
  - Status: Open

## Template For New Issues
- Issue:
- Impact:
- Affected files/components:
- Workaround (if any):
- Owner:
- Target resolution date:
- Status:
