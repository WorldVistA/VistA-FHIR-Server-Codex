# M Web Server Runaway Worker Analysis (2026-03-12)

This note documents a reproducible runaway-worker issue observed on `fhirdev.vistaplex.org` and a minimal hotfix applied for validation.

## Scope

- Target stack: `%webreq` / `%webrsp` in the M Web Server layer.
- Environment where reproduced: `fhirdev.vistaplex.org` (`glilly/fhir-dev-server:latest` container).
- Affected endpoint pattern: `GET /fhir?dfn=<N>` responses generated from a global-backed response structure.

## Symptom Summary

- Large accumulation of orphaned worker jobs:
  - many `mumps -direct` with `PPID=1`
  - high sustained CPU from these workers
- degraded endpoint behavior:
  - `/fhir` index remained responsive
  - `/fhir?dfn=...` often timed out

## Evidence Collected

### 1) Orphaned worker count and process profile

- Initial snapshot showed ~69 orphaned `mumps -direct` workers (`PPID=1`).
- Most were in `R` state and had been running for hours.

### 2) Socket correlation

- Orphan workers were correlated to port `9080` worker sockets.
- Distribution sample:
  - `mapped_orphan_sockets: 57`
  - TCP states: `CLOSE_WAIT: 55`, `ESTABLISHED: 2`
- This indicates worker jobs persisting after client-side disconnects.

### 3) Repro correlation by request type

- `GET /fhir` (no DFN) did **not** increase orphan count.
- Timed request to `GET /fhir?dfn=101083` did increase orphan count:
  - observed growth `69 -> 70 -> 71` with repeated timeout repro.

## Root Cause

In `_webrsp.m`, `SENDATA` contains a vertical traversal loop for global responses (`RSPTYPE=2`):

```mumps
. . F  D  Q:HTTPEXIT
. . . S HTTPRSP=$Q(@HTTPRSP)
. . . D:$G(HTTPRSP)'="" W(@HTTPRSP)
. . . I $G(HTTPRSP)="" S HTTPEXIT=1
. . . E  I $G(@HTTPRSP),$G(@ORIG),$NA(@HTTPRSP,OL)'=$NA(@ORIG,OL) S HTTPEXIT=1
```

The boundary-exit condition is incorrectly gated by `$G(@HTTPRSP)` and `$G(@ORIG)`.

When traversing nodes whose values are empty strings (common in M globals used as sparse trees), `$G(@HTTPRSP)` can be false even after traversal has moved outside the intended subtree, preventing `HTTPEXIT` from being set. Under disconnect/error paths, workers can remain stuck in response traversal and leak.

## Minimal Fix Applied for Validation

Remove value-based guards from the subtree boundary condition, leaving only subtree comparison:

```mumps
. . . E  I $NA(@HTTPRSP,OL)'=$NA(@ORIG,OL) S HTTPEXIT=1
```

### Rationale

- `$Q` traversal must stop based on structural boundary (`$NA(...,OL)`), not node value truthiness.
- Empty-string values are valid and should not suppress loop termination.

## Runtime Validation on `fhirdev`

After patching `_webrsp.m`, reloading `%webrsp`, and restarting `%webreq`:

- orphan workers cleaned back to listener baseline (`1` direct listener process)
- `GET /fhir?dfn=101083` returned quickly (`200 application/json`)
- stress run: `10` consecutive `GET /fhir?dfn=101083` requests
  - `ok=10`, `err=0`
  - orphan worker count remained stable at baseline (`1`)
- smoke checks passed:
  - `/fhir`
  - `/fhir?dfn=<sample>`
  - `/fhir?dfn=<sample>&view=browser`

## Notes for Maintainers

- The issue appears in response traversal semantics and should be considered independent of application-specific FHIR code.
- The fix is minimal and localized to `%webrsp` `SENDATA` global traversal loop.
- Recommend regression tests that include:
  - sparse global trees with empty-string values
  - forced client disconnect/timeouts during large response serialization
  - assertion that worker count does not grow under repeated aborted requests

