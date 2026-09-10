# IRIS bring-up rehearsal — 2026-09-09

Companion to `IRIS_PORTABILITY_AUDIT_2026-09.md`. The audit was a lexical
scan; this is the **audit's predictions tested on a real InterSystems
IRIS instance**. Done locally against a disposable container the same
evening as the audit. Every claim below was executed, not inferred.

## Environment

- Image: `containers.intersystems.com/intersystems/iris-community:latest-em`
  → **IRIS 2026.1.0.234.1 Community**, valid license, capped to 8 cores
  (Community's core limit — the first blocker; see below).
- Data: the FOIA VistA database (`IRIS.DAT`, 4.5 GB) extracted from the
  year-old `glilly/iris-foia` image, mounted as a new `FOIA` namespace.
  Routine/global mappings recreated from the old instance's `iris.cpf`
  (`%DT`/`%DTC`/`%` → FOIA, `%Serenj*`/`%Z*` globals → FOIA, `TMP`/`XTMP`
  etc → IRISTEMP).

## First blocker (and fix)

The old `glilly/iris-foia` image would not start:
`InterSystems IRIS Community License expired` / `Invalid Community
Edition license, may have exceeded core limit`. Two causes, both solved
by a fresh host: (1) the embedded Community license in the ~18-month-old
image had expired; (2) Community refuses to start when it sees more than
8 cores. Fix: current Community image + `--cpus 8` (or a host with ≤8
cores). **No paid license needed for everything in this rehearsal.**

## Results — VistA on IRIS

- **FileMan runs.** In the `FOIA` namespace, `D DT^DICRW` returned
  `DT=3260910`; `^%ZOSF`, `^DD(0,0)="ATTRIBUTE^N^999^41"`, and Kernel
  routine `XUP` all present. The VistA data dictionary and Kernel came
  across intact under IRIS 2026.1.
- **All 55 product routines compile clean on IRIS.** Imported as UDL
  `.mac` (each needs a `ROUTINE name [Type=MAC]` header line — a
  packaging detail, noted for the load script) and compiled with `ck-d`.
  Only **one** needed a source fix: `C0FPSL` line 5 was a `;` comment in
  column 1 (GT.M tolerates it; IRIS reads column 1 as the label field
  and rejects `;` as an invalid tag). Fixed by adding the leading space
  every other comment line already had — committed, harmless on GT.M.
- **The portability shim works on real IRIS.** `$$ISGTM^C0FWOS()`
  returns `0` (correctly detects it is *not* GT.M) and
  `$$ENV^C0FWOS("HOME")` returns `/home/irisowner` — i.e. the shim's
  IRIS branch (`$SYSTEM.Util.GetEnviron`) executed. The Day-4 audit
  shim is validated, not just written.
- **The M-Web-Server layer partly runs already.** `$$UP^%webutils("abc")`
  returned `ABC` on IRIS. (`%`-routines needed a `%web*`→FOIA routine
  mapping — the same one-line config pattern the FOIA cpf already uses
  for `%DT`; not a code issue.)

## Remaining work = exactly what the audit predicted

The only compile failures left are 10, **all in the vendored
M-Web-Server dependency**, and each matches an audit line item:

| Routine(s) | IRIS error | Nature |
|---|---|---|
| `%webreq` (lines 12/29/146) | #1013 incorrect args | GT.M omitted-arg calls `start^%webreq(PORT,,...)`; the routine's OWN comment says "Cache can't accept empty arguments. Change to empty strings." |
| `%webreq` (230) | #1025 on `ZGOTO 0:NEXT^%webreq` | the debug-only `ZGOTO` the audit flagged, inside a GT.M branch |
| `%webreq`/`%webtest` | #1054 on `start^%webreq(...):(IN=` | GT.M JOB device-parameter syntax |
| `%webutils` (317/370) | #22 `<UNIMPLEMENTED> tstart ():serial` | GT.M `TSTART ():SERIAL` transaction syntax; IRIS spelling differs |
| `%webtest`, `%webjson*Test` | #1013 / `$&libcurl` external calls | **test-only routines**, not runtime; `$&` C-library calls are GT.M external-call syntax |

None of these are in our product code, and none is a surprise. The core
`%webreq` needs the empty-arg→empty-string change its own author already
anticipated for Caché; the rest is either debug/test scaffolding or the
`TSTART` syntax swap. This is a day of dependency work, matching the
audit's 3–4 day total estimate.

## Bottom line

The audit's headline held up under execution: **VistA + FileMan run on
IRIS 2026.1 Community, all product routines compile, the portability
shim works, and the only real remaining work is a known, bounded set of
M-Web-Server fixes.** The migrated FOIA database and a repeatable load
sequence are staged in `~/work/iris-migration/`. Next step is a
persistent `irisfhir.vistaplex.org` host to make this durable and wire
it into the fleet smoke as a sixth, non-blocking lane.
