# BSTS / C0TS web services: format handling analysis and path forward

This document records the analysis of the `C0TS*` M routines used for the `/bsts/*` HTTP surface (terminology and codeset listings), the defects that were found, the fixes that were applied, and practical options and recommendations for ongoing work.

## Scope

Relevant routes (registered in `KBAIWS` and similar) include at least:

| Route | M entry |
|--------|---------|
| `GET bsts/codeset` | `wsCDSETS^C0TSWS` |
| `GET bsts/codelist` | `wsCDLIST^C0TSWS` |
| `GET bsts/concept` | `wsCON^C0TSWS` |
| `GET bsts/subset` | `wsSUBLST^C0TSWS` |
| (optional) `bsts/code` | `wsCODE^C0TSWS` (may be registered per environment) |

The routines live under names such as `C0TSWS`, `C0TSWSD` (data/caching), and `C0TSWSU` (HTML tables and, after this work, non-HTML serialization). Source is shipped in the `fhir` test container as `/home/osehra/p/C0TSWS.m` and related files; a working copy of the updated routines is also kept in this repository at `src/C0TSWS.m` and `src/C0TSWSU.m` for version control and deployment.

## Technical analysis

### 1. Documented but unimplemented `format` parameter

**Observation.** Comments and the HTML “this page: html | xml | json | csv” links describe `format=html|json|xml|csv` (and sometimes `mumps` / `yaml`).

**Finding.** The web handlers in `C0TSWS` only filled the HTTP response for `FORMAT="html"`. For any other `format=`, the routine exited with an empty return global. The M HTTP stack still chose a default `Content-Type` (for example `application/json` for JSON-style routes), so clients saw a **200 response with a zero-length body** for `?format=json`. That is easy to misread as a generic bug in the web layer when the real issue was an incomplete implementation in `C0TSWS`.

### 2. Spurious leading characters before HTML (e.g. a line count)

**Observation.** Some HTML responses began with a numeric prefix (for example a line count) before `<!DOCTYPE …>`.

**Finding.** `ADDTO^C0TSWSU` and similar helpers store a **line count** in `@RTN@(0)`. The GT.M code path in `VPRJRSP` walks the response global with `$QUERY` and emits **all** subscripted nodes, including subscript `0`, as part of the body. The value in `@RTN@(0)` is metadata (how many `ADDTO` lines), not a line of the document, so it was incorrectly serialized as the first “chunk” of the response.

**Fix pattern.** After building the HTML table, the handler calls `RMCNT0^C0TSWSU(RTN)` which removes `@RTN@(0)` so only real content subscripts are written.

### 3. Very large codelist JSON and GT.M string limits

**Observation.** `GET bsts/codelist?format=json` could return **500** with a large codeset (thousands of terms).

**Finding.** A naïve implementation that concatenates the entire document into a **single** M string can hit GT.M (and implementation) **maximum string length** limits. That surfaces as a runtime error, not a clear “payload too large” response.

**Fix pattern.** `WSCODEJ^C0TSWSU` was changed to **stream** the JSON: open the `rows` array across multiple `^TMP` lines that concatenate to valid JSON, instead of one monolithic string.

### 4. `max` and performance

Codelist handlers already support a `max` query parameter (defaulting to a high bound). It limits rows returned; large values still cost CPU and I/O. Streaming JSON does not remove the need for **reasonable defaults** and **pagination** if these endpoints are used heavily from the public internet.

## What was implemented (summary)

- **End-to-end support** for `format=json`, `format=xml`, `format=csv`, and `format=mumps` on the main `bsts/*` entry points, consistent with the comments in the routines.
- **Coercion of unknown formats** (for example `yaml`) to JSON via `UNKFMT^C0TSWSU`, so links do not break silently to empty output.
- **`RMCNT0^C0TSWSU`** to strip `@RTN@(0)` on HTML output after `ADDTO`/`GENHTML`.
- **Safe JSON** for `codelist` / `subset` lists via **multi-line** construction in `WSCODEJ`.
- Helpers in `C0TSWSU` for **JSON escaping**, **CSV field quoting**, and **minimal XML** where hand-built (no full schema enforcement).

Routines in this repo: `src/C0TSWS.m`, `src/C0TSWSU.m` (kept in sync with the `fhir` container under `/home/osehra/p` when testing).

## Options going forward

### A. Keep and maintain the hand-built serializers (current approach)

- **Pros:** No new dependencies; full control; works on existing GT.M stack; small surface area for the current JSON/XML/CSV needs.
- **Cons:** You must keep escaping, delimiter rules, and multi-line JSON streaming correct as formats evolve; maintenance burden grows if you add more fields or nested structures.

### B. Reuse VistA’s JSON or XML encoders

- The environment already has patterns such as `ENCODE^VPRJSON` (and similar) used elsewhere. You could build a M structure (global or local) and call the encoder for **code detail** and **small** lists.
- **Pros:** One standard path to JSON; fewer hand-rolled strings.
- **Cons:** You must still respect **string size** for huge lists; encoders need an array shape they understand; not every legacy structure is a drop-in.

### C. Add explicit pagination and stable contracts

- Add query parameters such as `offset`, `count`, and maybe `summary=true`, and return **paged** JSON (FHIR or custom) with `total` and `link` for next page.
- **Pros:** Scales to large terminology installations; better for browsers and for integration.
- **Cons:** Requires client updates and a clear versioning story.

### D. Map terminology to FHIR `CodeSystem` / `ValueSet` (longer term)

- Expose a thin FHIR R4 read layer (or a small Operation) on top of BSTS, instead of or in addition to `BstsCodesetList` JSON.
- **Pros:** Interoperable with the rest of the FHIR ecosystem; aligns with a FHIR front door if that is a product goal.
- **Cons:** Larger design and implementation; SNOMED/VA licensing and identity rules still apply.

### E. Upstream in `bsts-vista` (or equivalent) vs fork-in-repo

- If `bsts-vista` (or the packaging that deploys to `fhir`) is the **canonical** home, merge these changes upstream and version them as a patch to `C0TS VISTA TERMINOLOGY SERVER`.
- If the canonical tree is not updated quickly, keep **`src/C0TSWS*.m` here** as the **deployment source of truth** for your containers, with a short “sync checklist” in ops docs (copy, `ZLINK`, smoke `curl`).

## Recommendations

1. **Treat `format=` as a supported contract**  
   Add a **short** HTTP surface doc (in your ops or API docs) listing supported `format` values, defaults, and `max` for list endpoints, so integrators are not depending only on comments in M.

2. **Default `max` for machine formats**  
   For `json`/`xml` on `codelist`, consider a **conservative default** (for example 500) with a clear error or metadata when truncated, *unless* you add pagination. This reduces accidental huge responses and long GC pauses.

3. **Keep `RMCNT0` (or move count off subscript 0) everywhere**  
   Any new HTML builder that uses `ADDTO` or stores a count in `^(0)` should either call `RMCNT0` before return or use a different convention (for example, store count under `^("meta","lines")` if the HTTP layer is updated to ignore that subtree).

4. **Regression smoke after deploy**  
   After any routine load: `curl` for `?format=html` (no leading garbage), `?format=json` (non-empty, parse with `python -m json.tool` or similar), and one **large** `codelist` with `format=json&max=...` to confirm no 500s.

5. **Align with a single source branch**  
   Decide whether **`bsts-vista`**, this repo’s `src/`, or the **container image** is canonical; document it so the team does not edit three divergent copies.

6. **Future: pagination before FHIR**  
   If these endpoints are used beyond demos, **pagination** (option C) is a higher return than adding more ad hoc formats; if product strategy is **FHIR-first**, start a small `CodeSystem` read design (option D) rather than growing custom JSON schema indefinitely.

---

*Document version: 1.0. Based on the C0TSWS / C0TSWSU analysis and changes described in the implementation session. Update this file if routes, defaults, or encoding strategy change.*
