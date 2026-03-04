# Bundle Response Requirements

This project returns exactly one FHIR JSON `Bundle` per request.

## Core Behavior
- Every request returns a single top-level `Bundle`.
- A bundle may include resources from multiple domains.
- Bundle entries are de-duplicated by `resourceType` + resource id.

## Supported Query Modes (Phase 1)

### Encounter-Centric Bundle
- Input: a specific encounter (and patient context as required).
- Output: one bundle containing:
  - The requested `Encounter` resource.
  - Supporting resources that are clinically or referentially required for that encounter (for example `Patient`, `Condition`, `Observation`, `AllergyIntolerance`, `MedicationRequest` when linked).

### Date-Range Bundle
- Input: patient and date range.
- Output: one bundle containing:
  - All in-scope `Encounter` resources in that range.
  - Supporting resources linked to those encounters.

## Response Contract
- Response `resourceType` is always `Bundle`.
- Bundle `type` is:
  - `collection` for encounter-centric requests.
  - `searchset` for date-range requests.
- Errors are returned as `OperationOutcome`.

## Implementation Notes
- Entry points:
  - `GETBNDL^C0FHIR`
  - `BYENC^C0FHIRBU`
  - `BYDATE^C0FHIRBU`
- Final JSON serialization layer is required to convert local M structures to JSON text.
