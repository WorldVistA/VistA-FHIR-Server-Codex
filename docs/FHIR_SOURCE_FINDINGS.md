# FHIR Source Findings

This document records findings from the source corpus in `/home/glilly/FHIR-source-files` and how they informed the first implementation.

## Analysis Scope
- Total files discovered: 118
- Core groups reviewed:
  - DDE/entity definitions and utilities (`entity*.txt`, `DDE*.m`, `DDERR.m`)
  - VPR extraction/runtime routines (`VPR*.m`)
  - Sample JSON bundles (3 patient bundles)
  - Project context (`PROJECT_CONTEXT.md`)

## DDE and Entity Findings
- DDE supports entity-driven extraction through `GET^DDE` and `EN^DDEGET`.
- Standard filter keys include patient and date-range forms (`patient`, `start`, `stop`, `id`).
- Query routines commonly populate `DLIST(n)=id` for downstream extraction.
- Entity definitions are stored in `^DDE(...)` with sequence/item metadata and data model indexing (`SDA`/`FHIR`).
- Practical implication:
  - DDE is a useful retrieval backbone and can be used incrementally for additional domains.
  - New entities should preserve the `C0FHIR` namespace convention defined in project docs.

## VPR Findings
- `GET^VPRDJ` is the main JSON extraction orchestration path in VPR and uses filter-driven dispatch.
- `VPRDVSIT` provides strong encounter extraction patterns; `EN1^VPRDVSIT` is useful for per-visit detail.
- `VPRDPT` provides broad patient demographics and identifiers.
- Domain routines exist for Phase 1 targets:
  - `Patient`: `VPRDPT`
  - `Encounter`: `VPRDVSIT`
  - `Condition`: `VPRDGMPL`
  - `Allergy`: `VPRDGMRA`
  - `Medication`: `VPRDPS*`
  - Observations via lab/vitals/domain-specific routines (`VPRDLR*`, `VPRDGMV`, others)
- Practical implication:
  - First version should use VPR extraction conventions and expand domain-by-domain.
  - Existing routines labeled as protected should be treated as read-only sources.

## Sample Bundle Findings
- All sample payloads are FHIR `Bundle` resources with `type="transaction"`.
- Entry structure is consistent:
  - `entry.fullUrl`
  - `entry.resource`
  - `entry.request` (`method=POST`, `url=<ResourceType>`)
- Full URLs and references are primarily `urn:uuid:*`.
- Bundles include multi-domain resources anchored by patient and encounter context.
- Practical implication:
  - First implementation targets transaction-envelope output with deterministic fullUrl and de-duplication.

## Implemented Decisions In First Version
- Web entry point is `GETFHIR^C0FHIR(RTN,FILTER)`.
- Internal mode resolution supports:
  - encounter-centric (`FILTER("encounter")`)
  - date-range (`FILTER("start")` / `FILTER("end")`)
- JSON encoding standard is `ENCODE^XLFJSON`.
- Bundle envelope now uses transaction semantics and entry request metadata.
- First mapped resources:
  - `Patient` via `GETPAT^C0FHIR`
  - `Encounter` via `GETENC^C0FHIR`
- Date-range encounter traversal uses `^AUPNVSIT("AET",DFN,...)` with `MAX` limit support.

## Known Gaps And Next Expansion Targets
- Phase 1 resources not yet mapped into bundle output:
  - `Observation`, `Condition`, `AllergyIntolerance`, `MedicationRequest`
- Reference linking depth is currently encounter spine first, not full supporting graph.
- Future steps:
  - Add per-domain builders in `C0FHIR*` routines.
  - Preserve de-duplication and transaction entry conventions as each domain is added.
  - Validate output shape and profile conformance as resource coverage expands.
