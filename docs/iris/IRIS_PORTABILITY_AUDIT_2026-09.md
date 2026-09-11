# IRIS portability audit — VistA FHIR Server (Codex)

Date: 2026-09-09 (sprint Day 4). Method: lexical scan
(`scripts/iris-portability-scan.py`) over every product routine — 54 in
`src/` + 18 in `rehmp/C0RG` — plus the 22 vendored M-Web-Server
(`%web*`) routines, followed by manual triage of every hit. Raw scan
output: `scan-product-2026-09.md`, `scan-mws-2026-09.md` (same folder).

## Headline

**The product code is essentially IRIS-portable today.** 72 routines
yielded 13 construct hits, and only 3 of them need any work at all —
two `$ZTRNLNM` env lookups and one GT.M `OPEN` parameter list. The
Kernel/FileMan surface we call (`^DIC`, `^DIE`, `%ZTLOAD`, `^%DT`) is
the same API VA runs on Caché/IRIS in production, so it ports by
definition. The HTTP layer (vendored M-Web-Server) was **written
dual-platform from the start**: it switches on `%WOS`
(`$P($SYSTEM,",")=47` → GT.M, else Caché-family) and already contains
`|TCP|` device code for the Caché/IRIS side.

## Product-code findings (13 hits, triaged)

| Hits | Construct | Where | Verdict |
|---:|---|---|---|
| 4 | `$ETRAP` handlers | C0FHIR, C0FHIRWS, C0FWDOM, C0FWLAB | **Portable** — standard error trap, same on IRIS |
| 2 | `%ZTLOAD` (TaskMan) | C0FQRPT:226, C0FQUAL:764 | **Portable** — Kernel API, identical on IRIS-hosted VistA |
| 2 | `$ZTRNLNM("HOME")` | C0FHIRWS:104, C0FQUAL:601 | **Shim** — replace with `$$ENV^C0FWOS`; IRIS side uses `$SYSTEM.Util.GetEnviron()` |
| 1 | `OPEN IO:(READONLY:NOWRAP):5` | C0FWBULK:51 | **Shim** — GT.M device params; IRIS spelling is `"R"` mode. One line behind a `$$FOPEN^C0FWOS` |
| 4 | PIPE device / `NEWVERSION` / `DELETE` params | `_WC.m` (61, 80, 123) | **Dev tooling only** — the working-copy sync tool never ships to an IRIS runtime; exclude from the port |

Zero hits in product code for: `$ZCMDLINE`, `ZSYSTEM`, `ZGOTO`,
`$ZINTERRUPT`, `$VIEW`, byte-oriented `$Z` string functions, extended
global references, GT.M-specific `JOB` params.

## Dependency: M-Web-Server (22 routines, 59 hits)

Already dual-platform; the hits cluster in the GT.M half of existing
`%WOS` branches:

- Socket handling: GT.M socket devices vs `|TCP|` — **both already
  implemented** (`_webreq.m` lines 39–43, 157).
- gzip responses: GT.M-only by explicit guard (`$P($SY,",")=47` at
  `_webrsp.m:284`); on IRIS it falls through to uncompressed — works,
  just skips compression. Optional later: IRIS `$SYSTEM.Util.Compress`.
- `ZGOTO` (`_webreq.m:230`): debug-mode-only, inside a `%WOS="GT.M"`
  guard — no action needed.
- `ZSYSTEM`, `$ZTRNLNM`, `$ZCONVERT` (3+1+2 hits): inside GT.M branches
  or trivially shimmable the same way as product code.

**Risk note:** the Caché branches predate IRIS and have not been
exercised by us; "Caché-compatible" is a strong head start, not a
guarantee. That is what the verification day below is for. Our
`HTTPERR`-array error-body change (Day 1) touches `C0RGWEB`, not the
`%web` core, so it rides along unchanged.

## What a port actually costs

| Work item | Estimate |
|---|---|
| `C0FWOS.m` shim (`$$ENV`, `$$FOPEN`, platform detect mirroring `%WOS`) + swap the 3 call sites | ~half a day |
| Stand up IRIS Community Edition + VistA (WorldVistA/VEHU on IRIS image) and smoke the M-Web-Server Caché branches (sockets, TLS, chunked bodies) | 1–2 days |
| Run the Day-2 round-trip CI lane against the IRIS container (Synthea → addpatient → readback → clinical write harness); fix fallout | 1 day |
| Routine packaging for IRIS (`%RI`/`$system.OBJ` load script equivalent of `zlink` sync) | ~half a day |

**Total: 3–4 focused days to a green IRIS smoke, no license blocker**
(Community Edition suffices for everything above). The audit found no
rewrite-class item in product code.

## Recommended sequence

1. `C0FWOS.m` shim + the three call-site swaps (can merge now; it's a
   no-op on GT.M).
2. IRIS container with Kernel/FileMan + routine load script.
3. M-Web-Server smoke on IRIS; upstream fixes go back to the vendored
   copy with the Day-2 checksum manifest updated.
4. Point `ci-roundtrip-local.sh` at the IRIS image as a second lane.

Timely context: Augie's InterSystems thread and a possible December
hackathon (`Vista-on-FHIR/docs/emails/2026-09-augie-fhir-accomplishments-iris.md`)
— this audit is the "come talk to us" artifact: concrete, costed, and
showing the port is days, not months.
