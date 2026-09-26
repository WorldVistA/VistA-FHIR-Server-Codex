# C0RG terminology gateway options

## Purpose

C0RG needs a terminology gateway that can support browser/UI workflows such as
diagnosis pickers, Health Factor/CarePlan pickers, and code mapping without
hard-coding one terminology authority. The same gateway should be able to route
requests to:

1. an online BSTS/C0TS terminology server;
2. a local BSTS/FileMan cache;
3. a C0T/VistA provider that uses Lexicon, ICD, CPT, and other local VistA
   resources.

The goal is not to replace BSTS or Lexicon. The goal is to give reHMP and
CPRS-on-FHIR one stable C0RG contract while deployment policy decides which
provider answers a request.

## Current evidence

### RPMS/BSTS pattern

The RPMS BSTS package is built as a general M/FileMan interface and cache for an
external terminology server, historically DTS. RPMS documentation describes BSTS
as a package in the `9002318-9002318.99` file range that lets M applications use
SNOMED CT, RxNorm, UNII, ICD, and IHS-defined mapping codesets from an external
terminology service while caching data locally.

The RPMS source follows that model:

- `CDSET^BSTSRPC` implements the `BSTS GET CODESETS` RPC by calling
  `$$CODESETS^BSTSAPI("VAR",...)`.
- `CODESETS^BSTSAPI` delegates to `CODESETS^BSTSAPIA`.
- `SUBSET^BSTSAPI` delegates to `SUBSET^BSTSAPIA`.
- `SUBSET^BSTSAPIA` accepts a namespace id, a local/remote selector, and debug
  flag. It can call remote `BSTSWSV`/DTS code, but falls back to local
  `^BSTS(9002318.4,...)` subset indexes.
- `BSTSWSV1` routines show remote DTS calls through configured active servers,
  with logic such as `WSERVER^BSTSWSV`, `CKDTS`, and `BSTSDTS*` routines.

That means RPMS already treats BSTS as both:

- an **online terminology client**; and
- a **local FileMan-backed terminology cache**.

The public C0TS endpoint
[`/bsts/codeset?format=json`](http://fhir.vistaplex.org:9080/bsts/codeset?format=json)
exposes this information as web JSON. It returns rows such as SNOMED CT US
Edition (`36`), ICD-10-CM (`5140`), RxNorm (`1552`), and SNOMED-to-ICD mapping
codesets including `32777`, `35290`, and `35291`, plus many SNOMED subsets such
as `IHS_Problem_List`, `IHS_PROBLEM_SUPERSET`, and `PXRM_DIABETES`.

### Existing C0TS web shape

The local C0TS web routines already expose terminology browsing routes:

- `GET /bsts/codeset` -> `wsCDSETS^C0TSWS`
- `GET /bsts/codelist` -> `wsCDLIST^C0TSWS`
- `GET /bsts/concept` -> `wsCON^C0TSWS`
- `GET /bsts/subset` -> `wsSUBLST^C0TSWS`
- optional `GET /bsts/code` -> `wsCODE^C0TSWS`

These are good low-level terminology endpoints, but they are not yet a C0RG
contract. C0RG should hide provider differences and return a normalized response
for UI consumers.

### Existing Lexicon proof point

The live server already has a VistA Lexicon terminology adapter:

- [`/r/KBAITLEX`](http://fhir.vistaplex.org:9080/r/KBAITLEX)
- [`/term/diabetes`](http://fhir.vistaplex.org:9080/term/diabetes)

`KBAITLEX.wsSctTerm` does a SNOMED term search through VistA Lexicon:

```mumps
S ok=$$TAX^LEX10CS(term,codesys,dt,"LEXTAX",0)
```

It then walks `^TMP("LEXTAX",$J,...)` and returns rows with:

- `code`
- `text`
- `date`
- `codeSystem`

The uploaded `/term/diabetes` capture shows this works for real UI output. It
returns hundreds of SNOMED CT rows with columns `Code`, `Text`, `Code System`,
and `Code System Date`, for example `111552007` "Diabetes mellitus without
complication" and `44054006` "Diabetes mellitus type 2".

This is a strong C0T/VistA provider prototype. It proves the gateway does not
need BSTS for every terminology search. For VistA-native diagnosis search, the
Lexicon can be the local authority, and C0RG can wrap it in the same response
shape as BSTS.

## Proposed C0RG operations

Use the existing `/rehmp` envelope and add `TERMINOLOGY.*` operations to
`DISPATCH^C0RGAPI`.

Initial operations:

| Operation | Purpose |
| --- | --- |
| `TERMINOLOGY.CODESETS` | List known code systems/codesets. |
| `TERMINOLOGY.CODELIST` | List codes in a codeset, with paging. |
| `TERMINOLOGY.SUBSETS` | List subsets for a codeset. |
| `TERMINOLOGY.SUBSET` | List codes in a subset. |
| `TERMINOLOGY.SEARCH` | Search terms for a UI picker. |
| `TERMINOLOGY.CONCEPT` | Return concept/code detail. |
| `TERMINOLOGY.TRANSLATE` | Map one code to a target system. |

Example request:

```json
{
  "apiVersion": "1.0",
  "requestId": "term-diabetes-001",
  "operation": "terminology.search",
  "payload": {
    "source": "auto",
    "use": "diagnosis",
    "query": "diabetes",
    "system": "SCT",
    "targetSystem": "ICD10CM",
    "max": 50
  }
}
```

Example response:

```json
{
  "apiVersion": "1.0",
  "requestId": "term-diabetes-001",
  "status": "ok",
  "data": {
    "source": "c0t-vista-lexicon",
    "items": [
      {
        "code": "44054006",
        "display": "Diabetes mellitus type 2",
        "system": "http://snomed.info/sct",
        "codeSystem": "SCT",
        "versionDate": "Jul 01, 2005",
        "selectable": true,
        "maps": [
          {
            "targetSystem": "ICD10CM",
            "code": "E11.9",
            "display": "Type 2 diabetes mellitus without complications",
            "source": "lexicon"
          }
        ]
      }
    ],
    "paging": {
      "offset": 0,
      "count": 50,
      "hasMore": true
    }
  }
}
```

## Provider model

### `online-bsts`

Use when a site wants to delegate to an online terminology service.

Implementation choices:

- HTTP proxy to a configured C0TS/BSTS web endpoint, such as `/bsts/codeset`,
  `/bsts/codelist`, `/bsts/subset`, and `/bsts/concept`.
- Direct M calls to installed BSTS remote APIs, allowing BSTS itself to choose
  an active DTS server.

Pros:

- Reuses the same public C0TS JSON shape already demonstrated by
  `/bsts/codeset?format=json`.
- Fits RPMS sites whose source of terminology truth is the IHS BSTS/DTS update
  path.
- Can expose codesets and subsets that Lexicon alone does not model.

Risks:

- Online dependency can make UI pickers slow or unavailable.
- Public C0TS endpoints are browsing-oriented, so C0RG still needs normalized
  response shaping, paging, and error handling.
- Licensing and deployment policy may constrain what can be proxied or cached.

### `local-bsts`

Use installed BSTS files and APIs in local/cache mode.

Implementation choices:

- Call `CODESETS^BSTSAPI`, `SUBSET^BSTSAPI`, `SEARCH^BSTSAPIA`, and concept
  APIs with the local flag.
- Reuse C0TS data helpers such as `C0TSWSD`/`C0TSFM` when those routines are
  installed and maintained locally.

Pros:

- Same terminology identity as RPMS BSTS without requiring live network access.
- Uses FileMan-backed `^BSTS(9002318*)` data.
- Best fit for RPMS deployments that already update BSTS content by scheduled
  DTS refresh.

Risks:

- Cache freshness depends on local BSTS update jobs.
- Not every VistA test target has BSTS installed.
- Mapping APIs may return richer structures than current C0TS JSON exposes, so
  C0RG needs a deliberate normalized map/result model.

### `c0t-vista`

Use a new C0T provider over VistA Lexicon, ICD, CPT, and other local VistA
resources. `KBAITLEX.wsSctTerm` is the concrete prototype for this provider.

First useful calls:

- SNOMED term search with `$$TAX^LEX10CS(term,"SCT",date,"LEXTAX",0)`.
- Diagnosis search with `$$DIAGSRCH^LEX10CS`, especially for ICD-10 diagnosis
  pickers.
- SCT-to-ICD-10 mapping with `GETASSN^LEXTRAN1(SCT,5217693)` followed by
  `ICDDX^ICDEX`.
- ICD validation/detail through `ICDDX^ICDEX`.
- CPT validation/detail through file `81` or CPT APIs where present.

Pros:

- Best match for VistA writeback because PCE, Problem List, and ICDEX ultimately
  need local VistA-resolvable diagnosis/procedure codes.
- Works even when BSTS is absent.
- The live `/term/diabetes` endpoint proves Lexicon search can already drive a
  browser terminology list.

Risks:

- Lexicon search output is not automatically the same as a problem-list-safe or
  POV-safe picklist.
- SNOMED results may still need ICD resolution before C0FW can file a
  Condition/POV.
- The existing `KBAITLEX` shape is useful but old: C0RG should not expose
  `^gpl` debug globals or KBAI-specific HTML helpers as the long-term contract.

## Source selection policy

Use `payload.source` to let clients or configuration choose behavior:

| Source | Meaning |
| --- | --- |
| `auto` | Try configured preferred provider, then fallbacks by operation. |
| `online-bsts` | Use online BSTS/C0TS or remote BSTS/DTS. |
| `local-bsts` | Use local BSTS FileMan/cache APIs only. |
| `c0t-vista` | Use Lexicon/ICD/CPT/VistA resources. |
| `syn` | Optional later provider over SYN maps such as `sct2icd`. |

Recommended defaults:

- `TERMINOLOGY.SEARCH` with `use=diagnosis`: `c0t-vista` first on VistA,
  `local-bsts` first on RPMS, `online-bsts` fallback when configured.
- `TERMINOLOGY.CODESETS`: `local-bsts` or `online-bsts`; Lexicon does not have
  an equivalent codeset catalog.
- `TERMINOLOGY.TRANSLATE` from SCT to ICD-10 for writeback: Lexicon first,
  BSTS mapping advice second where installed, SYN maps as a demo/intake fallback.

## Diagnosis picker implications

For the reHMP CPRS demo and CPRS-on-FHIR, the diagnosis picker should not bind
directly to `/bsts/*` or `/term/*`. It should call C0RG:

```text
POST /rehmp
operation: terminology.search
```

The UI should receive normalized rows and submit the selected row into the
FHIR writeback bundle:

- `Encounter`
- `Encounter.note[]` with user-authored support text
- `Condition` referencing the Encounter fullUrl
- `Condition.code.coding[]` containing the selected ICD/SNOMED codings
- `vista-add-to-problem-list` extension when the user checks "add to problem
  list"

C0FW should still validate the submitted coding at write time. Terminology search
is a picker convenience, not the final filing authority.

## Recommended first implementation slice

1. Add `C0RGTER.m` and route `TERMINOLOGY.SEARCH` in `C0RGAPI.DISPATCH`.
2. Implement `source=c0t-vista` for SNOMED search using the `KBAITLEX` pattern:
   `TAX^LEX10CS(term,codesys,date,"LEXTAX",0)`.
3. Normalize rows to `items[]` with `code`, `display`, `system`, `codeSystem`,
   `versionDate`, and `source`.
4. Add `use=diagnosis` behavior that attempts SCT-to-ICD-10 enrichment through
   Lexicon association `5217693`, but still returns the SNOMED row if unmapped.
5. Add `source=local-bsts` later by wrapping `BSTSAPI` local calls.
6. Add `source=online-bsts` by proxying configured C0TS HTTP endpoints or by
   calling BSTS remote APIs when installed.
7. Add UI picker support in reHMP CPRS demo against the C0RG operation, not
   directly against provider-specific endpoints.

## Open questions

- Should `auto` default be configured per site in C0RG parameters, or inferred
  from installed routines (`BSTSAPI`, `LEX10CS`, `C0TSWS`)?
- Should `TERMINOLOGY.SEARCH` return only selectable diagnosis concepts for
  `use=diagnosis`, or should it also return broader SNOMED administrative and
  family-history concepts with `selectable=false`?
- Should C0RG expose FHIR terminology resources (`ValueSet`, `CodeSystem`,
  `$expand`, `$lookup`, `$translate`) later, or keep the compact C0RG envelope
  contract for UI use?
- How much mapping metadata should the UI see: only the chosen ICD target, or
  map advice/rule/group/priority from BSTS where available?
- Do public endpoints need rate limits or max-result caps before diagnosis
  search is exposed broadly?

## Bottom line

BSTS gives us the RPMS terminology/cache model, and `KBAITLEX` proves that local
VistA Lexicon can already serve useful SNOMED search results through a web
adapter. C0RG should sit above both. The first practical gateway should expose a
normalized `terminology.search` operation backed by a C0T/VistA Lexicon provider,
then add local/online BSTS providers behind the same response shape.
