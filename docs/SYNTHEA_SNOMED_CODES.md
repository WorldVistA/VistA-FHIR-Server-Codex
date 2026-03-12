# Synthea SNOMED CT Codes — Categories and FHIR ValueSets

## Overview

Synthea (synthetic patient population simulator) uses **SNOMED CT** across its module JSON files to encode encounters, conditions, procedures, observations, allergies, and care plan activities. Codes appear in state definitions (e.g., `Encounter`, `Procedure`, `ConditionOnset`, `AllergyOnset`, `CarePlanStart`) under a `codes` array with `system`, `code`, and `display`.

**Source:** Module files in  
[https://github.com/synthetichealth/synthea/tree/master/src/main/resources/modules](https://github.com/synthetichealth/synthea/tree/master/src/main/resources/modules)

Synthea also supports **ValueSet URIs** (e.g. ECL-based) so that a random code from a value set is chosen at runtime when a terminology service is configured.

---

## Categories (by FHIR Resource Type)


| Category                 | FHIR Resource(s)     | Synthea Module Usage                                  | ValueSet ID in Bundle         |
| ------------------------ | -------------------- | ----------------------------------------------------- | ----------------------------- |
| **Encounter types**      | `Encounter`          | `Encounter` states: `codes` for type/reason           | `synthea-encounter-types`     |
| **Conditions**           | `Condition`          | `ConditionOnset` states                               | `synthea-conditions`          |
| **Procedures**           | `Procedure`          | `Procedure` states (screenings, tests, interventions) | `synthea-procedures`          |
| **Observations**         | `Observation`        | Vitals, labs, assessments (SNOMED CT and LOINC)       | `synthea-observations`        |
| **Allergy / reactions**  | `AllergyIntolerance` | `AllergyOnset`; allergens may use RxNorm              | `synthea-allergy-reactions`   |
| **Care plan activities** | `CarePlan`           | `CarePlanStart` activities                            | `synthea-careplan-activities` |
| **Immunizations**        | `Immunization`       | Vaccine product (CVX); SNOMED for procedure/reaction  | `synthea-immunizations`       |


---

## FHIR Document

The file `**Synthea_SNOMED_ValueSets.json`** in this directory is a FHIR **Bundle** of type `collection` containing one **ValueSet** per category above. Each ValueSet:

- Uses `http://snomed.info/sct` for SNOMED CT.
- Includes a **representative** set of codes found in Synthea modules (allergies, asthma, and related modules).
- Is not exhaustive; the full set of codes is defined across all module JSON files in the Synthea repository.

### Using the Bundle

- **Validation:** Load the Bundle into a FHIR server or validator; ValueSets can be used for validation of Synthea-generated resources.
- **Mapping:** Use the categories when building SNOMED→OS5/ICD/CPT maps (e.g. for VistA ingest) so that codes commonly produced by Synthea are covered.
- **Discovery:** To get the complete list of SNOMED codes, clone the Synthea repo and parse all `*.json` under `src/main/resources/modules` for `"system": "SNOMED-CT"` (or `"SNOMED-CT"`) and collect unique `code`/`display` by state type.

### Other Code Systems in Synthea

- **RxNorm:** Medications and some allergen codes.
- **CVX:** Vaccine product for Immunization.
- **LOINC:** Lab results and some observations.
- **ValueSet URIs:** ECL or `fhir_vs` style; expanded at runtime if a terminology server is configured.

---

## References

- [Synthea Generic Module Framework](https://github.com/synthetichealth/synthea/wiki/Generic-Module-Framework)
- [Synthea HL7 FHIR export](https://github.com/synthetichealth/synthea/wiki/HL7-FHIR)
- [ValueSet-based code selection (Synthea PR #709)](https://github.com/synthetichealth/synthea/pull/709)

