# irisfhir public lane — Caddy/TLS, quality dashboards, rehmp, common cohort — 2026-09-10

Third act of the IRIS day (after the sixth-lane wiring and the first patient).
irisfhir.vistaplex.org is now a **public, TLS-fronted, populated** VistA-on-IRIS
demo: FHIR + quality dashboards over HTTPS, the rehmp CPRS-class web UI, and
the fleet's common cohort scored by official CQL.

## What went up

| Layer | Detail |
|---|---|
| Edge | Caddy (official apt repo) → `reverse_proxy 127.0.0.1:9080`; Let's Encrypt cert `CN=irisfhir.vistaplex.org` (issuer YE2, expires Dec 2026); UFW opened 80/443. `scripts/iris-public-setup.sh`. |
| rehmp backend | 19 `C0RG*` routines + `C0RGWEB` imported (UDL `ImportDir`) — **compiled clean first try, no GT.M-ism triage**; `POST /rehmp → WSREHMP^C0RGWEB` registered. |
| rehmp UI | `rehmp/ehmp-ui/rehmp-cprs-demo/dist` published to `/var/www/rehmp`, served at `https://irisfhir.vistaplex.org/demos/cprs/`. |
| Cohort | 12 patients (14-bundle load1 manifests, 2 Synthea-ICN dedupes) via `load-cohort.sh` at `LOAD=1`; file 2 now holds DFN 1–12. |
| Quality | `SEEDCRIT^C0FQUAL`; official CQL re-eval per measure via cds1 `/quality/evaluate-cohort`. |

## The load-bearing new capability: `%WC` on IRIS

The quality re-eval calls cds1 over HTTPS through `%^%WC` (Sam Habiel's curl web
client). Its transport is a GT.M/YottaDB `PIPE` device running `curl` — neither
`PIPE` nor `curl` exists in the stock IRIS container. Added a native IRIS branch
to `src/_WC.m` using `%Net.HttpRequest` (object calls wrapped in `XECUTE` so the
same source still compiles on GT.M, the C0FWOS-shim pattern), plus a `C0SSL`
SSL configuration (created by the setup). Verified: `GET https://cds1.vistaplex.org/`
returns 200 through the new branch.

## Official-CQL results over the cohort (honest numbers)

cds1 fetched each patient from `https://irisfhir.vistaplex.org/fhir?dfn=N` over
TLS and ran cqm-execution. Per-measure IPP / DENOM / NUMER:

| Measure | IPP | DENOM | NUMER |
|---|---|---|---|
| CMS122v14 (diabetes HbA1c poor control) | 1 | 1 | 1 |
| CMS125v14 (mammography) | 1 | 1 | 0 |
| CMS130v14 (colorectal screening) | 2 | 2 | 0 |
| CMS138v14 (tobacco screening) | 3 | 3 | 3 |
| CMS165v14 (controlling BP) | 2 | 2 | 1 |
| CMS2v15 (depression screening) | 4 | 4 | 0 |

Each measure's POP was then trimmed to its IPP members (fleet convention:
curated POP = cohort of interest), which is also what keeps dashboards fast.

## Two things found and handled

- **cds1 fetch URL is `{fhirBase}?dfn=N`** — `fhirBase` must include the
  `/fhir` path. First attempt with `https://irisfhir.vistaplex.org` (no `/fhir`)
  got `Invalid JSON from …?dfn=1` (cds1 hit the portal HTML). Set
  `^C0FQUAL("FHIRBASE")="https://irisfhir.vistaplex.org/fhir"`. This matches
  `FHIRBASE^C0FQUAL`, which appends `/fhir` when deriving from the request host.
- **Per-measure dashboards are slow on this box** — each builds a FHIR bundle
  per curated POP DFN (~12s/patient, single-threaded listener, 2 vCPU, large
  Synthea bundles), and the render doesn't reuse a table cache. Curated (IPP-only)
  POP keeps every measure under Caddy's window (12–48s). Caddy `reverse_proxy`
  timeouts raised to 300s as headroom. **Perf follow-up**: cache the dashboard
  table bundles or parallelize; today it is correct-but-slow, not a hang (a full
  12-patient POP rendered correctly at 144s direct on :9080).

## C0FHIR browser static assets (`^%webhome`)

The C0FHIR browser core works (632 resources rendered for DFN 12), but its
TJSON syntax-highlight view fetches `/filesystem/tjson/web/index.js` — a static
ESM module, not an allowlisted `WSASSET` blob. `FILESYS^%webapi` serves
`/filesystem/*` from the `^%webhome` docroot (Cache/IRIS via `$ZU(168)`), which
was unset. Fixed to fleet parity: deployed the vendored `tjson/web` bundle to
`/opt/iris/durable/www/filesystem/tjson/web/` (durable mount) and set
`^%webhome="/durable/www/"`. `index.js` now serves as `application/javascript`.
Folded into `iris-web-setup.sh` (asset deploy + `^%webhome`) and asserted by the
lane smoke, so a snapshot restore re-establishes it.

## TaskMan note

`D ^ZTMB` fails on IRIS with `PLA:IRIS is the wrong type in taskman site
parameters` — the box-volume type isn't configured for an IRIS node, so the
queued re-eval path (`DO ^%ZTLOAD → REEVT`) can't run. Worked around by calling
the worker `REEVALJ^C0FQUAL(measure)` in the **foreground**. Follow-up: fill in
TaskMan site parameters for the IRIS node so the dashboard "Re-evaluate CQL"
button works unattended (it also affects the validate-report task).

## Evidence (rerunnable)

| Claim | Command |
|---|---|
| Public TLS + UI up | `scripts/iris-public-setup.sh` |
| Web listener + routes | `scripts/iris-web-setup.sh` |
| Lane green (17 checks incl. rehmp, dashboard counts, SYN/gtree) | `scripts/iris-lane-smoke.sh` |
| Six-lane fleet, no GT.M regression | `QUALITY_SKIP_DEPLOY=1 scripts/deploy-quality-all.sh` |
| rehmp gateway | `curl -X POST -d '{"apiVersion":"1.0","operation":"patient.search","payload":{"searchType":"auto","searchString":"MARQ"}}' https://irisfhir.vistaplex.org/rehmp` |
| One dashboard w/ live counts | `curl https://irisfhir.vistaplex.org/fhir-quality-dashboards/CMS138v14` |

Full fleet smoke 2026-09-10: `OK fhirdev / vehu10 / rpms-candidate / rpmsfhir /
fhirprod` + `OK irisfhir (non-blocking lane)`, exit 0.

## Blank-note bug (evening): missing SYN routines on IRIS

User report: AI Consult text did not appear in the signed note (rehmp CPRS
demo, DFN 11) — the note read back with an empty body.

**Diagnosis path (each step ruled a layer out):**

1. The saved writeback artifact (`GET /writebacksaves/wbs-67823-82750-101350`)
   showed the client **had** submitted the full note text in
   `Encounter.note[0].text` — UI exonerated.
2. `^TIU(8925,1,"TEXT",1..18)` held all 18 lines — C0FW TIU filing exonerated.
3. The FHIR read returned `attachment.data=""` — read-side.
4. Root cause: `$$B64^C0FHIR` delegates to `$$ENCODE64^SYNWEBUT` and silently
   returns `""` when that routine is absent. Only `SYNWEBRG` had been imported
   to IRIS; the other 55 `SYN*` support routines from
   `VistA-FHIR-Data-Loader/src` (present on every GT.M fleet server) were
   never imported. Same root cause as the `/gtree` 500
   (`<NOROUTINE> *SYNVPR`) and the cohort-load `"SYNFHF is not installed;
   cannot file CarePlan health factors"` skips.

**Fixes:**

- Imported all 56 `SYN*.m` via UDL `ImportDir` (53 clean; SYNYOTTA /
  SYNLINIT / two GT.M-guarded `tstart ():serial` lines in SYNWEBUT fail
  compile, none load-bearing — `$$ENCODE64^SYNWEBUT` verified working).
  Folded into `iris-web-setup.sh` step 1c so a snapshot restore
  re-establishes it; new lane-smoke check (`/gtree/DD(0)` via SYNVPR) guards
  the class.
- Second, latent cross-platform bug found on the way: `$$DOMTOK^C0FHIR` had
  no `DOCUMENTREFERENCE` alias and ended in a **valueless `QUIT`** — an M17
  `<COMMAND>` error on IRIS (and a `QUITARGREQD` on GT.M) for any
  unrecognized `domain=` value. Fixed: document aliases map to `ENCOUNTER`
  (GETENC emits DocumentReference) and unknown aliases return `""`.
- `iris-web-setup.sh` now multiplexes all ssh/scp over one ControlMaster
  connection — the droplet's `ufw limit 22/tcp` (~6 conn/30s) was refusing
  the script's burst of sequential connections.

**Verified:** `refresh=1` rebuild then cached read both return the full
944-byte note body over `/fhir` and over the rehmp gateway
(`patient.fhir.bundle`); `domain=DocumentReference` returns HTTP 200 with the
attachment; lane smoke 17/17; vehu10 full deploy + smoke green (no GT.M
regression from the C0FHIR change).

## Follow-ups

- Configure TaskMan site parameters on IRIS (unattended re-eval / validate).
- Cache or parallelize per-measure dashboard bundle builds (the 12s/patient cost).
- The stale pre-cohort `SUM`/`REEVAL` rows carried in the FOIA image are now
  overwritten with real cohort results; no action, noted for provenance.
- Cohort loads before the SYN import skipped CarePlan health-factor filing
  (`SYNFHF is not installed` in the load log). FHIR-side measure scoring was
  unaffected, but VistA-side reminders that key on health factors will miss
  them — re-file or reload if needed.
- The current droplet snapshot predates the SYN import and the `^%webhome`
  fix; `scripts/iris-web-setup.sh` re-establishes both after a restore
  (or retake the snapshot).
