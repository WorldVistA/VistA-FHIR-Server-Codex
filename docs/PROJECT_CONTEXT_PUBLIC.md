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

## `/tfhir` and `format=tjson` (troubleshooting)

- **`format=tjson`** on **`/tfhir`** returns **`Content-Type: text/html; charset=utf-8`** and renders the stored bundle in a browser-friendly **`&lt;pre&gt;`** via the shared `%wd` / `%wdgraph` tooling.
- Use **`&`** between query parameters: `.../tfhir?ien=1524&format=tjson` (not a second **`?`**).
- Shared `tjson` internals, `%wd` / `%wdgraph` maintainer notes, deploy scripts, and the Rust shim now live outside this repo in the sibling local repo **`tjson-tools`**.
- If a site override still sets **`^%WDG("tjson-args")="-C"`**, clear it unless that specific **`tjson`** build implements **`-C`**.

## Docker restart and the M web listener (`%webreq`)

After **`docker restart …`**, restart **`%webreq`** before HTTP checks; **`GET /showfhir`**, **`/tfhir`**, **`/fhir`**, etc. on the mapped port may reset until you do. **Canonical steps** (M commands, `docker exec` one-liner, **`^%webhttp`** check): **`~/ops/agent-context/vista-container-developer-guide.md`** — **§10** (and **§9** troubleshooting bullet).

## Related Documentation

- `docs/BUNDLE_REQUIREMENTS.md`
- `docs/NAMING_CONVENTIONS.md`
- `docs/OPEN_QUESTIONS.md`
- `docs/UNRESOLVED_ISSUES.md`

