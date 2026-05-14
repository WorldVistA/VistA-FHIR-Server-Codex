# C0FW selective SYN/ISI completion plan

## Purpose

C0FW should become the stable writeback orchestrator for `/addpatient` and
`/updatepatient`, while still allowing selected SYN and ISI routines to do work
where they are already stronger than the native C0FW adapter.

The goal is not to route around C0FW. The goal is to let C0FW decide, record,
and verify which engine handled each domain.

## Current Baseline

- `C0FWADD` and `C0FWUPD` own graph intake, graph indexing, patient linking, and
  domain dispatch.
- `C0FWDOM` dispatches domains without calling SYN/ISI importers.
- Native C0FW already has working slices for Patient, Encounter, vital
  Observations, Encounter.note TIU filing, some Condition/POV filing, and a
  minimum CVX Immunization filing path.
- Several domains intentionally return deterministic `not_implemented` status:
  Lab, Allergy, Medication, Procedure, CarePlan, and Appointment.
- SYN/Data Loader still has mature domain routines such as `SYNFLAB`,
  `SYNFHF`, `SYNFIMM`, `SYNFPROC`, `SYNFTIU`, `SYNFMED`, and patient/encounter
  support through `SYNFPAT` and `SYNFENC`.
- ISI is strongest for older patient-import behavior and data-loader templates,
  but should be treated as an optional implementation engine, not as the HTTP
  route owner.

## Principles

1. C0FW owns the HTTP routes, graph row, bundle slice, return JSON, and load log.
2. Native C0FW remains the default engine for domains it can file safely.
3. SYN and ISI can be used only through explicit C0FW adapter wrappers.
4. Fallback must be visible in the load log and response. No silent legacy calls.
5. A missing SYN/ISI routine must produce `not_implemented` or `skipped`, not a
   M crash.
6. Idempotency is required before a fallback adapter is enabled for reruns.
7. C0FW must preserve the graph indexes that later domains depend on, especially
   DFN, ICN, Encounter id to visit IEN, and bundle slice membership.

## Configuration Model

Add a small C0FW policy layer, for example `C0FWPOL`, backed by globals or site
parameters:

```mumps
^C0FW("policy","Patient")="native"
^C0FW("policy","Encounter")="native"
^C0FW("policy","HealthFactor")="native"
^C0FW("policy","Lab")="syn"
^C0FW("policy","Immunization")="syn"
^C0FW("policy","Medication")="off"
```

Supported values:

- `native`: call the C0FW adapter only.
- `syn`: call the SYN adapter wrapper only.
- `isi`: call the ISI adapter wrapper only.
- `auto`: try native first; use configured legacy fallback only when native
  returns `not_implemented`, not when it returns a clinical filing error.
- `off`: record `skipped`.

Request-level override can be allowed for controlled testing:

```text
POST /updatepatient?dfn=1660&engine.Lab=syn&engine.Immunization=off
```

Site policy should win unless an explicit developer/test flag enables URL
overrides.

## Adapter Shape

Each domain should have a C0FW-owned wrapper even when the implementation calls
SYN/ISI:

```text
C0FWLAB  native lab adapter or not_implemented
C0FWLSYN SYN lab adapter wrapper
C0FWIMM  native immunization adapter or not_implemented
C0FWISYN SYN immunization adapter wrapper
```

Wrapper responsibilities:

- Confirm the required legacy entrypoint exists with `$T(...)`.
- Translate C0FW graph IEN/RIEN/DFN/visit IEN into the shape expected by SYN/ISI.
- Call the legacy routine through one place.
- Normalize success, partial, skipped, not implemented, and error statuses into
  `C0FWSTAT`.
- Write `engine`, `routine`, `entrypoint`, `sourceGraph`, and `targetFile` into
  the load log.
- Rebuild or verify graph indexes after successful filing.

Suggested load-log shape:

```text
load
  Lab
    <rien>
      engine: SYN
      routine: SYNFLAB
      loadStatus: loaded
      file: 63
      targetIen: ...
```

## Dispatch Algorithm

1. `C0FWDOM` identifies the domain from FHIR `resourceType`.
2. `C0FWDOM` asks policy for the domain engine.
3. If `native`, call existing C0FW adapter.
4. If `syn` or `isi`, call the C0FW wrapper for that engine.
5. If `auto`, call native first. Fallback only when:
   - native status is `not_implemented`;
   - the fallback routine is present;
   - the resource has enough graph links to avoid duplicate or orphan filing.
6. Always write one canonical domain section. Do not reintroduce mixed-case or
   legacy-only sections such as both `Encounter` and `encounters`.

Native errors should not automatically fall back. A native error usually means
bad data, broken site setup, or an idempotency issue. Falling back can create
duplicates and hide the real defect.

## Domain Completion Order

1. Patient and graph link safety.
   - Keep C0FW native patient creation as the route default.
   - Allow `SYNFPAT`/`ISIIMP03` only as an explicit `Patient=syn` or
     `Patient=isi` engine for comparison and RPMS targets that need templates.
2. Encounter and visit index safety.
   - Keep C0FW native Encounter filing first because later domains require
     Encounter reference to visit IEN resolution.
   - Add SYN fallback only if native returns `not_implemented`, not for
     DATA2PCE errors.
3. Health Factors.
   - Treat as Encounter-scoped data, not a separate FHIR resource.
   - See the Health Factor section below.
4. Vitals and Conditions.
   - Keep native as default.
   - Add SYN fallback only for unsupported coding maps after idempotency checks.
5. Labs, Immunizations, Procedures, Allergies, Medications.
   - Start as `syn` or `auto` candidates because C0FW native adapters are not
     complete.
   - Require one fixture per domain that proves file location, readback, and
     idempotent rerun.
6. Appointments and CarePlan.
   - Keep disabled unless the target RPMS/VistA scheduling or CP packages are
     installed and explicitly enabled.

## Health Factors Under Encounter

There is no standard FHIR R4 `HealthFactor` resource. In VistA/RPMS, a Health
Factor is a PCC V-file fact linked to a visit. The closest FHIR owner is
therefore the `Encounter`.

C0FW should standardize on Encounter extensions for VistA/RPMS Health Factors:

```json
{
  "resourceType": "Encounter",
  "extension": [
    {
      "url": "http://vistaplex.org/fhir/StructureDefinition/vista-health-factor",
      "extension": [
        { "url": "name", "valueString": "TOBACCO CURRENT EVERY DAY" },
        { "url": "code", "valueString": "..." },
        { "url": "system", "valueUri": "urn:va:health-factor" },
        { "url": "comment", "valueString": "patient reports ..." },
        { "url": "severity", "valueCode": "MO" },
        { "url": "magnitude", "valueDecimal": 2 }
      ]
    }
  ]
}
```

Rationale:

- V Health Factor rows require a visit pointer.
- Encounter is already the visit carrier in C0FW.
- Extensions preserve data without inventing a non-FHIR resource type.
- C0FW can file them in the same DATA2PCE call as the Encounter or as an
  idempotent follow-up update when the visit already exists.

Native C0FW behavior should be:

- `C0FWENC` parses `Encounter.extension` with the canonical Health Factor URL.
- It resolves `name` to `^AUTTHF("B",name)`.
- It files `ENCDATA("HEALTH FACTOR",n,...)` through DATA2PCE.
- It records status under `load("Encounter",rien,"healthFactor",...)`.
- It checks `^AUPNVHF("AD",visit,...)` before rerun to avoid duplicates.

SYN behavior should be optional:

- `SYNFHF` can be wrapped as `C0FWHSYN` for sites where legacy health-factor
  transform maps are already installed.
- C0FW should still keep the canonical FHIR representation as Encounter
  extension and let the wrapper translate to the `SYNFHF` expected input.

Export/readback behavior should mirror the same shape:

- `GET /fhir?...` should emit V Health Factor rows as `Encounter.extension`.
- The FHIR browser should display Health Factors within the Encounter detail
  panel.
- If a Health Factor has a measurement-like value and a site wants analytics,
  C0FW may additionally emit an `Observation` profile later, but that should be
  secondary. The writeback source of truth remains Encounter extension.

## Verification Matrix

For each enabled domain/engine pair:

1. Load a fixture bundle through `/addpatient` or `/updatepatient`.
2. Verify graph status includes `engine`, `routine`, and target file/IEN.
3. Verify VistA/RPMS globals or FileMan APIs show the filed row.
4. Verify `/fhir?dfn=<dfn>` reads the resource back.
5. Rerun the same graph slice and verify no duplicate target rows are created.
6. Run XINDEX on changed C0FW wrappers.

Minimum Health Factor smoke:

- Bundle has one Encounter with one `vista-health-factor` extension.
- First run creates exactly one `^AUPNVHF("AD",visit,...)` row.
- Load log reports `load("Encounter",rien,"healthFactor",n,"status")="filed"`.
- `/fhir?dfn=<dfn>` shows the Health Factor under that Encounter extension.
- Second run reports `skipped` or `already filed` and row count stays unchanged.

## Open Questions

- Which domains should default to `auto` on VEHU/RPMS once SYN is installed?
- Should URL engine overrides be developer-only, or available to demos?
- Which legacy SYN routines are idempotent enough to enable without wrapper-side
  duplicate checks?
- Do RPMS targets have consistent Health Factor names in `^AUTTHF`, or do we
  need a shipped code/name map?
- Should generated Synthea social-history Observations ever be transformed into
  Health Factors, or should only explicit Encounter extensions file as V Health
  Factors?

## First Implementation Slice

1. Add `C0FWPOL` for per-domain engine policy and capability probing.
2. Update `C0FWDOM` to dispatch through policy but preserve current native
   behavior as the default.
3. Finish native Health Factor round trip:
   - import from `Encounter.extension`;
   - read back from `^AUPNVHF` into `Encounter.extension`;
   - show in the browser under Encounter.
4. Add one SYN wrapper for a high-value missing domain, preferably
   Immunization or Lab, with explicit `engine=syn` status.
5. Add rerun/idempotency smoke tests for Patient plus Encounter plus Health
   Factor before enabling additional domains.

## Slice 1 Status

Initial implementation started with the lowest-risk pieces:

- `C0FWPOL` provides per-domain engine selection with native defaults and
  request override hooks for controlled testing.
- `C0FWDOM` dispatches through the policy layer while preserving current native
  behavior unless a domain is explicitly configured otherwise.
- `C0FWHSYN` wraps `SYNFHF` for Health Factor dictionary resolution/creation.
  Native `C0FWENC` still owns the actual visit-linked V Health Factor filing.
- `C0FHIR` readback emits V Health Factor rows as Encounter extensions using
  `http://vistaplex.org/fhir/StructureDefinition/vista-health-factor`.
- C0FW TIU handling accepts both `Encounter.note` and text/plain
  `DocumentReference.content[].attachment.data` on import, and exports
  visit-linked TIU as both Encounter annotations and DocumentReference resources.

The next slice should harden native Immunization or add a Lab SYN wrapper with
full target-file idempotency checks before enabling it by default.

## Slice 2 Status

C0FW now has a minimum native Immunization path:

- CVX is resolved directly through `^AUTTIMM("C",cvx)`.
- The target Encounter reference is resolved through C0FW's Encounter visit
  index.
- Filing uses `DATA2PCE^PXAI` with a native `IMMUNIZATION` payload.
- Reruns check `^AUPNVIMM("AD",visit,...)` for the same immunization IEN before
  filing.

Remaining immunization work is richer mapping, not the basic native filing path:
route, anatomic site, dose units, lot, info source, reaction, contraindication,
and manufacturer should be layered after fixture-based idempotency tests.
