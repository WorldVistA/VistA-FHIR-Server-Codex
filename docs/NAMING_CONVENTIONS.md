# Naming Conventions

This project uses a single namespace for all new FHIR implementation artifacts.

## MUMPS Routine Namespace
- All new MUMPS routine names must start with `C0FHIR`.
- Example routine names:
  - `C0FHIR`
  - `C0FHIRBU`
  - `C0FHIRPT`
  - `C0FHIREN`
  - `C0FHIROB`

## DDE Entity Namespace
- All new DDE entities created for this project must use the `C0FHIR` namespace prefix.
- Entity naming should remain consistent with VistA conventions while preserving the `C0FHIR` prefix.

## Phase 1 Resource Naming Map
Use this map for the first implementation wave to keep naming consistent.

| FHIR Resource | MUMPS Routine | DDE Entity Name Pattern |
| --- | --- | --- |
| `Bundle` (orchestration) | `C0FHIRBU` | `C0FHIRBundle` |
| `Patient` | `C0FHIRPT` | `C0FHIRPatient` |
| `Encounter` | `C0FHIREN` | `C0FHIREncounter` |
| `Observation` | `C0FHIROB` | `C0FHIRObservation` |
| `Condition` | `C0FHIRCO` | `C0FHIRCondition` |
| `AllergyIntolerance` | `C0FHIRAL` | `C0FHIRAllergyIntolerance` |
| `MedicationRequest` | `C0FHIRMR` | `C0FHIRMedicationRequest` |

Notes:
- Routine names in this map are kept to 8 characters for broad VistA compatibility.
- If local DDE naming rules require a separator, keep the `C0FHIR` prefix and adapt only the separator format.

## Intent
- Keep all project-specific FHIR logic clearly separated from existing routines/entities.
- Make ownership and maintenance boundaries explicit.
