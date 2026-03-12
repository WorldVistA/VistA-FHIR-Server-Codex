# Steps Taken

Use this file as a chronological log of concrete implementation work.

## 2026-03-03
- Established source convention: MUMPS routines go in `src/`.
- Established documentation convention: detailed tracking files go in `docs/`.
- Established namespace convention: use `C0FHIR` for all new MUMPS routines and new DDE entities.
- Added starter routine scaffold in `src/C0FHIR.m`.
- Added bundle dispatcher entry point `GETBNDL^C0FHIR`.
- Added bundle orchestration scaffold routine `src/C0FHIRBU.m`.
- Added documentation tracking structure in `docs/`.
- Added namespace reference documentation in `docs/NAMING_CONVENTIONS.md`.
- Added a Phase 1 resource naming map for routine names and DDE entity patterns.
- Added bundle response requirements in `docs/BUNDLE_REQUIREMENTS.md`.
- Added `docs/PROJECT_CONTEXT_PUBLIC.md` as a repository-safe context document.
- Selected `ENCODE^XLFJSON` as the JSON encoding standard and added `GETBNDLJ^C0FHIR` / `TOJSON^C0FHIRBU` scaffolding.
- Added web service entry point `GETFHIR^C0FHIR(RTN,FILTER)` with URL-parameter mapping (for example `FILTER("dfn")=dfn`).
- Updated patient builder contract to `GETPAT^C0FHIR(RTN,DFN)` so bundle generators pass the full in-flight bundle array by reference.
- Read and analyzed the `FHIR-source-files` reference corpus (DDE, VPR, and sample bundles) to drive first-version design.
- Implemented first-version transaction bundle builder with de-duplicated `Patient` and `Encounter` entries.
- Added encounter-centric and date-range encounter loading (`^AUPNVSIT("AET",DFN,...)`) into `BYENC^C0FHIRBU` and `BYDATE^C0FHIRBU`.
- Added `docs/FHIR_SOURCE_FINDINGS.md` to document analysis findings from `FHIR-source-files` and resulting implementation decisions.
- Added `docs/VPR_CONTAINER_FHIR_MAPPING.md` mapping all listed VPR container domains to FHIR resources and source file numbers.
- Updated mode resolution so requests with no encounter/date filters default to all-encounters date-range behavior.
- Added first-pass `Condition` and `Observation` resource builders and wired them into encounter/date-range bundle generation.
- Added first-pass `AllergyIntolerance` and `MedicationRequest` resource builders and wired them into encounter/date-range bundle generation.
- Added first-pass `Immunization` and laboratory (`Observation`) resource builders and wired them into encounter/date-range bundle generation.
- Added `docs/TEST_SERVER_VALIDATION.md` to document `dfn`-based VPR test server parity checks and a baseline validation case.
- Added `^DPT("B")` `gtree` endpoint guidance to document how to discover patient `dfn` values from the test server.
- Added graph-store `DFN` index guidance (`^%wd(17.040801,3,"DFN",DFN,IEN)`) for tracing patients back to original imported Synthea source records.
- Added explicit graph-store JSON retrieval pattern (`gtree/%25wd(17.040801,3,<IEN>,%22json%22)`) with example IEN lookup workflow.
- Added graph-store load log retrieval pattern (`gtree/%25wd(17.040801,3,<IEN>,%22load%22)`) and documented how it supports import-vs-mapping parity debugging.
- Replaced fragile `VPRDLR` helper calls in lab extraction with direct normalized line building from `^TMP("LRRR",...)` to avoid hidden local-variable assumptions.
- Normalized non-canonical FileMan time components (overflow seconds/minutes) before FHIR `dateTime` serialization.
- Switched response envelope semantics for `GET /fhir` to `Bundle.type="collection"`, removed transaction request metadata, and moved entry `fullUrl` generation to valid `urn:uuid:<uuid>` values.
- Added post-encoding JSON normalization for numeric-literal `id` and `code` keys so those fields emit as JSON strings.
- Added RPC entry points `RPCFHIR^C0FHIR` (scalar params) and `RPCFHIRA^C0FHIR` (array params) as wrappers to the existing `GETFHIR^C0FHIR` request flow.
- Added RPC gateway routine `src/C0FHIRGF.m` with `GENFULL^C0FHIRGF` for Broker-compatible parameter naming (`DFN,ENCPTR,SDT,EDT,MAX,MODE`).
- Added environment setup routine `src/C0FHIRSE.m` to register/update RPC `C0FHIR GET FULL BUNDLE` and context option `C0FHIR CONTEXT` in files `#8994` and `#19`.
- Added optional domain filtering (`domains`) so bundles can be requested by domain (`encounter`, `condition`, `vitals`, `allergy`, `medication`, `immunization`, `labs`) across web and RPC entry points.
- Refactored oversized `C0FHIR` logic into helper routines (`C0FHIRD`, `C0FHIRM`, `C0FHIRL`) while preserving public entry points in `C0FHIR`.
- Added first-pass `Procedure` resource builders (surgery, radiology, clinical procedures, and V-CPT sources) and wired `procedures` domain filtering into encounter/date-range bundle generation, RPC descriptions, and requirements docs.

## Template For New Entries
- Date:
- Change:
- Files touched:
- Reason:
- Validation performed:
- Next follow-up:
