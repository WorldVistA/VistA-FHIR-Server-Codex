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
- Bundle `type` is `transaction` (v1 target based on source sample bundles).
- JSON output is encoded using `ENCODE^XLFJSON`.
- Errors are returned as `OperationOutcome`.
- Web service entry point is `GETFHIR^C0FHIR(RTN,FILTER)`.
- URL parameters are passed in `FILTER`, for example:
  - `FILTER("dfn")=12345`
  - `FILTER("encounter")=<enc-id>`
  - `FILTER("start")=<fm-date-time>`
  - `FILTER("end")=<fm-date-time>`
  - `FILTER("mode")="encounter"` or `"daterange"` (optional when inferable)
- Default mode behavior:
  - If no `encounter`, `start`, or `end` is provided, mode defaults to `daterange` and returns all encounters for the patient (subject to `max`).

## Implementation Notes
- Entry points:
  - `GETFHIR^C0FHIR`
  - `GETBNDL^C0FHIR`
  - `GETBNDLJ^C0FHIR`
  - `BYENC^C0FHIRBU`
  - `BYDATE^C0FHIRBU`
- Resource builders:
  - `GETPAT^C0FHIR(RTN,DFN)` appends the `Patient` resource into the in-flight bundle array.
  - `GETENC^C0FHIR(RTN,ENCIEN,DFN)` appends an `Encounter` resource into the in-flight bundle array.
- Serializer helper:
  - `TOJSON^C0FHIRBU` (wraps `ENCODE^XLFJSON`)
- First-version scope currently implemented:
  - `Patient` + `Encounter` bundle entries in transaction envelope.
  - Date-range encounter collection from `^AUPNVSIT("AET",DFN,...)`.
