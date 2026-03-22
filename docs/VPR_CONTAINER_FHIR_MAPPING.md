# VPR Container to FHIR Mapping

Source analyzed: `/home/glilly/FHIR-source-files/vpr-containers.txt` (24 container types).

This mapping is the first implementation target map for FHIR R4 resource alignment.

For the narrower set of bundle domains currently emitted by the in-repo `C0FHIR*` routines, see `docs/CURRENT_DOMAIN_EXTRACTION_NOTES.md`. That document tracks the active extraction surface; this file remains the broader VPR-container roadmap.

| # | VPR Container | VistA Source File(s) | VPR Update Entity(ies) | Proposed FHIR Domain/Resource(s) | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | `PATIENT` | `2` | `VPR PATIENT` | `Patient` | Core demographics and identifiers. |
| 2 | `ENCOUNTER` | `9000010`, `405`, `230` | `VPR VISIT`, `VPR ADMISSION`, `VPR EDP LOG` | `Encounter` | Include delete semantics from `VPR VISIT STUB`. |
| 3 | `ADVANCE DIRECTIVE` | `8925` | `VPR ADVANCE DIRECTIVE` | `Consent` (primary), `DocumentReference` (secondary) | TIU-based directive content can be represented as a document. |
| 4 | `ALERT` | `26.13`, `8925` | `VPR PATIENT RECORD FLAG`, `VPR CW NOTES` | `Flag` | Clinical warning/flag behavior aligns to `Flag`. |
| 5 | `ALLERGY` | `120.8`, `120.86` | `VPR ALLERGY`, `VPR ALLERGY ASSESSMENT` | `AllergyIntolerance` | Includes assessment/no-known-allergy context handling. |
| 6 | `APPOINTMENT` | `2.98`, `41.1` | `VPR APPOINTMENT`, `VPR SCHEDULED ADMISSION` | `Appointment` | Scheduled encounters and admissions. |
| 7 | `PROBLEM` | `9000011`, `783` | `VPR PROBLEM`, `VPR FIM` | `Condition` | Problem list conditions. |
| 8 | `DIAGNOSIS` | `9000010.07`, `45` | `VPR V POV`, `VPR PTF` | `Condition` | Encounter-linked diagnoses. |
| 9 | `DOCUMENT` | `8925`, `74`, `63.05`, `63.08` | `VPR DOCUMENT`, `VPR RAD REPORT`, `VPR LRMI REPORT`, `VPR LRAP REPORT` | `DocumentReference`, `DiagnosticReport` | TIU notes and diagnostic reports. |
| 10 | `LAB ORDER` | `100` | `VPR LAB ORDER` | `ServiceRequest` | Category laboratory. |
| 11 | `RAD ORDER` | `100` | `VPR RAD ORDER` | `ServiceRequest` | Category imaging. |
| 12 | `OTHER ORDER` | `100` | `VPR OTHER ORDER` | `ServiceRequest` | Non-lab/non-rad orders. |
| 13 | `MEDICATION` | `100` | `VPR MEDICATION` | `MedicationRequest` | Expand later to dispense/administration where available. |
| 14 | `VACCINATION` | `9000010.11`, `9000010.23`, `9000010.707` | `VPR VACCINATION`, `VPR VACC HF REFUSAL`, `VPR ICR EVENT` | `Immunization` | Refusal/contraindication data maps to status reason extensions. |
| 15 | `OBSERVATION` | `120.5` | `VPR VITAL MEASUREMENT` | `Observation` | Vitals and measured findings. |
| 16 | `PHYSICAL EXAM` | `9000010.13` | `VPR V EXAM` | `Observation` | Exam findings as observations. |
| 17 | `PROCEDURE` | `130`, `9000010.18`, `45.05` | `VPR SURGERY`, `VPR V CPT`, `VPR PTF 601` | `Procedure` | Surgical and CPT/ICD procedure history. |
| 18 | `FAMILY HISTORY` | `9000010.23` | `VPR FAMILY HISTORY` | `FamilyMemberHistory` | Family history statements. |
| 19 | `ILLNESS HISTORY` | *(none listed)* | *(none listed)* | `Condition` (provisional) | Source mapping not defined in container list; confirm upstream source. |
| 20 | `SOCIAL HISTORY` | `9000010.23`, `790.05` | `VPR SOCIAL HISTORY`, `VPR PREGNANCY` | `Observation` (social-history), `Condition` (pregnancy when applicable) | Pregnancy handling may require profile-specific rules. |
| 21 | `REFERRAL` | `123` | `VPR REFERRAL` | `ServiceRequest` | Referral requests to services/specialties. |
| 22 | `PROGRAM MEMBERSHIP` | *(none listed)* | *(none listed)* | `EpisodeOfCare` (provisional) | Source mapping not defined in container list; confirm semantics. |
| 23 | `MEMBER ENROLLMENT` | `2.312` | `VPR INSURANCE` | `Coverage` | Insurance enrollment/coverage details. |
| 24 | `MEDICAL CLAIM` | *(none listed)* | *(none listed)* | `Claim`, `ExplanationOfBenefit` (provisional) | Container exists but source mapping is not shown in the list. |

## Immediate Build Priority
- Phase 1 is unchanged: `Patient`, `Encounter`, `Observation`, `Condition`, `AllergyIntolerance`, `MedicationRequest`.
- Current in-repo extraction now extends beyond the original Phase 1 baseline to include `Immunization`, `Procedure`, and lab-result `Observation` / panel `DiagnosticReport`; see `docs/CURRENT_DOMAIN_EXTRACTION_NOTES.md` for the implemented bundle-domain behavior.
- The remaining container mappings in this document define the extension roadmap after Phase 1 parity.
