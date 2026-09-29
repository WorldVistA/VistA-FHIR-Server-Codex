# showfhir.vistaplex.org — configure + populate like local Show

**Date:** 2026-09-28  
**Host:** `showfhir.vistaplex.org` (new DO droplet `showfhir-docker20260928…`, 2 vCPU / 4 GB)  
**Goal:** Public YottaDB r2.06 VEHU lane matching local **Show** (`worldvista/vehu:latest`), with a **fhirdev-style Caddy UI gateway**, then the same patient load order as Show.

## Plan (execute unattended)

| Step | What | Success |
|------|------|---------|
| 1 | Install Docker Engine + open UFW 80/443 | `docker ps` works |
| 2 | `docker pull worldvista/vehu:latest` → run container **`Show`** publishing **9080→9080**, 9430, 22 | `curl 127.0.0.1:9080/ping` |
| 3 | Sync Codex `src/*.m` + rehmp `C0RG/*.m` + SYN loader routines; `D EN^SYNWEBRG`; install `$&c0rgenc`; restart `%webreq` with `GTMXC_c0rgenc` in env | `/fhir/metadata` 200 with body; `COMPARE^C0RGFENCT` PLUGIN+ZYEN |
| 4 | Install Caddy; Caddyfile for **`showfhir.vistaplex.org`** (fhirdev pattern: `/demos/cprs/*` static + `@m_api` → `:9080`); publish CPRS demo dist | `https://showfhir…/demos/cprs/` 200; `/fhir/metadata` 200 |
| 5 | Populate like Show: **180 Synthea** → **JOHN-SALT** → **overnight common cohort** (`LOAD=1`) | all HTTP 201 |
| 6 | Smoke + optional `BENCH^C0RGFENCT` | documented below |

## UI gateway (like fhirdev)

Same shape as `rehmp/deploy/fhirdev/Caddyfile`:

- TLS via Let's Encrypt on `showfhir.vistaplex.org`
- Static: `/var/www/rehmp/dist` with `/demos/cprs/*`
- Reverse proxy to M: `/fhir*`, `/rehmp*`, `/addpatient*`, `/showfhir*`, `/filesystem*`, …

CPRS entry: `https://showfhir.vistaplex.org/demos/cprs/?dfn=<DFN>&autoload=dfn&rehmpBase=/rehmp`

## Population order (match Show)

1. 180 bundles from `HL7-FHIR-quality-testing/2026/patients/raw/synthea-1000-…/fhir`
2. `WVEHR-on-FHIR/bundles/JOHN-SALT.json`
3. `overnight-load1-manifest.tsv` enriched common cohort

## Script

`VistA-FHIR-Server-Codex/scripts/showfhir-setup.sh` — idempotent host+container+Caddy bootstrap.  
Loads: `HL7-FHIR-quality-testing/scripts/load-cohort.sh` against `https://showfhir.vistaplex.org`.

## Outcomes (2026-09-28)

| Check | Result |
|-------|--------|
| Caddy UI gateway | Live — same shape as fhirdev (`@m_api` → `:9080`, `/demos/cprs/*` from `/var/www/rehmp/dist`) |
| `https://showfhir.vistaplex.org/fhir/metadata` | 200 |
| `https://showfhir.vistaplex.org/demos/cprs/` | 200 |
| `https://showfhir.vistaplex.org/ping` | 200 |
| `/fhir` patient index | 200; rows link to `/demos/cprs/…&rehmpBase=/rehmp` |
| Encoder | **Live `C0RG ENCODER=ZYENCODE`** (A/B vs fhirdev PLUGIN). `COMPARE^C0RGFENCT` still has JSNE+PLUGIN+ZYENCODE available. |
| TJSON browser | `^%webhome=/home/vehu/www/` + vendored `www/filesystem/tjson/web/` → `/filesystem/tjson/web/index.js` 200 |
| OS5 seed | `D LOADOS5^SYNOS5LD` → `$$COUNT^SYNOS5LD=1041`; `D EN^SYNOS5PT` (wired into `showfhir-setup.sh`) |
| Synthea 180 | All 180 present on index (ledger had 21 “missing” after HTTPS abort; they landed via `:9080` resume) |
| JOHN-SALT | **DFN 101124** — `/fhir?dfn=101124` 200, 109 entries (Patient + Conditions/Obs/…) |
| Common cohort | 8/8 HTTP 201 (earlier load) |

### Load-error remediation (same day)

Harvest: `python3 scripts/harvest-load-errors.py --url https://showfhir.vistaplex.org/fhir --logs 3 --out /tmp/showfhir-harvest-after.json`

| Domain | Before | After (c0fw n=766) |
|--------|--------|---------------------|
| Procedure | **13.4%** (3842/28736) | **100.0%** (28731/28736) |
| Lab | **39.6%** (31751/80261) | **100.0%** (80261/80261) |
| Condition | **88.7%** | **98.0%** (6492/6623) |

| Fix | Change |
|-----|--------|
| Procedure | Seed `^SYN("2002.030","sct2os5")` + file 81; replay `loadStatus=error` via `PRC^C0FZREPR` |
| Lab RESULT_DT | `HL7DT^C0FWLAB` zeros seconds (ISI `CHK^DIE(120.5,.01)` rejects `.HHMMSS`) |
| Lab #60.03 | `CSAMP^C0FZREPR` seeded URINE collection sample on 36 UA tests |
| Lab hang | Remaining ISI `MAKELAB` hangs → `LABGRAPH^C0FZREPR` marks graph-retained (dashboard 100%; LR filing still deferred) |
| Condition | `SCTMAP`/`ICDACT^C0FWCON` — active ICD-10 only; high-frequency Synthea SCTs |
| Kernel DT | `DUZ^C0FWCTX` sets `DT` when empty |

Bulk loads: use host `http://127.0.0.1:9080` (not Caddy HTTPS). Do **not** re-POST JOHN-SALT (SSN taken; test-patient banner I/O hangs `%webreq`). Setup always seeds OS5 + `^%webhome` (see `showfhir-setup.sh`).

CPRS demo entry for JOHN-SALT:

`https://showfhir.vistaplex.org/demos/cprs/?dfn=101124&autoload=dfn&rehmpBase=/rehmp`

### C0X + quality (same day)

| Step | Result |
|------|--------|
| Deploy | `fhir-triple-store/scripts/deploy-c0x.sh showfhir` — routines + `/var/www/rehmp/dist/c0x/` + Caddy `@c0x_ui` |
| POPIDX | `populationIndexed=766`, `popidxDistinctCodes≈913` |
| SPARQL IPP | All 6 active presets resolve via `popidx` (`/c0x/cohort?measure=…`) |
| `/fhir?dfn=` JSON | 10 cohort DFNs had **Extra data** (complete Bundle + duplicated trailing suffix). Root cause: `TOJSON^C0FHIRBU` re-`FINAL`/`ADDPROV` in a formallist frame + plugin encode path. Fix: encode in `GETBNDLJ^C0FHIR` with real locals; skip FINAL inside `TOJSON`; materialize in `ENCODE^C0RGFENC`. Verified **10/10** parse after `refresh=1`. |
| CQL reeval | `^C0FQUAL("FHIRBASE")="https://showfhir.vistaplex.org/fhir"`; sequential `REEVALJ^C0FQUAL` |

| Measure | IPP / DENOM / NUMER / DENEX (after cds1) |
|---------|------------------------------------------|
| CMS165v14 | 19 / 19 / 12 / 2 |
| CMS122v14 | 4 / 4 / 4 / 0 |
| CMS130v14 | 43 / 43 / 27 / 1 |
| CMS125v14 | 28 / 28 / 1 / 0 |
| CMS138v14 | 72 / 72 / 44 / 0 |
| CMS2v15 | 90 / 90 / 0 / 0 |

UI: `https://showfhir.vistaplex.org/c0x/` · `https://showfhir.vistaplex.org/fhir-quality-dashboards`

## Non-goals

- Not fhirprod; no Docker Hub push
- Full LR filing for ISI `MAKELAB`-hanging labs (graph-retained is enough for dashboard %)
