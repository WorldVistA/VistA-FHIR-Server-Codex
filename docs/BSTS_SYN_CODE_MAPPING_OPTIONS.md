# BSTS, SYN, and SCT/ICD Code Mapping Options

## Question

Does BSTS support code mapping? How does SYN support code mapping? What are our options for attempting to map from SNOMED CT (SCT) to ICD and vice versa?

Short answer:

- **BSTS supports mapping data and APIs**, especially SNOMED-to-ICD mapping advice and ICD-to-SNOMED lookup, but the **current `/bsts/*` C0TS web surface in this workspace is mostly terminology lookup/list/detail** and does not expose a first-class mapping endpoint.
- **SYN supports mapping with its own `^SYN("2002.030",...)` tables**, accessed through `$$MAP^SYNDHPMP`, plus loader-specific fallback behavior. SYN currently uses these maps heavily for SCT-to-ICD, SCT-to-CPT/OS5, health factors, vitals, and other local filing needs.
- **For SCT to ICD, the best first implementation should prefer VistA Lexicon where available, fall back to SYN maps where needed, and record failures.** ICD to SCT is more constrained: BSTS has an ICD9-to-SNOMED API and SYN maps have inverse indexes for maps they own, but ICD-10-to-SCT is not clearly exposed as a robust local API in this workspace.

## Evidence Reviewed

Relevant local sources:

- `VistA-FHIR-Server-Codex/docs/BSTS_C0TS_FORMAT_WEB_SERVICES.md`
- `VistA-FHIR-Server-Codex/docs/BSTS_INTEGRATION_PLAN.md`
- `VistA-FHIR-Server-Codex/src/C0TSWS.m`
- `VistA-FHIR-Server-Codex/src/C0TSWSU.m`
- `VistA-FHIR-Server-Codex/src/C0FWCON.m`
- `VistA-FHIR-Data-Loader/src/SYNDHPMP.m`
- `VistA-FHIR-Data-Loader/src/SYNFENC.m`
- `VistA-FHIR-Data-Loader/src/SYNFPRB.m`
- `VistA-FHIR-Data-Loader/src/SYNDHP61.m`
- `VistA-FHIR-Data-Loader/src/SYNDHP62.m`
- `VistA-FHIR-Data-Loader/src/SYNGBLLD.m`
- `VistA-FHIR-Data-Loader/src/SYNOS5LD.m`
- `VistA-FHIR-Data-Loader/src/SYNBSTS1.m`
- `bsts-vista/trunk/p/BSTSAPI.m`
- `bsts-vista/trunk/p/BSTSAPIA.m`
- `bsts-vista/trunk/p/BSTSAPIC.m`
- `bsts-vista/trunk/p/BSTSAPID.m`
- `bsts-vista/trunk/p/C0TSUTL.m`

## What BSTS Appears to Expose

### Current C0TS HTTP surface

The C0TS web handlers in `C0TSWS.m` expose these read-only terminology endpoints:

- `GET /bsts/codeset` -> `wsCDSETS^C0TSWS`
- `GET /bsts/codelist` -> `wsCDLIST^C0TSWS`
- `GET /bsts/concept` -> `wsCON^C0TSWS`
- `GET /bsts/subset` -> `wsSUBLST^C0TSWS`
- optional `GET /bsts/code` -> `wsCODE^C0TSWS`

These routes return codesets, code lists, subsets, code detail, and concept detail in formats such as HTML, JSON, XML, CSV, and M arrays. They do not currently define a `/bsts/map`, `/bsts/translate`, `$translate`, or explicit SCT-to-ICD/ICD-to-SCT web operation.

The C0TS codelist/subset HTML comments mention columns such as "MAPS TO", but those are commented out in the web table code. That is a hint that mapping data may exist underneath, not an exposed contract.

### BSTS lower-level APIs

The lower-level `BSTSAPI*` routines do include mapping-related entry points:

- `MPADVICE^BSTSAPI` calls `MPADVICE^BSTSAPIC`, documented as returning **ICD-10 mapping information for a specified SNOMED concept id**. Output includes map advice, category value, group, priority, rule, target name, and target.
- `ICD2SMD^BSTSAPI` calls `ICD2SMD^BSTSAPID`, documented as returning **SNOMED terms that map to a given ICD9 code**.
- `SEARCH^BSTSAPIA` can return sections selected by return flags, including ICD9/ICD10 information, IsA, children, associations, inverse associations, subsets, synonyms, and preferred terms.
- `C0TSUTL` contains direct helpers:
  - `SCT2ICD9^C0TSUTL(CDE)` reads the BSTS term/concept record and returns an ICD9 mapping.
  - `SCT2ICD10^C0TSUTL(CDE)` reads the BSTS record's `ICD_MAPPING` multiple and returns the first ICD10 mapping.

So: **BSTS is not only a terminology lookup store. It has mapping data and API hooks.** The gap is that the Codex/C0TS HTTP layer currently exposes terminology browsing, not a stable mapping/crosswalk service.

### BSTS hierarchy/subsumption

BSTS search/detail output can include IsA and child information. In `BSTSAPIA`, the return flags include `I-IsA` and `C-Children`, and output sections include `ISA` and `CHD`. That is useful for hierarchy exploration and limited subsumption-like checks, but this workspace does not show a clean FHIR-style `$subsumes` operation or a dedicated C0TS web route for subsumption.

## How SYN Supports Code Mapping

### Map storage

SYN stores maps under:

```text
^SYN("2002.030", mapName, "direct", sourceCode, targetCode)=description
^SYN("2002.030", mapName, "inverse", targetCode, sourceCode)=description
```

The generic accessor is `$$MAP^SYNDHPMP(MAP,CODE,DIR,IOE)`.

Important behavior:

- `DIR` defaults to direct; `DIR="I"` uses the inverse index.
- It returns `1^targetCode` or `-1^code not mapped`.
- It returns the first target under the source code using `$O`, so ambiguous one-to-many mappings are not modeled as a rich result.
- `sct2icd` replaces `?` with `A` in the target. That looks like a data normalization workaround and should be treated carefully.

Documented map names in `SYNDHPMP` include:

- `sct2icd`
- `sct2icdnine`
- `sct2cpt`
- `mh2loinc`
- `mh2sct`
- `sct2hf`
- `flag2sct`
- `sct2vit`
- `ctpos2sct`
- `rxn2ndf`
- `sct2os5`

`SYNGBLLD` and `SYNOS5LD` populate these maps. In particular, `SYNOS5LD` builds `sct2os5` direct and inverse indexes from generated `SYNOS5D*` routines.

### Encounter and Condition loading

SYN uses maps differently by domain:

- `SYNFENC` reads FHIR `Encounter.type` as an SCT/CPT-like code and passes it to `ENCTUPD^SYNDHP61` as `SCTCPT`. If the encounter code is empty, it defaults to generic visit SCT `185349003`.
- `SYNFENC` reads encounter reason coding. It uses `DXICDCS^SYNDHP61` to detect whether the incoming reason system is already ICD-9 or ICD-10. If it is ICD-coded, it uses `ICDDX^ICDEX` directly. If it is SNOMED, it maps through `sct2icdnine` or `sct2icd` based on the encounter date.
- `SYNDHP61.ENCTUPD` repeats the encounter diagnosis logic: incoming ICD can be resolved directly with `ICDEX`; incoming SNOMED maps through `sct2icd` or `sct2icdnine`.
- For encounter procedures, `SYNDHP61.ENCTUPD` first tries `sct2cpt`; if that fails or the CPT code is not present in file 81, it tries `sct2os5`; if that fails it uses fallback OS5 code `6456Q`.
- If the encounter diagnosis cannot be mapped to ICD, `SYNDHP61.ENCTUPD` can fall back to filing the SNOMED code under `STD CODES` with coding system `SCT`, and optionally a health factor named `SYN SNOMED PURPOSE OF VISIT`.
- `SYNFPRB` and `SYNDHP62` map FHIR Condition/problem SCT codes to ICD using `sct2icd` or `sct2icdnine` by date. If not mapped, they return an error and record mapping failures through `MAPERR^SYNQLDM`.

### Lexicon use inside SYN/Codex

There are two notable Lexicon paths:

- `SYNDHP61.PROBUPD` uses `CODE^LEXTRAN` to validate/resolve SNOMED CT and uses `GETASSN^LEXTRAN1(DHPSCT,5217693)` to map SNOMED CT to ICD-10-CM. If no ICD is found it falls back to `R69.` before resolving with `ICDDX^ICDEX`.
- `C0FWCON.SCTICD10` uses the same Lexicon association VUID `5217693` for SNOMED-to-ICD-10, but returns `0` if no ICD target resolves. It also tries appending a trailing dot for three-character ICD-10 values before giving up.

This means the workspace already has both **SYN table mapping** and **VistA Lexicon association mapping** in use, depending on path.

## Options for SCT to ICD

### Option 1: VistA Lexicon association `5217693`

Use:

```text
GETASSN^LEXTRAN1(SCT,5217693)
ICDDX^ICDEX(ICD_TEXT,30)
```

This is already used in `SYNDHP61.PROBUPD` and `C0FWCON.SCTICD10`.

Pros:

- Uses VistA's installed Lexicon and ICD files.
- Better aligned with VistA problem list and diagnosis filing.
- Avoids maintaining a separate handcrafted ICD-10 map when the local site already has an authoritative association.

Cons:

- This only clearly covers SCT-to-ICD-10 in the reviewed code.
- Result quality depends on local Lexicon content, patch level, and association availability.
- It may return broad or unspecified ICD codes; filing policy must decide whether that is acceptable.

Best use:

- First choice for **FHIR Condition writeback** and problem-list-like workflows where the input is SNOMED and the target is VistA DX/PL or V POV.

### Option 2: SYN `^SYN("2002.030","sct2icd"...)` and `sct2icdnine`

Use:

```text
$$MAP^SYNDHPMP("sct2icd",SCT)
$$MAP^SYNDHPMP("sct2icdnine",SCT)
```

Pros:

- Already used by the SYN loader.
- Has both direct and inverse global indexes.
- Supports date-based ICD-9 versus ICD-10 selection in existing loaders.
- Provides a local place to patch gaps for synthetic/demo workflows.

Cons:

- Data provenance and completeness need review.
- The accessor returns only the first mapping target.
- Mapping failure behavior differs by caller: some paths error; encounter filing can fall back to STD CODES/health factors.
- The `sct2icd` `?` to `A` transformation suggests data quirks that should be understood before using it as a clinical crosswalk.

Best use:

- Compatibility with existing SYN FHIR intake and demo loads.
- Fallback after Lexicon for Synthea/demo cases where a local SYN map is intentionally curated.

### Option 3: BSTS lower-level mapping APIs

Use lower-level APIs rather than current `/bsts/*` HTTP:

```text
MPADVICE^BSTSAPI
SCT2ICD10^C0TSUTL
SCT2ICD9^C0TSUTL
```

Pros:

- BSTS has mapping-specific records, including ICD-10 mapping advice, target, rule, group, and priority.
- Can expose more than a simple one-code target if we design the wrapper correctly.
- Can be useful for explainability when ICD-10 map rules/advice matter.

Cons:

- Current C0TS web routes do not expose this cleanly.
- `C0TSUTL.SCT2ICD10` returns only the first ICD10 mapping and ignores richer map advice.
- Need runtime confirmation of installed BSTS data completeness and freshness.
- Requires new wrapper/API work if clients need it over HTTP or FHIR.

Best use:

- A second implementation slice after Lexicon/SYN fallback, especially if users need to see ICD-10 map advice or candidate choices.

### Option 4: External SNOMED/ICD maps

Use official or licensed external crosswalks, pre-process them into local tables, then import into SYN or a new graph/global.

Pros:

- Can be reproducible and version-pinned.
- Can carry full map metadata, direction, advice, active status, and release date.
- Can be tested independently of VistA patch state.

Cons:

- Licensing and redistribution constraints are real.
- ICD-10-CM maps are directional and rule-based; a naive lookup can produce misleading results.
- Requires loader, validation, and update governance.

Best use:

- Building a deterministic demo/test mapping corpus or filling known Synthea gaps, provided licensing and provenance are documented.

## Options for ICD to SCT

### Option 1: BSTS `ICD2SMD`

`ICD2SMD^BSTSAPI` / `ICD2SMD^BSTSAPID` is documented as returning SNOMED terms that map to a given ICD9 code.

Pros:

- Explicit API exists in BSTS.
- Returns SNOMED term detail, not just a bare code.

Cons:

- The reviewed API is explicitly ICD9-oriented.
- It does not establish a robust ICD-10-to-SCT path.
- ICD-to-SCT is usually many-to-many and less reliable than SCT-to-ICD for clinical intent.

### Option 2: SYN inverse indexes

For maps that SYN owns, `$$MAP^SYNDHPMP(MAP,CODE,"I")` can use the inverse index. For example, `sct2os5` inverse is used by C0FHIR export code to recover source SNOMED from OS5/CPT encounter codes.

Pros:

- Already available in `^SYN("2002.030",map,"inverse",...)`.
- Useful for recovering original SCT when the target code was generated by the same SYN map.

Cons:

- Only valid for maps populated with inverse data.
- Returns first mapped SCT, not a complete candidate set.
- Inverse of an SCT-to-ICD map is not semantically equivalent to a clinical ICD-to-SCT translation.

Best use:

- Export/recovery workflows where the code was previously mapped by SYN and preserving source SCT is more important than inferring new semantics.

### Option 3: VistA Lexicon search

Use ICD code to locate diagnosis/narrative in Lexicon/ICDEX and search for associated SNOMED expressions if available.

Pros:

- Keeps work inside VistA terminology content.
- Could be better aligned with local site dictionaries.

Cons:

- No reviewed code shows a clean existing ICD-10-to-SCT API comparable to `GETASSN^LEXTRAN1(SCT,5217693)`.
- Needs proof-of-concept validation in the target VistA/RPMS instance.

### Option 4: External reverse maps or curated tables

Use external ICD-to-SCT maps or curated local tables.

Pros:

- Can be designed for the exact use case.
- Can include ranking and manual review status.

Cons:

- Directionality is the largest risk. ICD codes are often broader billing/grouping categories, while SNOMED may encode more clinical detail.
- Unreviewed automatic ICD-to-SCT can produce false precision.

Best use:

- Assisted suggestions only, with provenance and confidence, not automatic problem-list mutation without review.

## Tradeoffs and Risks

- **Directionality matters.** SCT-to-ICD and ICD-to-SCT are not symmetric. SYN inverse indexes are useful but should not be advertised as authoritative reverse clinical maps.
- **Encounter diagnosis and problem list are different.** Encounter POV filing may tolerate a less-specific ICD or a SNOMED STD CODES fallback. Problem list filing usually needs a cleaner Lexicon/SNOMED/ICD story and should avoid silently filing poor mappings.
- **Local site dictionaries matter.** `ICDDX^ICDEX`, file 81, Lexicon, `^AUTTHF`, clinic/provider dictionaries, and installed BSTS content vary by environment. A mapping that resolves in one container may fail elsewhere.
- **ICD-10 specificity matters.** A map may produce a billable code, a category, or a placeholder-like code. The current `C0FWCON` code has a small normalization for three-character ICD-10 values, but a general implementation should validate active status and filing acceptability.
- **One-to-many mappings are common.** `$$MAP^SYNDHPMP` collapses to the first target. BSTS `MPADVICE` can expose group/priority/rule/advice and is better suited for cases where multiple candidates exist.
- **Fallbacks affect data quality.** SYN encounter loading can fall back to OS5 `6456Q` for procedure filing and to SNOMED STD CODES/health factors for unmapped diagnosis. That is practical for demos but should be explicit in reports.
- **Licensing/provenance must be tracked.** SNOMED CT and map content may have use restrictions. Any imported external map should carry release/version/license metadata.

## Recommended First Implementation Slice

Build a small C0FW/SYN mapping wrapper and use it in one narrow writeback/load path before generalizing.

Recommended SCT-to-ICD order:

1. If the input coding is already ICD-9/ICD-10, resolve with `ICDDX^ICDEX` for the correct coding system and date.
2. If the input is SNOMED CT and the desired target is ICD-10, try VistA Lexicon association `GETASSN^LEXTRAN1(SCT,5217693)` and validate with `ICDDX^ICDEX`.
3. If Lexicon fails and this is a SYN/demo intake path, try `$$MAP^SYNDHPMP("sct2icd",SCT)` or `sct2icdnine` by date.
4. If still unmapped:
   - For encounter POV, preserve the SNOMED as `STD CODES`/health factor where that behavior is already accepted.
   - For problem list writeback, fail clearly and record a mapping error instead of inventing a diagnosis.

Recommended initial API shape:

```text
RESOLVE^C0FWMAP(.OUT,SOURCE_SYSTEM,SOURCE_CODE,TARGET_SYSTEM,FMDATE,CONTEXT)
```

Return:

- status: mapped, already-target, unmapped, ambiguous, invalid
- source system/code/display
- target system/code/IEN/display
- method: icdex-direct, lextran-5217693, syn-sct2icd, syn-sct2icdnine, bsts-mpadvice
- context: encounter, problem-list, procedure, export
- messages and provenance

Keep the first slice read-only except for logging mapping failures. Do not replace all loader calls at once.

## Open Questions

- Which deployed environment is the source of truth for BSTS data: `bsts-vista`, the container image, or another production KIDS install?
- Are `MPADVICE^BSTSAPI` and `C0TSUTL.SCT2ICD10` loaded and populated in the current `vehu10`/test containers?
- Should `/bsts/*` grow mapping endpoints, or should mapping live under a C0FW/FHIR operation wrapper instead?
- For problem-list creation, should unmapped SNOMED fail, file SNOMED-only metadata, or fall back to broad codes such as `R69.`? Existing code differs by path.
- Do we need ICD-10-to-SCT as an automatic map, or only as a suggestion/search feature?
- What map version/release metadata do we need to show users or store with filed data?
- Which Synthea SCT codes are failing today, and are those best solved by Lexicon updates, SYN map patches, BSTS map use, or source bundle changes?

## Bottom Line

BSTS can support code mapping at the lower API/data level, but our current HTTP BSTS integration mostly exposes terminology browsing. SYN already has practical direct/inverse mapping tables in `^SYN("2002.030",...)` and uses them during FHIR loading, especially for SCT-to-ICD and SCT-to-OS5/CPT. For new work, use a policy wrapper: prefer direct ICD and Lexicon SCT-to-ICD-10 resolution, fall back to SYN where appropriate, preserve or fail unmapped SNOMED based on context, and treat ICD-to-SCT as a candidate-generation problem rather than a trustworthy inverse translation.
