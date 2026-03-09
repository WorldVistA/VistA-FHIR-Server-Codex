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
  - Supporting resources that are clinically or referentially required for that encounter (for example `Patient`, `Condition`, `Observation`, `AllergyIntolerance`, `MedicationRequest`, `Immunization`, and laboratory `Observation` resources when linked/in-range).

### Date-Range Bundle
- Input: patient and date range.
- Output: one bundle containing:
  - All in-scope `Encounter` resources in that range.
  - Supporting resources linked to those encounters.

## Response Contract
- Response `resourceType` is always `Bundle`.
- Bundle `type` is `collection` for `GET /fhir` read responses.
- Entry `fullUrl` values use `urn:uuid:<uuid>` format with valid UUIDs.
- JSON output is encoded using `ENCODE^XLFJSON`.
- Errors are returned as `OperationOutcome`.
- Web service entry point is `GETFHIR^C0FHIR(RTN,FILTER)`.
- RPC entry points are:
  - `RPCFHIR^C0FHIR(RTN,DFN,ENC,START,END,MAX,MODE,DOMAINS)` (scalar parameters)
  - `RPCFHIRA^C0FHIR(RTN,FILTER)` (array parameters)
  - `GENFULL^C0FHIRGF(RTN,DFN,ENCPTR,SDT,EDT,MAX,MODE,DOMAINS)` (Broker-oriented RPC wrapper)
- URL parameters are passed in `FILTER`, for example:
  - `FILTER("dfn")=12345`
  - `FILTER("encounter")=<enc-id>`
  - `FILTER("start")=<fm-date-time>`
  - `FILTER("end")=<fm-date-time>`
  - `FILTER("domains")="encounter,condition,vitals,labs"` (optional)
  - `FILTER("mode")="encounter"` or `"daterange"` (optional when inferable)
- Supported domain tokens:
  - `encounter`, `condition`, `vitals`, `allergy`, `medication`, `immunization`, `labs` (`all` keeps default behavior)
- Domain filtering behavior:
  - `Patient` is always included for referential context.
  - Other domains are included only when requested (or all when no domain filter is supplied).
- Default mode behavior:
  - If no `encounter`, `start`, or `end` is provided, mode defaults to `daterange` and returns all encounters for the patient (subject to `max`).

## Implementation Notes
- Entry points:
  - `GETFHIR^C0FHIR`
  - `RPCFHIR^C0FHIR`
  - `RPCFHIRA^C0FHIR`
  - `GENFULL^C0FHIRGF`
  - `GETBNDL^C0FHIR`
  - `GETBNDLJ^C0FHIR`
  - `BYENC^C0FHIRBU`
  - `BYDATE^C0FHIRBU`
- Environment/setup helper:
  - `EN^C0FHIRSE` registers RPC `C0FHIR GET FULL BUNDLE` and context option `C0FHIR CONTEXT`.
- Resource builders:
  - `GETPAT^C0FHIR(RTN,DFN)` appends the `Patient` resource into the in-flight bundle array.
  - `GETENC^C0FHIR(RTN,ENCIEN,DFN)` appends an `Encounter` resource into the in-flight bundle array.
  - `GETCOND^C0FHIR(RTN,DFN,BEG,END,MAX)` appends `Condition` resources from problem data.
  - `GETOBS^C0FHIR(RTN,DFN,BEG,END,MAX)` appends `Observation` resources from vitals data.
  - `GETALGY^C0FHIR(RTN,DFN,BEG,END,MAX)` appends `AllergyIntolerance` resources from allergy data.
  - `GETMED^C0FHIR(RTN,DFN,BEG,END,MAX)` appends `MedicationRequest` resources from medication/order data.
  - `GETIMM^C0FHIR(RTN,DFN,BEG,END,MAX)` appends `Immunization` resources from immunization data.
  - `GETLAB^C0FHIR(RTN,DFN,BEG,END,MAX)` appends laboratory `Observation` resources (chemistry/microbiology first pass).
- Serializer helper:
  - `TOJSON^C0FHIRBU` (wraps `ENCODE^XLFJSON`)
- First-version scope currently implemented:
  - `Patient`, `Encounter`, `Condition`, `Observation`, `AllergyIntolerance`, `MedicationRequest`, and `Immunization` bundle entries in collection envelope.
  - Date-range encounter collection from `^AUPNVSIT("AET",DFN,...)`.
  - Problem-list condition loading via `GMPLUTL2` + `VPRDGMPL`.
  - Vital-sign observation loading via `GMRVUT0` + `VPRDGMV`.
  - Laboratory observation loading (chemistry/microbiology first pass) via `LR7OR1` + `VPRDLR`.
  - Allergy loading via `GMRADPT` + `VPRDGMRA`.
  - Medication loading via `PSOORRL` + `VPRDPSOR`.
  - Immunization loading via `VPRDPXIM`.
