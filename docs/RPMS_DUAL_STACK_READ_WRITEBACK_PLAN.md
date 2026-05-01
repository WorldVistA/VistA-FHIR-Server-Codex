# RPMS + VistA Dual-Stack Plan

This note turns the RPMS/VistA compatibility research into an implementation plan
for the Codex FHIR server, SYN loader, `rehmp` bridge, writeback workflow, and
Reminders-on-FHIR work.

Current practical baseline: VPR and SYN have been installed on RPMS and have
already partially loaded patients for a demonstration. That is an important
proof point. It means the next phase should not start from an abstract
"can RPMS ever run this?" question. It should start from a profile-driven
hardening plan for the already-demonstrated read path, then add explicit
writeback and reminders gates.

## Short Answer

Supporting both VistA and RPMS requires a runtime profile and capability layer,
not a fork. The common substrate is strong enough to keep one server stack:
FileMan, Kernel, `^DPT`, PCC visit file `^AUPNVSIT`, TIU `^TIU(8925)`, Lab,
Problem List, V files, and many VPR/SYN concepts overlap. The differences are
large enough that direct calls to VA-specific APIs and deployment assumptions
must move behind adapters.

The target shape is:

- `vista` / `vehu` profile: current behavior, VPR-first, `%web` route
  registration, VA Clinical Reminders through `ORQQPX` / `PXRM`.
- `rpms` profile: PCC-first where needed, RPMS/BMX/BGO/BSD/APCH-aware, VPR/SYN
  reused where present, and routes enabled only when their routines/files exist.
- shared browser/API surface: `/fhir`, `/rehmp`, demo static assets, optional
  `/bsts`, and writeback-save routes remain stable for the UI.

## Current Codex Surface

The current route registration is centered in `src/SYNWEBRG.m`:

- `POST /addpatient` and `POST /updatepatient` call SYN FHIR intake routines.
- `GET /fhir` and `REGTFHIR^C0FHIR` expose the FHIR read surface.
- `GET /vpr/{dfn}` and related query forms expose SYN/VPR JSON.
- `POST /rehmp` calls `WSREHMP^C0RGWEB`.
- `GET /tiustats` and `GET /tiuvpatients` inspect visit-linked TIU coverage.
- `POST /writebacksaves` and related routes store reminder-writeback artifacts.

That shape is already compatible with a dual-stack strategy because routes are
registered conditionally by routine presence. The missing step is making those
conditions explicit capability checks and documenting which route belongs to
which profile.

## RPMS Demonstration Baseline

The RPMS demo where VPR and SYN are installed and patients partially load should
be treated as Phase 0 evidence.

Capture these facts for each RPMS demo environment:

- RPMS build/version and database source.
- Which VPR routines/packages were installed and whether their output shape
  matches VA VPR expectations.
- Which SYN routines were installed, including graph backend availability.
- Whether `%webutils`, `%webreq`, or another listener is serving HTTP.
- Which routes are registered successfully.
- One or more patient identifiers that demonstrate partial load, and which
  domains loaded: Patient, Encounter, Problem, Vitals, Allergy, Medication,
  Immunization, Procedure, Labs, Documents, Reminders.
- Failure modes for domains that did not load: missing routine, missing file,
  no sample data, permissions, unexpected DD/index shape, or output mismatch.

The most useful artifact is a small RPMS demo manifest committed beside smoke
artifacts, for example:

```json
{
  "profile": "rpms",
  "baseUrl": "http://127.0.0.1:908x",
  "patient": { "dfn": "...", "hrn": "...", "display": "..." },
  "installed": {
    "vpr": true,
    "syn": true,
    "web": true,
    "tiu": true,
    "pxrm": true,
    "apch": "unknown"
  },
  "domains": {
    "patient": "pass",
    "encounter": "partial",
    "labs": "unknown",
    "reminders": "not-tested",
    "writeback": "not-enabled"
  }
}
```

## Read Path

### Goal

Keep the browser and API contract stable while allowing each domain to choose
the best local extraction mechanism.

The UI should not need to know whether the backing system is VistA or RPMS for
read-only chart display. It should call `/fhir` or `/rehmp` and receive FHIR
resources or `ResponseEnvelope` payloads with profile metadata when needed.

### Current Read Dependencies

The current FHIR bundle is VPR-heavy:

- Patient maps directly from file `#2` / `^DPT`.
- Encounters use PCC visits via `^AUPNVSIT` and VPR visit extraction.
- Problems use `GMPLUTL2` and `VPRDGMPL`.
- Vitals use `GMRVUT0` and `VPRDGMV`.
- Allergies use `GMRADPT` and `VPRDGMRA`.
- Medications use `PSOORRL` and `VPRDPSOR`.
- Immunizations use `VPRDPXIM`.
- Procedures aggregate VPR surgery/radiology/procedure/CPT paths.
- Labs use `LR7OR1`.
- Reminders currently use `ORQQPX` and `PXRM`.

RPMS can share some of those surfaces but should not be assumed to share all of
them. MCP/source findings indicate RPMS has PCC-centered clinical data, V files,
TIU, Lab, Problem List, and EHR packages, but may need RPMS-specific APIs such as
PCC/Data Entry, `BSD*` scheduling, BI immunization, BGO/BMX RPCs, and APCH/PCC
Health Maintenance reminders.

### Required Read Work

- Add a `C0STACK` or similar capability module that answers:
  - active profile: `vista`, `vehu`, `rpms`, `minimal`;
  - routine exists;
  - global/file exists;
  - API entry point exists;
  - route should be registered;
  - domain is supported, partial, or disabled.
- Wrap each clinical domain behind an adapter label:
  - `GETPAT`: shared `^DPT`, with RPMS identifier extensions.
  - `GETENC`: shared PCC visit path, with RPMS service category validation.
  - `GETLAB`: VistA `LR7OR1` first where valid, RPMS `LRPXAPI` or BLR overlay
    fallback when needed.
  - `GETIMM`: current VPR path where present, RPMS V Immunization/BI path as
    fallback.
  - `GETPROB`: current GMPL/VPR path where present, RPMS problem-list/PCC path
    as fallback.
  - `GETMED`: split VA PSO/VPR from RPMS pharmacy/APSP/eRx surfaces.
  - `GETDOC`: TIU `^TIU(8925)` shared, but validate visit link and ASU rules.
  - `GETREM`: split VA PXRM evaluation from RPMS APCH/PXRM reminder behavior.
- Add profile metadata to responses, probably as `Bundle.meta.tag` or an
  extension, so demos can show "RPMS profile, reminders partial" without
  breaking clients.
- Preserve patient search and bundle operations under `/rehmp`; only the server
  operation implementation should vary by profile.

## reHMP

`src/C0RGWEB.m` is the HTTP bridge for `POST /rehmp`. It delegates to
`$$HTTP^C0RGAPI` and maps `ResponseEnvelope` errors to HTTP status codes. It
also bootstraps the Kernel environment with `ENVINIT^C0FHIR`, which matters for
anonymous/demo HTTP workers.

For dual-stack use, `rehmp` should become the stable browser-facing command
surface:

- `health`: should report profile, build, listener, graph availability, and
  domain capabilities.
- `patient.search`: should support VistA DFN/ICN and RPMS HRN/chart-number
  search where available.
- `bundle.get`: should call the same domain adapters as `/fhir`.
- `bundle.continue`: should be profile-neutral.
- `terminology.*`: can route to BSTS/C0TS or FHIR terminology work.
- `reminder.*`: should be added for Reminders-on-FHIR read and writeback
  workflows.

The browser demos in the sibling `rehmp` repo should not need RPMS-specific UI
forks. They need capability display, identifier labels, and feature gating:

- show HRN/chart number when the backend profile is RPMS;
- hide writeback controls until writeback capability is enabled;
- show reminders as read-only until clinical filing is enabled;
- expose raw request/response artifacts for demonstration and validation.

## Writeback

### Current State

`src/C0RGWBS.m` stores reminder writeback attempts as graph artifacts. These are
review artifacts, not clinical imports. That is the right safety posture for
the current demo stage.

The existing routes are:

- `POST /writebacksaves`
- `GET /writebacksaves`
- `GET /writebacksaves/{id}`
- `POST /writebacksaves/{id}/rename`
- `POST /writebacksaves/{id}/archive`

This gives the UI a safe way to persist draft writeback payloads, HTTP attempt
metadata, patient/reminder indexes, and review state before clinical filing is
allowed.

### Required Writeback Levels

Treat writeback as three separate levels:

1. Artifact save: current graph-only save, safe for demos on VistA and RPMS.
2. Simulated post: validate payload and target capability, return the intended
   clinical write without modifying clinical files.
3. Clinical commit: file into TIU/PCC/reminder packages with audit, locks,
   security, and rollback/error handling.

Only Level 1 should be enabled by default. Level 2 can be enabled in RPMS demos
once payload validation and capability probes are in place. Level 3 needs a
separate sign-off.

### VistA Writeback Targets

Likely VistA targets:

- TIU notes via `MAKE^TIUSRVP`, `UPDATE^TIUSRVP`, signing/locking APIs, and
  visit linkage.
- PCE/V files through supported APIs, not direct global sets.
- Clinical Reminders resolution through PXRM/CPRS dialog mechanisms where
  possible.
- Graph artifact save for audit and replay.

### RPMS Writeback Targets

RPMS evidence from source search shows TIU note update paths use
`UPDATE^TIUSRVP`, and RPMS EHR code calls TIU lock/delete APIs through RPCs.
RPMS TIU post-signature logic can link documents to visits or create/resolve
visits through TIU/PCE paths.

For RPMS, writeback should prefer supported RPMS/EHR/PCC APIs over direct global
updates:

- TIU note create/update/sign/link using TIU service routines available on the
  target RPMS system.
- PCC/V-file writes through PCC Data Entry or documented APIs.
- Problem updates through GMPL/BGO APIs where present.
- Visit creation/linking through RPMS PIMS/BSD/PCC-compatible APIs.
- Reminder resolution through RPMS EHR Clinical Reminders or APCH workflows only
  after validation.

### Writeback Safety Gates

Before enabling clinical commit on either stack:

- prove authenticated Kernel `DUZ` is correct for the acting user;
- enforce patient/context match: DFN, visit, location, encounter date, author;
- lock target records before modification where the package expects it;
- reject stale drafts when source reminder state changed after draft creation;
- store before/after clinical references in the graph artifact;
- distinguish unsigned draft, signed note, addendum, and reminder resolution;
- provide idempotency keys so retry does not create duplicate notes/V-file rows;
- add a per-profile kill switch such as `C0_WRITEBACK_MODE=artifact|simulate|commit`.

## Reminders-on-FHIR

### Current State

`src/C0FHIRR.m` emits a `DiagnosticReport` for "Reminders Due". It uses:

- `GETLIST^ORQQPX` to list reminders for a location;
- `MAIN^PXRM` to evaluate one reminder;
- `^AUPNVSIT("AET",DFN,...)` to choose a recent location if one is not passed;
- an explicit fallback conclusion when `ORQQPX` or `PXRM` is unavailable.

That implementation is useful because it already treats missing reminder runtime
as a normal, explainable outcome.

### RPMS Reminder Reality

RPMS has EHR Clinical Reminders/PXRM material and also PCC Health Maintenance /
Best Practice Prompt concepts through APCH. MCP results indicate RPMS reminder
documentation lists IHS reminders, reminder taxonomies, computed findings,
quick orders, objects, and RPMS taxonomies used by PCC Health Maintenance
Reminders and Best Practice Prompts.

Therefore, "Reminders-on-FHIR" should be defined as a profile-aware service, not
as "always call VA PXRM exactly this way."

### Read Mapping

Use two layers:

- Reminder status resources:
  - `DiagnosticReport` for the current aggregate "Reminders Due" report.
  - Optional `DetectedIssue`, `GuidanceResponse`, or `CarePlan` later if the UI
    needs one resource per actionable item.
- Reminder metadata:
  - extension fields for local reminder IEN/name/status/due date/last done;
  - profile/system URI split between VA PXRM and RPMS/IHS reminders;
  - source package marker: `pxrm`, `apch`, `bgo`, or `unknown`.

The first RPMS pass can keep the current `DiagnosticReport` shape while adding:

- performer text of `RPMS Clinical Reminders` or `RPMS PCC Health Maintenance`;
- identifier systems that are not `urn:va:pxrm` when on RPMS;
- an extension indicating the evaluation backend.

### Writeback Mapping

Do not begin with automatic reminder resolution. Begin with:

1. Draft resolution artifact saved through `/writebacksaves`.
2. Optional TIU note draft/addendum documenting the planned reminder action.
3. Optional PCC/V-file action only after the target reminder's resolution logic
   is understood.
4. Final reminder resolution through the package-supported path.

For RPMS, some reminders may resolve through data entry into PCC/V files rather
than a direct "resolve reminder" API. The writeback design should capture the
clinical intent first, then use package-specific adapters to file the correct
underlying data.

## Deployment and Server Stack

The current scripts assume OSEHRA/VEHU containers, `%webreq`, users such as
`osehra`/`vehu`, routine directories under `/home/*/p`, and ports such as
`9081`/`9085`.

For RPMS, add an explicit deployment profile:

- `FHIR_CONTAINER`
- `FHIR_HTTP_BASE`
- `FHIR_REMOTE_P`
- `FHIR_REMOTE_WWW`
- `FHIR_M_USER`
- `FHIR_MUMPS`
- listener start/stop commands
- route registration entry point
- graph storage root
- static asset root
- writeback mode

Do not assume `%webreq` exists. If RPMS uses a different transport, keep the
core operations callable in-process and put only the listener glue behind a
profile-specific route registration layer.

## Capability Probe

Add a read-only probe routine and expose it through `/rehmp health` and possibly
`GET /fhir?capabilities=1`.

Minimum probe output:

- profile name and site identifiers;
- routines present: VPR, SYN, C0FHIR, C0RG, TIU, PXRM, ORQQPX, APCH, BMX/BGO,
  BSD, LR, GMPL, PSO/APSP;
- files/globals present: `^DPT`, `^AUPNVSIT`, V files, `^TIU(8925)`,
  `^PXD(811.9)`, `^LR`, `^LAB(60)`, graph root;
- route registration support;
- authenticated user context;
- domain support matrix;
- writeback mode and reason when disabled.

This probe is the main tool for avoiding brittle RPMS assumptions.

## Test Plan

Split smoke tests by profile:

- `minimal`: `/fhir` index and Patient-only bundle.
- `vista-full`: current VPR/FHIR domains.
- `vehu-tiu`: TIU visit-linked diagnostics and note/document bundle checks.
- `rpms-read`: RPMS patient partial-load demonstration plus all available read
  domains.
- `rpms-rehmp`: `health`, `patient.search`, `bundle.get`, domain filters, and
  continuation.
- `writeback-artifact`: `/writebacksaves` save/list/get/rename/archive.
- `writeback-simulate`: validate payload without clinical filing.
- `reminders-fhir`: due reminders report, missing-runtime fallback, and RPMS
  backend marker.

Each test should save request/response artifacts the way the existing rehmp demo
does, because those artifacts are the best way to compare VistA and RPMS
behavior without hiding differences in terminal output.

## Phased Implementation

### Phase 0: Document The Existing RPMS Demo

- Record exact RPMS install steps for VPR and SYN.
- Save one partial-load patient manifest.
- Save route list, capability notes, and failed-domain reasons.
- Add the first `rpms-read` smoke script even if many domains are expected
  partial.

### Phase 1: Profiles And Capability Probe

- Add stack profile configuration.
- Add capability probe routine.
- Make route registration capability-aware.
- Add profile metadata to `/rehmp health`.

### Phase 2: Harden Read Path

- Wrap current VPR calls behind domain adapters.
- Keep VPR as first adapter when present.
- Add RPMS fallback adapters for Patient, Encounter/PCC, Immunization, Problem,
  Lab, and TIU documents.
- Update `/fhir` and `/rehmp bundle.get` to share the adapter layer.

### Phase 3: reHMP RPMS Demo

- Make the `rehmp` UI display backend profile and capability matrix.
- Add RPMS identifier labels and partial-domain warnings.
- Run the browser demos against the RPMS backend.

### Phase 4: Reminders-on-FHIR

- Split VA PXRM and RPMS reminder backends.
- Keep current `DiagnosticReport` output shape as the first stable contract.
- Add RPMS/IHS identifier systems and backend marker extensions.
- Add read-only reminder smoke tests.

### Phase 5: Writeback Artifact And Simulation

- Keep graph-only save enabled.
- Add validation/simulation operation under `/rehmp`.
- Add payload schemas for reminder draft, TIU note draft, and PCC action draft.
- Add idempotency keys and stale-state checks.

### Phase 6: Clinical Writeback

- Enable only in a controlled test account.
- Start with one narrow action, probably TIU draft/addendum linked to a visit.
- Add package-specific commit adapters for VistA and RPMS.
- Require explicit environment opt-in and audit artifacts.

## Open Questions

- Which RPMS VPR routines are installed in the demo system, and are they stock,
  ported, or locally modified?
- Does the RPMS demo listener use `%webreq`/`%webutils`, BMX/CIA, or another
  bridge?
- Which patient identifier should the UI lead with on RPMS: DFN, HRN/chart
  number, ICN, or facility-local identifier?
- Which RPMS reminder backend should be first-class: PXRM Clinical Reminders,
  APCH Health Maintenance, BGO/EHR APIs, or a combination?
- What is the first clinically meaningful writeback target for the demo:
  reminder artifact only, TIU note draft, signed note/addendum, or PCC/V-file
  resolution?
- Who is the acting user for RPMS writeback, and how is Kernel `DUZ` established
  from the web session?

## Immediate Next Steps

- Add an RPMS demo manifest for the already-working VPR/SYN partial load.
- Build the capability probe and expose it through `/rehmp health`.
- Add an `rpms-read` smoke that saves artifacts for one demo patient.
- Decide the first Reminders-on-FHIR RPMS backend.
- Keep clinical writeback disabled until simulation validates payloads and
  target package behavior on RPMS.
