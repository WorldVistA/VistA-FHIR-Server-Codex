# Iris quality dashboard performance — 2026-09-25

**Audience:** agents and humans debugging slow `/fhir-quality-dashboards/{measure}` on Iris  
**Code:** `QMRDIR` / `QMRDIRX` / `HASQMR` / `QMREMPTY` in `src/C0FQUAL.m`  
**Ops:** `scripts/iris-qmr-stub.sh`  
**Supersedes:** the “per-measure dashboards are slow” bullet in
`docs/iris/IRIS_PUBLIC_LANE_2026-09-10.md` (that note blamed per-patient FHIR
bundle builds; the measured culprit was missing MeasureReport filesystem probes).

## Symptom

| URL | Before fix | After A+B+C |
|---|---|---|
| `/fhir-quality-dashboards` (index) | ~0.2s | ~0.2–0.4s |
| `/fhir-quality-dashboards/CMS122v14` | ~12s | ~0.2s |
| `/fhir-quality-dashboards/CMS165v14` | ~60s | ~0.2–0.3s |

fhirdev stayed ~0.4s throughout — it already had a real
`…/filesystem/quality/measurereports/` tree.

## Root cause

Each curated POP (and some graph) row called `$$HASQMR` → `$$QMRDIR`, which
probed three missing directories via `$$FTGOK^C0FHIRWS` → `FTG^%ZISH` for
`index.html`:

1. `$HOME/www/filesystem/quality/measurereports/` (`HOME=/home/irisowner` on Iris)
2. `/home/vehu/www/…`
3. `/home/osehra/www/…`

No published QMR tree existed under `^%webhome` (`/durable/www/`). Probes were
**uncached**, so cost scaled with POP size (~2s per failed open on this box).

The index page never called `HASQMR`, so it stayed fast.

## Fixes (A + B + C)

| | Change |
|---|---|
| **A** | Cache `^TMP("C0FQMRDIR",$J)` for the job (positive **and** empty). |
| **B** | Prefer `^%webhome…/filesystem/quality/measurereports/`, then `/durable/www/…`. If `^%webhome` is set, skip GT.M `vehu`/`osehra` homes. |
| **C** | Publish a stub tree under durable www: `index.html` + `EMPTY`. `QMREMPTY` short-circuits `HASQMR` so an empty stub does not pay per-DFN Patient-*.json misses. |

Stub path (host → container):

```text
/opt/iris/durable/www/filesystem/quality/measurereports/
  index.html
  EMPTY          # remove when real freezes are copied in
```

Redeploy stub:

```bash
./scripts/iris-qmr-stub.sh   # default root@irisfhir.vistaplex.org
```

## Verify

```bash
BASE=https://irisfhir.vistaplex.org
curl -sS -o /dev/null -w 'index %{http_code} %{time_total}s\n' --max-time 15 "$BASE/fhir-quality-dashboards"
curl -sS -o /dev/null -w 'CMS122 %{http_code} %{time_total}s\n' --max-time 30 "$BASE/fhir-quality-dashboards/CMS122v14"
curl -sS -o /dev/null -w 'CMS165 %{http_code} %{time_total}s\n' --max-time 30 "$BASE/fhir-quality-dashboards/CMS165v14"
```

Expect HTTP 200 and totals well under 1s for curated Iris POP sizes.

## When publishing real freezes

1. Copy measure dirs / `Patient-{DFN}.json` under the measurereports root.
2. **Remove** the `EMPTY` file so `HASQMR` resumes per-patient checks.
3. Keep `index.html` (QMRDIR still keys off it).

## Related

- Iris public lane narrative: `docs/iris/IRIS_PUBLIC_LANE_2026-09-10.md`
- Quality dashboard behavior: `docs/FHIR_QUALITY_DASHBOARDS.md`
- C0X on Iris (separate lane): `fhir-triple-store/scripts/iris-c0x-deploy.sh`
