# Project Context (Public)

This file is the shareable, repository-safe project context for implementation and onboarding.

## Project

- Name: VistA FHIR Server
- Last Updated: 2026-03-03

## Objectives

- Build VistA-standard M (MUMPS) code that generates FHIR JSON from patient records.
- Create DDE entities aligned with the FHIR data model to support generation.
- Return exactly one FHIR `Bundle` JSON per request, including multi-domain supporting resources as needed.
- Support all VPR container domain types listed in `vpr-containers.txt` using the mapping defined in `docs/VPR_CONTAINER_FHIR_MAPPING.md`.

## Success Criteria

- Valid FHIR JSON is generated for all in-scope domains.
- Phase 1 domain coverage includes `Patient`, `Encounter`, `Observation`, `Condition`, `AllergyIntolerance`, and `MedicationRequest`.
- Generated resources validate against FHIR R4 base and applicable US Core profiles.
- The solution works on VistA systems with and without DDE installed.
- Request modes supported:
  - Encounter-centric bundle (encounter + linked supporting resources)
  - Date-range bundle (all in-scope encounters in range + linked supporting resources)

## Constraints

- Implementation language/runtime: M (MUMPS) on VistA.
- Namespace rule: all new routines and new DDE entities use the `C0FHIR` prefix.
- JSON serialization standard: `ENCODE^XLFJSON`.
- Compliance target: VistA standards and HL7 FHIR R4.

## Scope

### In Scope

- Domains currently handled by DDE and/or VPR.
- Phase 1 core resources listed above.

### Out of Scope

- FHIR domains not currently addressed by DDE or VPR.

## Key Decisions

- `C0FHIR` is the required namespace prefix for all new MUMPS routines and new DDE entities.
- One multi-domain FHIR `Bundle` is returned per request.
- `ENCODE^XLFJSON` is the standard serializer for bundle JSON output.

## Related Documentation

- `docs/BUNDLE_REQUIREMENTS.md`
- `docs/NAMING_CONVENTIONS.md`
- `docs/OPEN_QUESTIONS.md`
- `docs/UNRESOLVED_ISSUES.md`

