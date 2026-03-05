# URL Design Gap Analysis: C0FHIR vs HL7 FHIR

This document compares the current C0FHIR URL design to HL7 FHIR server design expectations (FHIR R4) and outlines practical options.

## Current C0FHIR URL Design (As Implemented)

- Primary HTTP entry point: `GET /fhir`
- Primary query parameters:
  - `dfn` (required patient identifier)
  - `encounter` (optional encounter selector)
  - `start`, `end` (optional date window)
  - `max` (optional result cap)
  - `mode` (`encounter` or `daterange`)
  - `domains` (optional domain selector, comma-separated)
- RPC wrappers mirror the same semantics.
- Response shape: one `Bundle` (currently `type="collection"`) with multi-domain resources.

### Current Domain Tokens

- `encounter`
- `condition`
- `vitals`
- `allergy`
- `medication`
- `immunization`
- `labs`

`Patient` is currently always included for referential context.

## HL7 FHIR URL Design (Baseline Expectations)

FHIR REST APIs are centered on a base URL and resource-oriented interactions:

- Base endpoint: `[base]` (for example `/fhir`)
- Conformance endpoint: `[base]/metadata` (`CapabilityStatement`)
- Resource read:
  - `[base]/Patient/{id}`
  - `[base]/Encounter/{id}`
- Resource search:
  - `[base]/Encounter?subject=Patient/{id}&date=ge...&date=le...`
  - `[base]/Observation?subject=Patient/{id}&category=vital-signs`
- Standard result limits/paging via `_count` and `Bundle.link(next)`
- Include behavior via `_include` / `_revinclude`
- Operation style for cross-resource retrieval:
  - Standard: `[base]/Patient/{id}/$everything`
  - Custom operation (if needed): `[base]/$<operation-name>`

## Key Differences

| Area | Current C0FHIR Design | HL7/FHIR Typical Design | Impact |
|---|---|---|---|
| Endpoint style | Single query-oriented endpoint (`/fhir?dfn=...`) | Resource/interaction endpoints (`/Patient/{id}`, search, operations) | Current design is practical but not canonical REST FHIR style |
| Patient selector | `dfn` query param | Resource id in path or `patient`/`subject` search params | External clients need mapping knowledge |
| Encounter selector | `encounter` param | `Encounter/{id}` or search params | Similar semantic, different URL contract |
| Mode switching | `mode=encounter|daterange` | Usually implied by endpoint + params | Mode param is custom |
| Date filtering | `start`, `end` | Search prefixes (`date=ge`, `date=le`) or operation params | Client portability gap |
| Domain filtering | `domains=vitals,labs,...` (domain terms) | Usually `_type=ResourceType1,...`; sub-filter by resource search params | Domain terms are convenient but non-standard |
| Bundle type for query | `collection` | Search often uses `searchset` | Semantically acceptable for custom operation, less standard for search |
| Paging | `max` cap | `_count` + server paging links | Limited interoperability expectations |
| Discoverability | Implicit in local docs | CapabilityStatement + OperationDefinition | Harder for generic SMART/FHIR tooling |

## Parameter Mapping (Current to FHIR-like)

| Current Param | Closest FHIR Equivalent | Notes |
|---|---|---|
| `dfn` | `Patient/{id}` or `patient`/`subject` search param | `dfn` can remain internal id while exposed as FHIR id |
| `encounter` | `Encounter/{id}` or `encounter` search param | Could be path-based for direct reads |
| `start`, `end` | `date=ge...` / `date=le...` or `$everything` `start/end` | Keep current internally, translate externally |
| `max` | `_count` | Easy compatibility alias |
| `domains` | `_type` (+ category filters) | `vitals`/`labs` both map to `Observation`, usually by category |
| `mode` | Usually not needed | Endpoint shape can eliminate mode |

## Options

## Option 1: Keep Current URL Design (Document as Custom API)

- **What changes**: no endpoint changes; improve documentation only.
- **Pros**:
  - Lowest effort and risk
  - Preserves all existing clients
  - Fastest path for internal use
- **Cons**:
  - Remains non-standard for generic FHIR clients
  - Harder to integrate with off-the-shelf FHIR tooling

## Option 2: Add an HL7-Compatible Facade (Recommended Near-Term)

- **What changes**:
  - Keep current `/fhir?...` contract
  - Add FHIR-looking endpoints that translate to current internals
  - Example facade:
    - `GET /fhir/Patient/{id}/$everything?start=...&end=...&_type=...&_count=...`
- **Pros**:
  - Backward-compatible
  - Better interoperability quickly
  - Minimal disruption to current runtime logic
- **Cons**:
  - Two URL styles to support
  - Requires clear precedence and docs for aliases

## Option 3: Operation-First Standardization

- **What changes**:
  - Formalize custom behavior as a FHIR operation, e.g. `/$c0-bundle`
  - Publish `OperationDefinition` and expose it in CapabilityStatement
- **Pros**:
  - Explicitly standards-aligned for custom semantics
  - Strong discoverability
  - Keeps multi-domain bundle behavior intact
- **Cons**:
  - Still custom operation (not pure resource search model)
  - Requires conformance artifact work

## Option 4: Full RESTful FHIR Search/Read Model

- **What changes**:
  - Move to canonical resource reads/searches for each domain
  - Use `searchset`, `_include`, `_revinclude`, paging, and metadata endpoints
- **Pros**:
  - Highest interoperability and tooling compatibility
  - Most aligned with HL7 server expectations
- **Cons**:
  - Highest implementation and testing effort
  - May require rethinking current bundle orchestration behavior

## Practical Recommendation

Adopt **Option 2** first:

1. Keep current contracts stable.
2. Add HL7-friendly facade URLs (especially `Patient/{id}/$everything`).
3. Support alias translation:
   - `max -> _count`
   - `domains -> _type` (with `Observation` category mapping for `vitals` vs `labs`)
4. Add `/fhir/metadata` CapabilityStatement to document supported interactions.

This gives a low-risk interoperability step while preserving current working behavior.

## Open Design Decisions

- Should `domains` remain domain terms, or migrate to `_type` resource names publicly?
- Should query-result bundles move to `searchset`, or keep `collection` for this API style?
- Should `Patient` always be included, or only when explicitly requested?
- Should `dfn` be exposed directly as FHIR `Patient.id`, or translated to a separate identifier?

