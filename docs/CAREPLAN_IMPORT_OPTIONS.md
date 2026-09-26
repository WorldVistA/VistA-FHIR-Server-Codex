# CarePlan import options

## Question

How should C0FW add Care Plans to patient import when SYN already does it by
creating visit-linked Health Factors that contain SNOMED codes?

## Current C0FW state

C0FW recognizes FHIR `CarePlan` resources, but does not file them today.

- `C0FWDOM` maps `resourceType="CarePlan"` to the `CarePlan` domain and dispatches
  it after Encounters, so visit creation can happen before dependent resources.
- `C0FWCP` is only a placeholder. It records `not_implemented` with the message:
  "CarePlan filing requires a C0FW care-plan or clinical-procedure adapter; no
  SYNFCP importer is called."
- `C0FWSTAT` writes that status under `load("CarePlan",rien,"loadStatus")` and
  into the response domain summary. That is why current stats show CarePlan as
  not implemented.
- `C0FWPOL` defaults all domains to `native`; it only has a SYN capability probe
  for `HealthFactor`. A request or site policy of `engine.CarePlan=syn` would
  currently produce "policy requested SYN but no SYN wrapper is implemented for
  CarePlan."

This is intentional. The recent C0FW direction is that C0FW owns `/addpatient`,
`/updatepatient`, graph rows, bundle slices, return JSON, and domain status.
Legacy SYN/ISI work should enter through explicit C0FW wrappers, not by silently
calling old importers.

## Current Health Factor support in C0FW

C0FW already has the most important primitive needed for a CarePlan first slice:
visit-linked Health Factor filing.

- `C0FWENC` parses `Encounter.extension` entries with URL
  `http://vistaplex.org/fhir/StructureDefinition/vista-health-factor`.
- It resolves `name` through `^AUTTHF("B",name)`, or through a prior
  `C0FWHSYN` resolution when the HealthFactor engine is `syn` or `auto`.
- It queues `ENCDATA("HEALTH FACTOR",n,...)` and files with
  `DATA2PCE^PXAI`.
- Reruns check `^AUPNVHF("AD",visit,...)` for the same Health Factor before
  filing to avoid duplicates on the same visit.
- `C0FHIR` readback emits existing `^AUPNVHF` rows as the same Encounter
  extension shape.

The distinction is that C0FW Health Factor support is Encounter-extension based,
while FHIR `CarePlan` resources are currently a separate domain with no adapter.

## SYN CarePlan behavior

SYN imports CarePlans through `SYNFCP`, `SYNFHF`, and `SYNDHP91`. It does not file
a distinct CarePlan file. It converts the CarePlan, activities, addresses, and
goals into Health Factor dictionary entries and V Health Factor rows on a visit.

### Flow

1. `SYNFHIR` and `SYNFHIRU` call `importCarePlan^SYNFCP`.
2. `importCarePlan^SYNFCP` calls `wsIntakeCareplan^SYNFCP`.
3. `wsIntakeCareplan^SYNFCP` iterates graph entries under
   `@root@(ien,"type","CarePlan")`.
4. For each `CarePlan`, it resolves:
   - patient DFN and ICN;
   - `context.reference` or `encounter.reference`;
   - VistA visit IEN through `visitIen^SYNFENC`;
   - category SNOMED code/display from `CarePlan.category[1].coding[1]`;
   - addressed Condition SNOMED code/display through `DX^SYNFCP`;
   - period start/end;
   - CarePlan status;
   - activity SNOMED code/display/status;
   - goal text/status and addressed Condition.
5. It writes graph-local narrative text through `TONOTE^SYNFTIU`, but
   `SYNDHP91` itself does not create a TIU note.
6. With `args("load")=1`, it calls `CPLUPDT^SYNDHP91`.
7. `CPLUPDT^SYNDHP91` builds `ENCDATA("HEALTH FACTOR",...)` and calls
   `DATA2PCE^PXAI`.

### Health Factor dictionary behavior

`SYNFHF` is the dictionary resolver/creator for these entries.

- `HFCPCAT(CODE,TEXT)` creates or finds the CarePlan category Health Factor
  category.
- `HFCP(CODE,TEXT,CAT)` creates or finds the CarePlan Health Factor.
- `HFADDR(CODE,TEXT,CAT)` creates or finds the "addresses" Health Factor.
- `HFACT(CODE,TEXT,CAT)` creates or finds activity Health Factors.
- `HFGOAL(CODE,CAT,TEXT,DIAG)` creates or finds goal Health Factors.
- All of these call `GETHF`, which constructs uppercase names such as
  `SYN CP <text> (SCT:<code>)` or category names with `[C]`.
- `GETHF` files into `^AUTTHF` file `9999999.64`; when the system has code
  subfile `9999999.66`, it stores the code system and code there.
- Most CarePlan calls pass `LAYGO=1`, so missing Health Factors are created.

### V Health Factor filing

`SYNDHP91` requires an existing patient ICN and visit IEN:

- It rejects unknown ICNs via `^DPT("AFICN",DHPPAT)`.
- It rejects missing or invalid visits via `^AUPNVSIT(DHPVST)`.
- It converts HL7 start/end dates with `HL7TFM^XLFDT`.
- It files to the visit through `DATA2PCE^PXAI`.
- It stores comments like `Start: <fm-date> End: <fm-date> Status: <status>`.

The rows are normal PCC V Health Factors in `^AUPNVHF`, linked to the encounter
visit through the `AD` cross-reference.

### Idempotency

SYN has graph-level replay protection, but not target-row duplicate protection in
the CarePlan path.

- `SYNFCP` skips a resource when graph load status is already `loaded`.
- `SYNFHF` is dictionary-idempotent because it looks up existing `^AUTTHF("B")`
  names before creating new dictionary rows.
- `SYNDHP91` does not appear to check `^AUPNVHF("AD",visit,...)` before calling
  `DATA2PCE`. If the graph status is lost or a resource is reprocessed under a
  different graph row, duplicate V Health Factor rows are possible unless
  `DATA2PCE` or site-specific behavior rejects them.

This matters for a C0FW wrapper: C0FW should add explicit target duplicate checks
before enabling SYN-style CarePlan filing by default.

## Options for C0FW

### Option 1: Native C0FW Health Factor based CarePlan filing

Implement `C0FWCP` to parse FHIR `CarePlan` directly, resolve or create the SYN
style Health Factor dictionary entries, build a local `ENCDATA("HEALTH FACTOR")`
payload, and call `DATA2PCE^PXAI`.

Pros:

- Keeps C0FW as the only importer for the domain.
- Can use C0FW graph indexes and C0FW idempotency rules from the start.
- Can share helper logic with `C0FWENC` for visit resolution, status logging, and
  readback assumptions.
- Avoids inheriting old graph-local assumptions from `SYNFCP`.

Cons:

- Requires reimplementing the CarePlan-to-Health-Factor transform.
- Needs a clear policy for Health Factor dictionary creation. Native C0FW
  currently files existing Health Factors by name; SYN creates missing entries.
- More code than a wrapper, although the filing model is simple.

This is the best long-term C0FW shape.

### Option 2: C0FW wrapper around SYNFCP

Add a `C0FWCPSYN` wrapper that checks `$T(wsIntakeCareplan^SYNFCP)`, passes the
current graph IEN with `args("load")=1`, calls SYN, and normalizes the result into
`C0FWSTAT`.

Pros:

- Fastest way to reuse existing SYN behavior.
- Exercises the known Synthea path with minimal transform code.
- Good for comparison testing against existing SYN fixtures.

Cons:

- `SYNFCP` expects SYN graph indexes and lower-case load sections such as
  `load("careplan",rien,...)`.
- It processes all `CarePlan` entries in the graph, not naturally one C0FW RIEN.
- Idempotency is mostly graph-status based, not target `^AUPNVHF` based.
- Status and logs would need careful normalization to avoid mixed C0FW/SYN shapes.

This is useful as an explicit `engine.CarePlan=syn` test path, but should not be
the default first implementation without wrapper-side duplicate checks.

### Option 3: Hybrid SYN pre-resolution plus C0FW filing

Use SYN's `SYNFHF` dictionary routines to create or resolve the Health Factors,
but let `C0FWCP` own parsing, `ENCDATA`, duplicate checks, `DATA2PCE`, and status.

Pros:

- Reuses the valuable SYN piece: SNOMED-coded Health Factor dictionary creation.
- Preserves C0FW ownership of import status and target idempotency.
- Matches the existing `C0FWHSYN` pattern for Encounter Health Factors.
- Can be implemented incrementally: first CarePlan category and plan row, then
  activities, addresses, and goals.

Cons:

- Still depends on `SYNFHF` when dictionary LAYGO is desired.
- Requires C0FW to reproduce enough of `SYNFCP` parsing to build the right inputs.
- Need to decide whether dictionary creation is allowed by default or only under
  `engine.HealthFactor=syn` / site policy.

This is the recommended first implementation slice.

### Option 4: Model CarePlan only as Encounter extensions

Transform CarePlan content into `Encounter.extension` Health Factors before or
during intake, then let the existing `C0FWENC` path file them.

Pros:

- Uses working import and readback path today.
- Keeps V Health Factors attached to the encounter visit.
- Minimal new filing code.

Cons:

- Loses `CarePlan` as a distinct FHIR domain in the load response.
- Does not naturally represent `CarePlan.activity`, `CarePlan.goal`, or
  `CarePlan.addresses` as their source resource relationships.
- Only works if the transform runs before Encounter filing, or if Encounter can
  be reopened with additional Health Factors later.

This is attractive for narrow fixtures but weak as the main `CarePlan` import
design.

### Option 5: Separate CarePlan domain with readback/export policy

Keep CarePlan as a first-class C0FW domain, but accept that VistA storage is
Health Factor rows. On import, file `^AUPNVHF`; on export, reconstruct either:

- Encounter Health Factor extensions only; or
- FHIR `CarePlan` resources from recognizable SYN Health Factor names/codes.

Pros:

- Honest about storage while retaining FHIR domain status.
- Allows `/addpatient` and `/updatepatient` to say `CarePlan=loaded`.
- Leaves room for richer FHIR readback later.

Cons:

- Reconstructing real `CarePlan` resources from V Health Factors is heuristic.
- Existing `C0FHIR` readback currently emits Health Factors under Encounter,
  not CarePlan resources.
- Round-tripping a CarePlan exactly may require storing source metadata beyond
  normal V Health Factor rows.

This should be the framing for implementation: import as a CarePlan domain,
store as Health Factors, read back first as Encounter extensions, and defer full
CarePlan reconstruction until there is a use case.

## Interaction with selective SYN/ISI policy

The selective policy doc says C0FW should own orchestration and only use SYN/ISI
through explicit wrappers. CarePlan should follow that rule.

Recommended policy behavior:

- Default `CarePlan` remains `native`.
- Native `C0FWCP` should initially support a narrow Health Factor based slice.
- If `SYNFHF` exists and site policy allows dictionary LAYGO, native `C0FWCP` can
  call `SYNFHF` helper APIs for Health Factor resolution/creation.
- A future `engine.CarePlan=syn` can call a dedicated `C0FWCPSYN` wrapper, but
  should be opt-in and must report `engine`, `routine`, and idempotency outcome.
- Missing SYN routines must return `not_implemented`, not crash.
- Native filing errors should not silently fall back to SYN; that can create
  duplicate Health Factors and hide bad visit or patient linkage.

This also aligns with the recent Encounter Health Factor extension work:
`C0FWENC` owns visit-linked Health Factor filing for Encounter extensions, while
CarePlan gets its own domain adapter for FHIR CarePlan resources that happen to
store into the same V Health Factor target.

## Recommended first implementation slice

Implement a small native `C0FWCP` slice with optional SYNFHF dictionary
resolution.

Scope:

1. Process one `CarePlan` RIEN at a time under C0FW dispatch.
2. Require a resolvable `encounter.reference` or `context.reference` to a C0FW
   visit IEN using C0FW's Encounter visit index.
3. Extract:
   - category code/display from `CarePlan.category[1].coding[1]`;
   - status;
   - period start/end;
   - optional `addresses[1].reference` Condition SNOMED via graph `SPO`;
   - activities from `CarePlan.activity[*].detail.code.coding[1]`;
   - goals only if the referenced or adjacent `Goal` can be resolved reliably.
4. Resolve Health Factor dictionary rows:
   - prefer `SYNFHF` APIs when policy allows Health Factor SYN resolution;
   - otherwise require pre-existing `^AUTTHF` names and report skipped/not
     implemented for missing dictionary rows.
5. Before filing each Health Factor, check `^AUPNVHF("AD",visit,...)` for the
   same Health Factor IEN. Treat existing rows as `skipped/already filed`.
6. File new rows with `DATA2PCE^PXAI`.
7. Record C0FW-native status under `load("CarePlan",rien,...)`, including:
   `engine`, `targetFile=9000010.23`, `visitIen`, per-factor statuses, and the
   Health Factor IENs/names.

Start with category and top-level CarePlan Health Factor first. Then add
activities and addresses. Add goals last because `SYNFCP` uses ordering and
graph assumptions that need separate verification.

## Validation plan

1. Use a bundle with Patient, Encounter, Condition, Goal, and CarePlan resources.
2. Run `/addpatient` or `/updatepatient` with load enabled.
3. Verify the response reports `CarePlan` as `loaded` or `partial`, not
   `not_implemented`.
4. Verify the target visit has the expected `^AUPNVHF("AD",visit,...)` rows.
5. Verify `^AUTTHF` entries are reused or created according to policy.
6. Verify `/fhir?dfn=<dfn>` emits the rows as Encounter Health Factor extensions.
7. Rerun the same bundle and confirm no duplicate V Health Factor rows are
   created.
8. Run XINDEX on changed C0FW routines and smoke the route on `vehu10`.

Useful comparison test:

- Run SYN's `wsIntakeCareplan^SYNFCP` on a fixture in a controlled environment and
  compare Health Factor names, comments, and counts against the C0FW slice.

## Open questions

- Should C0FW allow Health Factor dictionary LAYGO by default for CarePlan, or
  only when `engine.HealthFactor=syn` or a site policy flag is enabled?
- What exact Health Factor naming convention should be treated as stable:
  SYN's `SYN CP`, `SYN ACT`, `SYN GOAL`, `SYN ADDR`, and `SYN CPCAT` names, or a
  Codex-specific namespace?
- Should duplicate detection compare only Health Factor IEN on the visit, or also
  comment/date/status so multiple activities with the same Health Factor can
  coexist?
- How should C0FW resolve `Goal` resources? By explicit `CarePlan.goal`
  references, graph `SPO` indexes, adjacent-entry assumptions, or all of the
  above?
- Is readback as Encounter extensions sufficient for the demo, or does the FHIR
  API need to reconstruct `CarePlan` resources from SYN Health Factors?
- Should CarePlan narrative text become a TIU note, or remain only graph-local as
  SYN currently does through `TONOTE^SYNFTIU`?
- Which statuses should map directly into comments versus structured extension
  children on readback?

## Bottom line

SYN's CarePlan import is best understood as SNOMED-coded Health Factor import,
not as a separate VistA CarePlan subsystem. C0FW should add CarePlan as a
first-class import domain, but the first storage target should be the same PCC V
Health Factor rows that C0FW already imports and exports for Encounters. The
lowest-risk path is a hybrid: use C0FW for dispatch, visit resolution,
idempotency, filing, and status, while optionally reusing `SYNFHF` for Health
Factor dictionary resolution and creation.
