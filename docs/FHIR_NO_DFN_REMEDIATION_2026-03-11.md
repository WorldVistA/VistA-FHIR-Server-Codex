# FHIR No-DFN Remediation (2026-03-11)

## Problem

Calling `GET /fhir` with no `dfn` returned a server error instead of a useful page.

Observed failure:

- `HTTP 500` from `/fhir`
- Error payload referenced:
  - `WEB+26^C0FHIRWS`
  - `LOGERR^C0FHIRGF`
  - `Label referenced but not defined: LOGERR`

## Root Cause

The web route is handled by `C0FHIRWS`, not directly by `C0FHIR`.

In `C0FHIRWS`:

- no-DFN requests were routed to an error path
- that path called `LOGERR^C0FHIRGF`
- `LOGERR` did not exist in `C0FHIRGF`

Result: hard 500 for `/fhir` when no `dfn` was supplied.

## Remediation Implemented

### 1) Added index-page behavior for no-DFN requests

- Updated `C0FHIRWS` no-DFN mode to call `FHIRIDX^C0FHIR(.RTN)` instead of erroring.
- Added source routine `src/C0FHIRWS.m` to this repository so web entry behavior is versioned.

### 2) Added HTML patient index renderer

- Implemented `FHIRIDX` in `src/C0FHIR.m`:
  - builds an HTML table of imported patients from `fhir-intake`
  - patient name links to `/fhir?dfn=<dfn>`
  - per-row links for:
    - original JSON (`/gtree/%25wd(17.040801,3,<ien>,%22json%22)`)
    - load log (`/gtree/%25wd(17.040801,3,<ien>,%22load%22)`)
    - VPR (`/vpr?dfn=<dfn>`)

### 3) Added per-patient domain count summaries

- Implemented `DOMSUM` in `src/C0FHIR.m`.
- Under each patient row, renders summary text per domain:
  - format: `<domain>:<loaded>/<source>`
  - derived from `^%wd(...,"load",<domain>,...)` status nodes.

### 4) Safety/helper additions

- Added `ADDLN` and `HTMLESC` helpers in `src/C0FHIR.m` for deterministic HTML output and escaping.

## Validation Performed

- `XINDEX` passed for:
  - `C0FHIR`
  - `C0FHIRWS`

- Endpoint smoke checks:
  - `/fhir` returns HTML index content with:
    - patient links
    - json/load/vpr links
    - domain summary lines
  - `/fhir?dfn=1530` continues returning JSON bundle

- Reference endpoints used for style/behavior comparison:
  - [`/bsts/codeset`](http://localhost:9081/bsts/codeset)
  - [`/r/C0TSWS`](http://localhost:9081/r/C0TSWS)

## Note

In this environment, `/fhir` currently returns HTML body content while the HTTP `Content-Type`
header still reports JSON from the web gateway layer. The no-DFN functional behavior and page
content are remediated; header normalization may require a gateway-level follow-up.

