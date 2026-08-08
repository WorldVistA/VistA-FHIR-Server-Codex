# Diagnosis selection options for encounter-note writeback

## Problem statement

We need a clinician-facing way to select a diagnosis while authoring or updating an encounter note. When a diagnosis is selected, the update must remain encounter-cohesive:

- the write payload should bundle the `Encounter`, the note text, and the diagnosis together;
- the note author must be able to add narrative support for the diagnosis in the note;
- the user must choose whether the selected diagnosis is visit-only or should also be added to the longitudinal problem list;
- the server must resolve the selected diagnosis into the VistA/PCE diagnosis machinery without relying on display text alone.

In CPRS/PCE terms this is the "purpose of visit" / encounter diagnosis path, with an optional problem-list add. In FHIR terms the safest first shape is an encounter-linked `Condition` in the same update bundle as the `Encounter` and note, plus a VistA extension controlling problem-list filing.

## Current state

### Codex update path

`POST /updatepatient` is implemented in `src/C0FWUPD.m`. It merges a new FHIR bundle slice into the existing `fhir-intake` graph row, indexes the appended entries, and dispatches domain loaders when `load=1`.

`src/C0FWDOM.m` files appended `Encounter` resources first, then files other domains. After each `Encounter`, it calls `LOADENC^C0FWTIU`, so `Encounter.note[]` can become visit-linked TIU text once a visit pointer exists.

`src/C0FWENC.m` creates or reuses a PCE/PCC visit through `DATA2PCE^PXAI`. It can also file an Encounter-native POV from `Encounter.reasonCode` or the `vista-pov` extension, but that path only accepts ICD-coded values.

`src/C0FWTIU.m` files note text in two supported shapes:

- `Encounter.note[].text`, filed immediately after the Encounter load;
- `DocumentReference` with `text/plain` base64 attachment and `context.encounter`, filed later as its own domain.

`src/C0FWCON.m` is the key Condition writeback adapter. It requires:

- a `Condition` resource;
- an `encounter.reference` or equivalent reference resolvable to an already-filed visit;
- `Condition.code.coding[]` containing either ICD-9/ICD-10 or SNOMED CT that can map to ICD-10 through Lexicon;
- optional `Condition.extension` at `http://vistaplex.org/fhir/StructureDefinition/vista-add-to-problem-list`.

When loaded, it calls `DATA2PCE^PXAI` with `DX/PL`, filing the visit POV and setting `PL ADD` based on that extension. If the extension is absent, Codex defaults to visit-only (`PL ADD=0`).

### Read path and existing FHIR conventions

`src/C0FHIRD.m` exports existing problem-list entries as `Condition` resources with `category=problem-list-item`. It prefers SNOMED coding when available and falls back to ICD coding.

`docs/FHIR_ENCOUNTER_NOTE_EXPORT_IMPORT.md` documents that Codex exports TIU text as `Encounter.note[]` and imports `Encounter.note[]` as the primary visit-linked TIU path. `DocumentReference` is also accepted, but the active browser demo currently uses `Encounter.note`.

### reHMP / CPRS-on-FHIR UI state

The active UI path is `rehmp/ehmp-ui/rehmp-cprs-demo/`. It loads patients through `/rehmp` operations, builds update bundles in `writeback/writebackBundle.js`, renders reminder/dialog inputs in `writeback/reminderDialog.js`, and can post raw bundles to `/updatepatient`.

The current bundle builder already creates `Patient` + `Encounter` with `Encounter.note[]` and VistA health-factor extensions. It has a placeholder `conditionResource()` for reminder candidates, but it is not a diagnosis picker and does not produce codings that Codex can file.

`CPRS-on-FHIR` already records the program stance in `docs/PCE_ENCOUNTER_NOTES_HF_POV.md` and `docs/FIRST_CLINICAL_WRITE_TARGET.md`: realistic encounter updates should keep `Encounter`, POV `Condition`, health factors, and notes together in one FHIR write bundle. `docs/CPRS_FUNCTIONS_CATALOG.md` tracks this as `CFH-PCE-POV-001`, distinct from longitudinal problem-list work (`CFH-PROB-*`).

## Options

### Option A: Client-side static diagnosis list, server resolves ICD

The UI ships or fetches a small curated diagnosis picklist with ICD-10-CM codes, display text, and optional SNOMED CT codes. The user selects one, edits the diagnosis-support note text, checks "add to problem list" or leaves it unchecked, and submits:

- `Encounter` with `note[].text` containing the clinical support;
- `Condition` referencing the Encounter `fullUrl`;
- `Condition.code.coding[]` with ICD-10-CM first, SNOMED optional;
- `Condition.extension[vista-add-to-problem-list].valueBoolean`.

Pros:

- fastest path with the current Codex loaders;
- does not require a new terminology endpoint before the first demo;
- deterministic for a narrow sandbox slice.

Cons:

- not a real clinical search experience;
- the list can drift from local VistA Lexicon/ICD availability;
- poor support for synonyms, local terms, and inactive/unusable codes.

This is suitable only as a first implementation slice or smoke-test fixture.

### Option B: Backend diagnosis search backed by VistA Lexicon

Add a Codex or `/rehmp` terminology operation that searches local VistA Lexicon and returns selectable diagnosis concepts with enough structured data for writeback: display text, lexical expression/IEN if useful, ICD-10-CM code, coding-system metadata, optional SNOMED CT, and active/applicable status for the encounter date.

The UI uses that search in a diagnosis picker. The selected item is submitted as an encounter-linked `Condition` exactly as in Option A, but its code package comes from the local VistA server.

Pros:

- best fit for real VistA/RPMS behavior because users pick from the same local terminology and mappings the server will use;
- lets the server validate date-sensitive ICD and local policy before submission;
- gives a stable route for RPMS/BSTS variants later.

Cons:

- needs a new backend operation and smoke tests;
- requires careful output contract so the UI does not depend on internal Lexicon globals;
- search performance and pagination must be designed.

This is the recommended product direction after a narrow static-list slice proves bundle filing.

### Option C: Use existing BSTS/C0TS terminology endpoints first

Use the existing BSTS/C0TS web service surface as the initial diagnosis search source, especially where RPMS/BSTS is the intended terminology authority. The UI calls terminology endpoints, chooses a concept, and sends the resulting ICD/SNOMED codings to Codex.

Pros:

- aligns with RPMS/BSTS terminology infrastructure;
- existing `/bsts/*` JSON support can be reused or extended;
- useful for mapping exploration and terminology-browser UX.

Cons:

- Codex writeback still ultimately needs an ICD diagnosis IEN through ICDEX/PCE;
- BSTS concept identity may not be sufficient unless the response includes the exact ICD/SNOMED mapping Codex accepts;
- may introduce a second terminology authority on VA-style VistA systems where Lexicon/ICDEX is the writeback authority.

This is a good RPMS-facing path, but for VistA writeback it should feed or align with the same server-side resolution contract as Option B.

### Option D: Diagnosis support as note-only, no Condition

The UI could add diagnosis support text to the note but skip structured `Condition` filing.

Pros:

- very low implementation effort;
- avoids terminology and PCE filing risk.

Cons:

- fails the requirement to select and bundle a diagnosis;
- does not file V POV or problem-list data;
- cannot support workload/billing/problem-list semantics.

This should not be treated as satisfying the requested feature. It is only a fallback for disabled writeback mode.

### Option E: Encounter `reasonCode` / `vista-pov` extension only

Codex can file a POV directly from `Encounter.reasonCode` or a `vista-pov` Encounter extension. A UI could put the diagnosis there and skip a separate `Condition`.

Pros:

- fewer resources in the bundle;
- already supported by `C0FWENC` for ICD-coded POV.

Cons:

- no existing add-to-problem-list switch in that path;
- `C0FWENC` does not currently map SNOMED through Lexicon like `C0FWCON`;
- less explicit FHIR shape for encounter diagnosis vs longitudinal problem list.

This can remain a compatibility path, but the new diagnosis-selection feature should prefer a separate encounter-linked `Condition`.

## Recommended first implementation slice

Start with a narrow but end-to-end slice:

1. Add a diagnosis picker to the active CPRS demo using a small local fixture of ICD-10-CM-coded diagnoses, optionally with SNOMED CT codes.
2. Add a "supporting note text" field or generated section that appends a clearly labeled diagnosis-support paragraph to the existing `Encounter.note[].text`.
3. Add an "add to problem list" checkbox. Default it to unchecked, because Codex defaults missing extension to visit-only and problem-list additions are higher risk.
4. Extend `rehmp/ehmp-ui/rehmp-cprs-demo/writeback/writebackBundle.js` to emit an encounter-linked `Condition` entry:
   - `subject.reference` = selected patient reference;
   - `encounter.reference` = the new Encounter `fullUrl`;
   - `code.text` and `code.coding[]` = selected diagnosis;
   - `onsetDateTime` or `recordedDate` = encounter date;
   - `extension.url` = `http://vistaplex.org/fhir/StructureDefinition/vista-add-to-problem-list`;
   - `extension.valueBoolean` = checkbox value.
5. Post to `POST /updatepatient?dfn=<dfn>&load=1` for VEHU/test patients and verify that Codex files the Encounter, TIU note, and Condition.
6. Confirm readback through `/fhir` shows the note and, when the checkbox is true, the problem-list `Condition`.

This keeps the first change small while exercising the exact server behavior that matters: same-bundle encounter linkage, note filing, diagnosis filing, and optional problem-list filing.

After that works, replace the fixture picker with a Lexicon-backed backend search.

## Role of VistA Lexicon

VistA Lexicon should become the authoritative server-side diagnosis selection and resolution service for VistA clinical writeback, not just a fallback mapper.

Recommended roles:

- Local authoritative search: user-facing diagnosis search should ask the target VistA/RPMS environment for locally valid terms, not rely only on a web-standard code list baked into the browser.
- Mapping source: when the UI selects SNOMED CT, Codex should use Lexicon mappings to derive the ICD-10-CM diagnosis accepted by PCE. `C0FWCON` already does this via `GETASSN^LEXTRAN1` and map VUID `5217693`.
- Validation gate: the backend should validate code activity, coding system, and encounter-date applicability through Lexicon/ICDEX before clinical filing.
- FHIR coding bridge: FHIR `Condition.code.coding[]` can carry both SNOMED CT and ICD-10-CM. SNOMED is useful as the clinical concept identity; ICD-10-CM is required for current `DATA2PCE` diagnosis filing. When both are known, include both.
- RPMS/BSTS bridge: on RPMS, BSTS may be the practical terminology search surface, but its selected concept still needs to resolve into the same FHIR coding contract and downstream ICD/PCE filing input.

Lexicon should not be an optional afterthought for real clinical use. The static picker can be a demo bootstrap, but production-quality diagnosis selection should be server-backed and local-site-aware.

## Tradeoffs

| Decision | Benefit | Risk / cost |
| --- | --- | --- |
| Separate `Condition` for diagnosis | Clear FHIR model; supports add-to-problem-list extension; matches CPRS-on-FHIR stance | Slightly larger bundle; requires reference validation |
| `Encounter.note[]` for note text | Current Codex import path is proven | Less expressive than `DocumentReference`/`Composition` for full TIU lifecycle |
| Default problem-list checkbox off | Safer; preserves visit-only POV workflow | User may forget to add chronic diagnoses unless UI makes the choice visible |
| ICD-first fixture for slice 1 | Fastest way to prove writeback | Not enough for real terminology UX |
| Lexicon-backed search for slice 2 | Local, authoritative, date-sensitive | Requires backend API and pagination/search design |
| Include both SCT and ICD in FHIR | Preserves clinical concept and filing code | Need clear precedence when mappings disagree |

## Backend requirements

For the first slice, Codex mostly needs documentation and tests, not a new loader:

- `C0FWDOM` must continue filing Encounter before Condition.
- `C0FWCON` must continue resolving ICD codings and SNOMED-to-ICD through Lexicon.
- `C0FWCON` should remain the owner of `vista-add-to-problem-list` behavior.
- Smoke tests should prove both `valueBoolean=false` and `valueBoolean=true`.

For the Lexicon-backed slice, add one backend operation, either:

- a Codex FHIR-ish terminology route, for example `GET /fhir/diagnosis-search?text=&date=`;
- a `/rehmp` operation, for example `terminology.diagnosis.search`;
- or a BSTS/C0TS-backed route if RPMS/BSTS is chosen as the first target.

The operation should return a small structured result, not raw Lexicon internals:

```json
{
  "display": "Type 2 diabetes mellitus without complications",
  "icd10": { "system": "http://hl7.org/fhir/sid/icd-10-cm", "code": "E11.9" },
  "snomed": { "system": "http://snomed.info/sct", "code": "44054006" },
  "source": "vista-lexicon",
  "active": true
}
```

## Concrete files and entry points likely touched

### VistA-FHIR-Server-Codex

- `src/C0FWUPD.m`: `POST /updatepatient` merge/load entry point.
- `src/C0FWDOM.m`: domain ordering and dispatch.
- `src/C0FWENC.m`: Encounter/visit filing and existing Encounter POV compatibility path.
- `src/C0FWTIU.m`: `Encounter.note[]` and `DocumentReference` TIU filing.
- `src/C0FWCON.m`: Condition writeback, ICD/SNOMED resolution, `vista-add-to-problem-list`.
- `src/C0FHIRD.m`: current Condition read mapping from problem list.
- `src/SYNWEBRG.m`: route registration for `/updatepatient`, `/rehmp`, `/writebacksaves`, and any future terminology search route.
- `docs/FHIR_ENCOUNTER_NOTE_EXPORT_IMPORT.md`: current note import/export reference.
- `docs/FHIR_INTAKE_CURL_RECIPES.md`: useful place for future diagnosis-writeback curl smoke recipes.

### rehmp

- `ehmp-ui/rehmp-cprs-demo/app.js`: CPRS demo state, dialogs, submit path, and result handling.
- `ehmp-ui/rehmp-cprs-demo/writeback/writebackBundle.js`: add diagnosis `Condition` resource builder, validation, and summary output.
- `ehmp-ui/rehmp-cprs-demo/writeback/reminderDialog.js`: if diagnosis support text is generated from reminder/dialog answers.
- `ehmp-ui/rehmp-cprs-demo/writeback/reminderDefinitions.js`: if diagnosis choices start as fixture-backed reminder candidates.
- `docs/FHIR_WRITEBACK_RULES.md` and `docs/FHIR_WRITEBACK_ENCOUNTER_SEQUENCE.md`: update after the diagnosis slice supersedes the older "Encounter plus Immunization first" writeback story.

### CPRS-on-FHIR

- `docs/PCE_ENCOUNTER_NOTES_HF_POV.md`: program stance for Encounter + POV Condition + note.
- `docs/FIRST_CLINICAL_WRITE_TARGET.md`: first clinical-write target context.
- `docs/CPRS_FUNCTIONS_CATALOG.md`: `CFH-PCE-POV-001`, `CFH-PROB-*`, and `CFH-NOT-*`.
- `docs/specs/CFH-PCE-POV-001.md`: likely home for the durable diagnosis/POV child spec.
- `harness/CFH-PCE-POV-001/`: likely home for request/response fixtures proving the bundle.

## Open questions

- Should the UI represent the note body only as `Encounter.note[]` for the first clinical slice, or should the durable contract move to `DocumentReference`/`Composition` once TIU lifecycle work starts?
- What exact Condition category/profile should distinguish encounter diagnosis/POV from problem-list Condition in write bundles?
- Should a checked "add to problem list" create only one `Condition` with the VistA extension, or should future FHIR profiles use separate encounter-diagnosis and problem-list Condition entries?
- Which route owns terminology search long term: `/rehmp terminology.*`, `/fhir` terminology operation, or `/bsts`/C0TS?
- Which Lexicon APIs and filters should be used for date-sensitive diagnosis search in the target VEHU and RPMS environments?
- Should Codex expose the resolved ICD diagnosis IEN, V POV IEN, and problem IEN in the `/updatepatient` response for UI confirmation?
- What should happen when SNOMED maps to multiple ICD-10-CM codes or the mapping is ambiguous for the encounter date?
- How should authentication/DUZ and provider/location selection be surfaced before this moves beyond controlled demo patients?

## Bottom line

Use an encounter-linked `Condition` in the same `/updatepatient` bundle as the `Encounter` and note. For the first slice, use a constrained ICD-coded picker to prove the existing Codex writeback path. Then make VistA Lexicon (or BSTS feeding the same contract on RPMS) the authoritative diagnosis search and mapping service so the UI selects locally valid clinical concepts and Codex files the correct PCE/Problem List records.
