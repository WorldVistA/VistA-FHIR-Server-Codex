# RPMS Routine Install and Test Matrix

This document lists the routines and RPMS package surfaces that need to be
installed, present, registered, and tested for the full Codex stack to operate
on RPMS.

Scope includes:

- Codex FHIR server and HTTP routes.
- SYN FHIR/Data-Loader routines.
- `rehmp` / C0RG JSON RPC bridge.
- BSTS/C0TS terminology HTTP services.
- Reminders-on-FHIR read path and writeback artifact path.
- Optional clinical writeback routines and RPMS-native package APIs.

It intentionally separates two categories:

- **Install/copy routines:** routines from our repositories that we place into
  the RPMS routine directory or package with KIDS.
- **Probe/validate routines:** RPMS-native routines/packages that should already
  exist on the target RPMS instance, but whose presence and behavior must be
  tested before enabling a feature.

## Minimum Operational Definition

"Entire stack operational" on RPMS means:

- `GET /fhir` works for an RPMS patient.
- `POST /rehmp` works for health, patient search, bundle get, and bundle
  continuation.
- VPR/SYN patient partial-load demonstration is reproducible.
- The browser demo can run against the RPMS backend.
- Terminology endpoints work if BSTS is in scope.
- Reminders-on-FHIR returns a read-only reminder report or a clear
  profile-specific unavailable result.
- Writeback artifacts can be saved, listed, renamed, and archived.
- Clinical writeback is disabled by default, but simulation can validate target
  capability.

## Install Set A: Codex FHIR Server

Install these from `VistA-FHIR-Server-Codex/src/`.

| Routine | Required For | Tests |
| --- | --- | --- |
| `SYNWEBRG` | Route registration for `/fhir`, `/rehmp`, `/vpr`, `/addpatient`, `/updatepatient`, `/tiustats`, `/writebacksaves`, and optional BSTS/FHIR routes. | `D EN^SYNWEBRG`, then list `^%web(17.6001)` or equivalent route registry; smoke each registered route. |
| `C0FHIR` | Core patient, encounter, bundle entry points, FHIR index, environment bootstrap. | `GET /fhir`, `GET /fhir?dfn=<dfn>`, patient-only and date-range bundle checks. |
| `C0FHIRBU` | Bundle orchestration, domain selection, IDs, date conversion, JSON support helpers. | Domain-filtered bundles: `domains=patient`, `domains=encounter,labs`, `mode=daterange`. |
| `C0FHIRWS` | HTTP `/fhir` web entry point and browser view. | `/fhir`, `/fhir?dfn=<dfn>`, `/fhir?dfn=<dfn>&view=browser`. |
| `C0FHIRD` | Conditions, vitals, allergies. | `domains=condition`, `domains=vitals`, `domains=allergy`. |
| `C0FHIRM` | Medications and immunizations. | `domains=medication`, `domains=immunization`; verify missing package behavior on RPMS. |
| `C0FHIRL` | Lab observations and lab DiagnosticReports. | `domains=labs`; verify `LR7OR1` and/or RPMS lab fallback. |
| `C0FHIRP` | Procedures, radiology, surgery, clinical procedures, V CPT. | `domains=procedure`; verify graceful skip of unavailable surgery/radiology/MD packages. |
| `C0FHIRR` | Reminders-on-FHIR read path. | `domains=reminder`; validate PXRM path, RPMS/APCH plan, and unavailable-runtime fallback. |
| `C0FHIRGF` | Broker RPC wrapper for full FHIR bundle. | Register RPC with `C0FHIRSE`; call `C0FHIR GET FULL BUNDLE` through Broker if RPMS Broker path is in scope. |
| `C0FHIRSE` | RPC/context option setup for Broker use. | `D EN^C0FHIRSE`; inspect file `#8994` and option file `#19`. |
| `C0RGWEB` | HTTP bridge for `POST /rehmp`. | `POST /rehmp` health, patient search, bundle get, bad request/error mapping. |
| `C0RGWBS` | Writeback-save graph artifact API. | `POST /writebacksaves`, `GET /writebacksaves`, get by id, rename, archive. |
| `C0TSWS` | BSTS/C0TS terminology HTTP service wrappers. | `/bsts/codeset?format=json`, `/bsts/codes?id=<id>&format=json&max=...`. |
| `C0TSWSU` | BSTS/C0TS formatting utilities. | JSON/XML/CSV formatting smoke for one codeset and code list. |

Also install top-level `SYNWEBUT.m` from this repo if the target web stack uses
the helper functions currently carried there.

## Install Set B: reHMP / C0RG

Install these from the sibling `rehmp/C0RG/` directory when `/rehmp` is in scope.

| Routine | Required For | Tests |
| --- | --- | --- |
| `C0RGAPI` | Main RequestEnvelope/ResponseEnvelope dispatcher. | `POST /rehmp` health, validation errors, unknown operation. |
| `C0RGREQ` | Request decode and validation. | Missing body, missing operation, bad version tests. |
| `C0RGRES` | Response envelope and error construction. | Verify success/error envelope shape and HTTP mapping through `C0RGWEB`. |
| `C0RGVER` | API version handling. | Bad `apiVersion` returns expected error. |
| `C0RGHLT` | Health operation. | Health response includes service status; extend to include RPMS profile/capabilities. |
| `C0RGPAT` | Patient search / patient operations. | `patient.search` by name/identifier; RPMS HRN/chart-number behavior when implemented. |
| `C0RGFHB` | FHIR bundle operation bridge. | `bundle.get`, domain filters, continuation when large bundles require slicing. |
| `C0RGBNC` | Bundle continuation support. | Force or detect continuation token and call `bundle.continue`. |
| `C0RGPAR` | Request parameter helpers. | Covered by patient and bundle operations. |
| `C0RGHTTP` | HTTP/support utilities used by C0RG. | Covered by `/rehmp` smoke. |
| `C0RGAUTH` | Auth/session placeholder or enforcement. | Validate current demo mode and future authenticated RPMS `DUZ` mode. |
| `C0RGCTXData` | User/session context support. | `USER.CTX.GET` / `USER.CTX.SET` if enabled by UI. |
| `C0RGUST` | User settings/context support. | Browser shell persistence tests when enabled. |
| `C0RGUGT` | User/get context helper. | Covered with user context operations. |
| `C0RGSE` | C0RG setup/registration. | `D EN^C0RGSE` before route registration; inspect RPC/options if used. |

Test command baseline:

```bash
./scripts/demo-rehmp-regression.sh --base-url <rpms-base-url> <dfn>
```

The test should preserve artifacts for health, patient search, bundle get,
continuation, domain-filtered bundle, validation errors, and `/fhir` parity.

## Install Set C: SYN FHIR/Data-Loader

Install these from `VistA-FHIR-Data-Loader/src/` when SYN load/import, VPR JSON,
graph storage, or Synthea-backed demos are in scope.

### Core Loader And Routing

| Routine | Required For | Tests |
| --- | --- | --- |
| `SYNFHIR` | Main FHIR import/replay web handlers. | `POST /addpatient`, `GET /loadstatus`, replay endpoints if enabled. |
| `SYNFHIRU` | Update existing patient from FHIR bundle. | `POST /updatepatient` with `dfn`, `ien`, or `icn`. |
| `SYNFHIR2` | Legacy/alternate FHIR import support. | Regression only if referenced by installed SYN routes. |
| `SYNINIT` | SYN route/setup support. | Verify route registration does not conflict with `SYNWEBRG`. |
| `SYNAUDIT` | Install health audit. | `D EN^SYNAUDIT`; capture missing files/routines/maps. |
| `SYNKIDS` | Packaging/install helpers. | KIDS build/install validation if packaging for RPMS. |
| `SYNLINIT` | Loader initialization. | Loader install smoke and graph initialization. |
| `SYNFUTL` | Loader utility functions. | Covered by import; check date/identifier transforms. |

### Patient And Clinical Domain Loaders

| Routine | Required For | Tests |
| --- | --- | --- |
| `SYNFPAT` | Patient creation/update and identifiers. | Load one RPMS patient; verify DFN, HRN/chart-number, ICN behavior. |
| `SYNFENC` | Encounters/PCC visits. | Load encounter; verify `^AUPNVSIT` row and indexes. |
| `SYNFVIT` | Vitals. | Load vitals; verify V Measurement/PCC storage and `/fhir` extraction. |
| `SYNFALG`, `SYNFALG2` | Allergies. | Load allergy; verify RPMS allergy package compatibility. |
| `SYNFMED`, `SYNFMED2`, `SYNFMEDT` | Medications. | Load/transform medication; verify RPMS pharmacy limitations before clinical use. |
| `SYNFIMM` | Immunizations. | Load immunization; verify `^AUPNVIMM` and BI package behavior if present. |
| `SYNFPRB`, `SYNFPR2` | Problems. | Load problem; verify Problem List and PCC links. |
| `SYNFPROC` | Procedures. | Load procedure; verify V CPT/procedure storage. |
| `SYNFLAB`, `SYNLABFX` | Labs. | Load lab; verify `^LR`, `^LAB(60)`, and accession behavior. |
| `SYNFPAN` | Lab panels. | Load panel; verify generated DiagnosticReport grouping in `/fhir`. |
| `SYNFHF` | Health factors. | Load health factor; verify V Health Factor storage. |
| `SYNFCP` | Clinical procedures. | Load only if RPMS target has compatible Medicine/CP package. |
| `SYNFAPT` | Appointments. | Validate against RPMS scheduling/BSD before enabling. |
| `SYNFTIU`, `SYNFTIUA` | TIU notes and note addenda. | Load unsigned/signed note test only in controlled RPMS account; verify visit linkage. |
| `SYNFPUL` | Pulmonary or related clinical support. | Optional; test only if referenced by demo bundle. |

### Graph, VPR, HTML, And Utilities

| Routine | Required For | Tests |
| --- | --- | --- |
| `SYNVPR` | `/vpr` route and VPR JSON bridge. | `GET /vpr/<dfn>`, `GET /vpr?icn=...`, `GET /vpr?ien=...`. |
| `SYNGRAPH`, `SYNGRAF`, `SYNFGR`, `SYNWD` | Graph storage, `%wd`/`^SYNGRAPH` compatibility. | `GET /graph/<graph>`, `/writebacksaves`, graph root health. |
| `SYNGBLLD` | Global/map build support. | Rebuild SYN globals and OS5 map. |
| `SYNOS5LD`, `SYNOS5D1`-`SYNOS5D6`, `SYNOS5PT` | SNOMED-to-OS5 map. | `D LOADOS5^SYNOS5LD`; verify `^SYN("2002.030","sct2os5",...)`. |
| `SYNBSTS1` | BSTS integration support for loader terms. | Verify only when BSTS is installed. |
| `SYNCSV`, `SYNHTM`, `SYNQLDM` | Import/report utility support. | Smoke any route or job that references them. |
| `SYNDHP61`, `SYNDHP62`, `SYNDHP63`, `SYNDHP65`, `SYNDHP69`, `SYNDHP91`, `SYNDHPMP` | Generated or fixture data helpers. | Install if referenced by loader tests; run audit for missing routine references. |
| `SYNWEBUT` | Web utility helper. | Verify whichever route stack references this copy versus Codex top-level copy. |
| `SYNYOTTA` | YottaDB-specific helper behavior. | YottaDB/GT.M environment smoke. |

## Install Set D: BSTS/C0TS Terminology

Install from `bsts-vista/trunk/p/` when terminology, picklists, `/bsts`, or
Reminders-on-FHIR coded actions require BSTS.

### C0TS HTTP Layer

| Routine | Required For | Tests |
| --- | --- | --- |
| `C0TSWS` | Web routes for codesets, code lists, code details, concepts. | `/bsts/codeset?format=json`, `/bsts/codes?id=<id>&format=json`. |
| `C0TSWSD` | Data access/cache layer for C0TS web services. | Codeset and codelist lookups; large list max/truncation behavior. |
| `C0TSWSU` | JSON/XML/CSV/HTML formatting utilities. | `format=json`, `format=csv`, `format=xml`. |
| `C0TSFM`, `C0TSUTL` | FileMan/utilities for terminology support. | Setup and lookup smoke. |

### BSTS Core

Install and test at least:

- `BSTSAPI`, `BSTSAPIA`, `BSTSAPIB`, `BSTSAPIC`, `BSTSAPID`, `BSTSAPIF`
- `BSTSUTIL`, `BSTSLKP`, `BSTSSRCH`
- `BSTSCDET`, `BSTSCLAS`, `BSTSCMCL`
- `BSTSDTS0`, `BSTSDTS1`, `BSTSDTS2`, `BSTSDTS3`
- `BSTSLSRC`, `BSTSSTA`, `BSTSVRSN`, `BSTSUPD`
- `BSTSRPC`, `BSTSWSV`, `BSTSWSV1`
- install/post routines such as `BSTS10P1`, `BSTS10P2`, `BSTS1POS` when using
  the KIDS build.

Operational tests:

- list codesets;
- fetch one bounded codelist;
- fetch one code detail;
- verify response size behavior with `max`;
- verify `rehmp` or browser picklists can call the chosen terminology path.

## Install Set E: Reminders-on-FHIR And Writeback Evidence

The current Codex read path is `C0FHIRR`. The current safe writeback persistence
path is `C0RGWBS`. Those are required.

The sibling `reminders-on-fhir` repo currently carries legacy HMP writeback
references under `src/legacy-hmp-writeback/`. These routines are **evidence and
reference material**, not the default clinical-writeback install set:

- `HMPWB`
- `HMPWB1`
- `HMPWB2`
- `HMPWB5`
- `HMPWB5A`
- `HMPWBIM1`
- `HMPWBM1`
- `HMPWBM2`
- `HMPWBPL`
- `HMPWBSO`
- `HMPZUIP`

Do not install these on RPMS as active production code unless a separate design
review decides to revive a specific routine. For the current stack, test them as
reference only while implementing new profile-aware writeback adapters.

## RPMS-Native Package Surfaces To Probe

These routines are not ours to install in a normal RPMS environment. They are
RPMS package prerequisites that must be present, callable, and behavior-tested.

### Core Platform

| Routine/Global/File | Needed For | Probe/Test |
| --- | --- | --- |
| `XLFDT`, `XLFSTR`, `XLFJSON`, `DIC`, `DIE`, `DILFD`, `DIQ`, `DICRW` | Kernel/FileMan/date/JSON operations. | Call date conversion, JSON encode/decode, `GET1^DIQ`, route setup routines. |
| `^DPT` / file `#2` | Patient anchor. | Patient lookup, demographics, identifiers. |
| `^VA(200)` / file `#200` | Provider/user references and writeback `DUZ`. | Resolve acting user and provider displays. |
| `^SC` / file `#44` | Clinics/locations and appointment-derived encounter metadata. | Encounter location and appointment checkout tests. |
| `^%web`, `%webutils`, `%webreq`, `%webrsp` or RPMS alternate listener | HTTP serving and route registration. | Register routes, restart listener, smoke HTTP. |

### PCC / Visit / V Files

| Routine/Global/File | Needed For | Probe/Test |
| --- | --- | --- |
| `^AUPNVSIT` / file `#9000010` | Encounters and visit-linked resources. | Verify `AET` index and visit DFN/date/location shape. |
| `^AUPNVPOV`, `^AUPNVIMM`, `^AUPNVCPT`, `^AUPNVLAB`, V Measurement, V Provider, V Health Factor | RPMS PCC clinical events. | Domain-by-domain read and writeback simulation. |
| `APCD*`, especially `APCDALV`, `APCDALVR` | PCC visit and V-file creation where supported. | Simulated visit/V-file filing in test account. |
| `VSIT*` | Visit API/help layer. | Confirm visit fields and APIs expected by RPMS. |

MCP evidence: RPMS source shows `APCDALV`/`APCDALVR` creating visits and V-file
entries, and PCC routines updating V files linked to `^AUPNVSIT`.

### VPR And Read Extraction

| Routine Family | Needed For | Probe/Test |
| --- | --- | --- |
| `VPRD*` | Current Codex VPR-first extraction for encounters, problems, vitals, allergies, medications, immunizations, procedures, labs/documents. | Capability probe for every `EN1^VPRD...` call used by Codex; compare output shape to VistA. |
| `VPRDVSIT` | Encounter extraction. | `domains=encounter`; visit-linked TIU note test. |
| `VPRDGMPL`, `GMPLUTL2` | Problems. | `domains=condition`; active/inactive problem sample. |
| `VPRDGMV`, `GMRVUT0` | Vitals. | `domains=vitals`; one BP/height/weight sample. |
| `VPRDGMRA`, `GMRADPT` | Allergies. | `domains=allergy`; allergy and no-known-allergy behavior. |
| `VPRDPSOR`, `PSOORRL`, `OR(100)` | Medications. | `domains=medication`; confirm RPMS pharmacy compatibility. |
| `VPRDPXIM` | Immunizations. | `domains=immunization`; compare with `^AUPNVIMM` and BI package. |
| `VPRDSR`, `VPRDRA`, `RAO7PC1`, `SROESTV`, `MDPS1`, `PXPXRM` | Procedures/surgery/radiology/clinical procedures/V CPT. | `domains=procedure`; verify absent packages skip cleanly. |

### Lab

| Routine/Global/File | Needed For | Probe/Test |
| --- | --- | --- |
| `LR7OR1` | Current lab result extraction via `RR^LR7OR1`. | `domains=labs`; chemistry and microbiology sample. |
| `LRPXAPI`, `LRPXAPIU` | RPMS/VistA Lab Extract APIs and LOINC/data-number helpers. | Use as fallback or validation source for RPMS. |
| `^LR`, `^LAB(60)`, file `#95.3` | Lab patient data, test names, LOINC. | Verify LRDFN pointer from `^DPT`, accession, result, units, comments. |
| `BLR*` | IHS/RPMS lab overlays when present. | Probe only if RPMS lab path requires BLR-specific behavior. |

MCP evidence: RPMS source includes `LRPXAPI` as Lab Extract APIs and `LR7OR1`
usage from OE/RR routines.

### TIU / Notes

| Routine/Global/File | Needed For | Probe/Test |
| --- | --- | --- |
| `^TIU(8925)` | Documents and writeback notes. | `GET /tiustats?dfn=<dfn>`, `GET /tiuvpatients`, note body read. |
| `TIUSRVP` | Note create/update services. | Simulation first; later create/update test note in controlled account. |
| `TIUVSIT`, `TIUPXAP1`, `TIUPXAP2`, `TIUPXAP3`, `TIULD`, `TIULC1`, `TIUSRVLI` | Visit linking, workload/PCE actions, post-signature behavior. | Verify note-to-visit link and addendum/signing behavior. |
| `TIU LOCK RECORD`, `TIU UNLOCK RECORD`, `TIU DELETE RECORD` RPCs if using Broker/BMX path | UI/clinical writeback locking behavior. | Lock/unlock simulation and failure handling. |

MCP evidence: RPMS TIU source uses `UPDATE^TIUSRVP`, visit linking through
TIU/PCE routines, and post-signature actions similar to VistA TIU.

### Reminders

| Routine/Global/File | Needed For | Probe/Test |
| --- | --- | --- |
| `ORQQPX` | Current VA-style reminder list call. | `domains=reminder`; missing-runtime fallback if absent. |
| `PXRM`, `^PXD(811.9)` | Current VA-style reminder evaluation. | Evaluate one due and one not-due reminder. |
| `APCH*`, `^APCHSCTL`, `^APCHSURV`, `APCHSMU` | RPMS PCC Health Maintenance reminders and summaries. | Probe `$$GVHMR^APCHSMU` or equivalent RPMS health-maintenance output. |
| `ATX*` | RPMS taxonomies used by APCH/PXRM reminders. | Validate reminder taxonomies exist for demo reminders. |

MCP evidence: RPMS source/docs describe PCC Health Maintenance reminders,
`ALL REMINDERS` health summary setup, `HEALTH MAINTENANCE REMINDERS` components,
and `$$GVHMR^APCHSMU`.

### Scheduling / Appointments

| Routine Family | Needed For | Probe/Test |
| --- | --- | --- |
| `BSD*` / PIMS scheduling | RPMS appointment extraction/writeback. | Appointment domain smoke once implemented. |
| `SD*`, `^SC`, `^DPT(DFN,"S")` | VistA-compatible schedule/clinic data. | Existing encounter end-time and appointment-related probes. |

### RPMS EHR / BMX / BGO

| Routine/RPC Family | Needed For | Probe/Test |
| --- | --- | --- |
| `BMX*`, CIA/EHR listener packages | Alternate RPMS transport if `%web` is not the real serving path. | Connection and table/string RPC smoke. |
| `BGO*`, especially problem/TIU/immunization/chart APIs | RPMS-native read/write adapters. | Use as candidate fallback for problem, note, and immunization actions. |
| `BJPN*`, `BJPC*`, related EHR GUI RPCs | RPMS EHR problem list and clinical UI behavior. | Only if implementing EHR-compatible writeback workflows. |

MCP evidence: RPMS EHR source examples use BMX context, BGO problem RPCs, and
visit stub creation before problem updates.

## Install/Test Order

1. **Platform probe:** Kernel/FileMan/JSON, listener, route registry, user
   context, graph root.
2. **Install Codex routines:** `C0FHIR*`, `C0RGWEB`, `C0RGWBS`, `C0TS*`,
   `SYNWEBRG`, `SYNWEBUT`.
3. **Install C0RG routines:** run setup if using C0RG registration.
4. **Install SYN/Data-Loader routines:** run `SYNAUDIT`, load OS5 map, verify
   graph backend.
5. **Install BSTS/C0TS:** only if terminology/picklists are in scope.
6. **Register routes:** run `D EN^SYNWEBRG`; restart listener if needed.
7. **Read smoke:** `/fhir`, domain filters, `/vpr`, `/rehmp`.
8. **SYN load smoke:** `POST /addpatient` or replay a known partial-load patient.
9. **Reminders smoke:** read-only due reminders or unavailable fallback.
10. **Writeback artifact smoke:** `/writebacksaves` save/list/get/rename/archive.
11. **Writeback simulation:** validate payloads without clinical filing.
12. **Clinical writeback:** only after explicit opt-in and controlled test
    account validation.

## Required Smoke Artifact Set

For each RPMS test pass, save:

- capability probe JSON;
- route registry dump;
- `GET /fhir` index response;
- `GET /fhir?dfn=<dfn>` full bundle;
- one response each for active domains;
- `/rehmp` health, patient search, bundle, continuation or skip result;
- `/vpr/<dfn>` if VPR route is enabled;
- `/bsts/codeset?format=json` if BSTS is enabled;
- `/tiustats?dfn=<dfn>` if TIU is enabled;
- `/writebacksaves` artifact cycle responses;
- XINDEX output for installed routines;
- install logs showing copied routines, `ZLINK`, setup, route registration, and
  listener restart.

## Open Decisions

- Whether RPMS installs should be source-copy/ZLINK for demos or KIDS packages
  for repeatable environments.
- Whether VPR on RPMS is a hard requirement or only the first adapter.
- Whether `%web` is required on RPMS or whether BMX/CIA/RPC Broker should be a
  peer transport.
- Which reminder backend is first-class on RPMS: VA-style PXRM, RPMS PXRM, APCH
  Health Maintenance, or a combined adapter.
- Which writeback target graduates first from artifact-only to simulation and
  then clinical commit.
