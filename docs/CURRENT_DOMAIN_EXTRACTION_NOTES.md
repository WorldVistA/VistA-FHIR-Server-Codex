# Current Domain Extraction Notes

This document tracks the domains currently emitted by the in-repo `C0FHIR*` bundle builders.

It is intentionally narrower than `docs/VPR_CONTAINER_FHIR_MAPPING.md`:

- This file answers "what does the repo extract into FHIR bundles today?"
- The mapping file answers "how do the full VPR container types line up with the long-term FHIR roadmap?"

## Bundle Behavior

- `Patient` is always included as the anchor resource in bundle output.
- The optional `domain` / `domains` request filter narrows the additional clinical domains.
- Current alias normalization lives in `DOMTOK^C0FHIR`.
- The implemented bundle-domain filters are smaller than the full VPR container list.

## Current In-Repo Coverage

| Bundle Domain | Request Tokens | FHIR Resource(s) Emitted | Current Notes |
| --- | --- | --- | --- |
| `Patient` | always included; `patient`, `pat` | `Patient` | Added unconditionally by `GETPAT^C0FHIR`. Current mapping is a direct demographic pass over file `#2`: patient name, gender, birth date, and SSN identifier when present. Using `domains=patient` effectively gives a patient-only bundle because the clinical domains are filterable but the patient anchor is not optional. |
| `Encounter` | `encounter`, `encounters`, `enc`, `visit`, `visits` | `Encounter` | Uses `EN1^VPRDVSIT`. Encounter mode takes one visit IEN; date-range mode walks `^AUPNVSIT("AET",DFN,...)`. Current output includes encounter class, type, participants, facility, clinic/location, stop-code-backed service type, and reason when the source data provides them. |
| `Condition` | `condition`, `conditions`, `problem`, `problems` | `Condition` | Problem-list extraction only. Uses `LIST^GMPLUTL2` plus `EN1^VPRDGMPL`, then filters by problem onset date when a date window is supplied. This is narrower than the full roadmap because encounter diagnoses remain a separate mapping concern. |
| `Vitals` | `obs`, `observation`, `observations`, `vital`, `vitals` | `Observation` | Vital-sign observations only, not every observation-shaped VPR domain. Uses `GMRVUT0` and `EN1^VPRDGMV` for the current vital set (`BP`, `T`, `R`, `P`, `HT`, `WT`, `CVP`, `CG`, `PO2`, `PN`). Emits `Observation.category=vital-signs`; numeric values become `valueQuantity`, otherwise `valueString`. |
| `Allergy` | `allergy`, `allergies`, `algy`, `allergyintolerance` | `AllergyIntolerance` | Uses `EN1^GMRADPT` and `EN1^VPRDGMRA`. Current code maps category, code, reactions, comments, severity/criticality, and verification/clinical status. The VPR "assessment / no-known-allergy" path is still skipped when there are no explicit allergy entries. |
| `Medication` | `med`, `meds`, `medication`, `medications`, `rx`, `medicationrequest` | `MedicationRequest` | Order-based medication extraction via `OCL^PSOORRL` and `EN1^VPRDPSOR`. Current output covers intent/status, authored date, requester, free-text sig, dose route/timing, dispense quantity, days supply, refills, and VUID/local drug identifiers when available. It does not yet emit dispense or administration resources. |
| `Immunization` | `imm`, `imms`, `immunization`, `immunizations` | `Immunization` | Uses `SORT^VPRDPXIM` and `EN1^VPRDPXIM`. Current mapping includes CVX and CPT coding, encounter link, performers, lot/expiration/manufacturer, route/site, dose quantity, series, and free-text notes. Contraindicated source rows currently map to `status=not-done`. |
| `Procedure` | `proc`, `procs`, `procedure`, `procedures` | `Procedure` | Aggregates several VistA procedure-like sources: surgery (`VPRDSR`), radiology (`VPRDRA`), clinical procedures (`MDPS1`), and V CPT rows. Encounter-only CPT rows are filtered out so they enrich `Encounter.type` instead of creating duplicate `Procedure` resources. |
| `Labs` | `lab`, `labs`, `laboratory`, `laboratories` | `Observation`, `DiagnosticReport` | Result-oriented lab extraction, not lab-order extraction. Uses `RR^LR7OR1` for chemistry and microbiology results, emits `Observation.category=laboratory`, and creates panel `DiagnosticReport` resources when multiple chemistry observations share an accession. This means the current `labs` domain overlaps the broader observation/report roadmap more than the separate `LAB ORDER` VPR container row. |

## Scope Notes

- `Patient` is always present in bundle output even when a narrower domain filter is used.
- `Condition` currently means problem-list conditions, not every diagnosis-like VPR source.
- `Vitals` and `Labs` are separate extraction paths even though both emit `Observation`.
- `Labs` currently represents result/report content, not `ServiceRequest` order content.
- Domains such as appointments, referrals, coverage, documents, claims, and consent remain roadmap items in `docs/VPR_CONTAINER_FHIR_MAPPING.md` rather than active bundle-domain filters.
