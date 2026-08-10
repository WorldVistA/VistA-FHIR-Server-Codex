# Quality Reporting Pipeline on the Dashboards

**Date:** August 9, 2026
**Status:** Phases 1–3 implemented (`C0FQRPT.m` + cds1 hosted validator/receiver)

## Goal

Make the end-to-end FHIR quality reporting capability (DEQM Summary
MeasureReport, the QRDA Category III replacement) visible and clickable from
the quality dashboards, so the September Connectathon demonstration runs in a
browser instead of a terminal.

## What already existed

- `C0FQUAL.m` renders the summary dashboard, per-measure dashboards, and the
  **Re-evaluate CQL** button (official cqm-execution on cds1 → `SETPOP`/`SETSUM`).
- The workstation pipeline in `HL7-FHIR-quality-testing`
  (`build-deqm-summary.py`, `deqm-summary-receiver-smoke.sh`) builds, validates,
  and submits DEQM Summary MeasureReports; its **frozen artifacts** are
  published under `/filesystem/quality/measurereports/{CMS}/` and linked from
  each measure dashboard.

The gap: the published artifacts are a freeze. Nothing on the dashboards showed
the *live* counts as a standards-shaped report, and the pipeline steps were not
visible as a story.

## Phase 1 (this change) — live export + reporting page

New routine `src/C0FQRPT.m`, routes registered in `SYNWEBRG.m`:

| Route | What it does |
|---|---|
| `GET /fhir-quality-report?measure=CMS165v14` | DEQM STU5 Summary MeasureReport built in M, at request time, from `^C0FQUAL("SUM")` — the same aggregates the dashboards display |
| `GET /fhir-quality-report?measure=…&bundle=1` | Transaction Bundle (reporter Organization + report), the exact payload a DEQM receiver accepts |
| `GET /fhir-quality-reporting` | Pipeline page: the four steps (Calculate → Build → Validate → Submit), a live-report table for every active measure, and the reporter Organization for this lane |

Links added: summary dashboard → *Quality reporting (DEQM)*; each measure
dashboard's results card → *Live DEQM Summary MeasureReport* and *Live
submission Bundle*.

Design decisions:

- **JSON shape mirrors `build-deqm-summary.py` exactly** (profile, measureScoring
  extension, meta.tag provenance, group/population/measureScore) — that shape is
  validated against DEQM STU5 and accepted by the reference `deqm-test-server`.
- **Honest provenance:** live exports are tagged `setsum-live` with the SETSUM
  cohort text and as-of date in `meta.tag`; they never claim `official-cql`.
  The reviewed freeze remains the artifact of record for exchange.
- **Distinct ids** (`{CMS}-[lane-]live-summary-deqm`) so a live submission never
  overwrites a frozen one on a receiver.
- **Lane-aware reporter Organization** (fhirdev / rpmsfhir / fhirprod presets,
  RPMS detected via `$$ISRPMS^C0FWPOL`), matching the Python builder's presets.

## Phase 2 (implemented) — one-click Validate and Submit

- cds1 `quality-eval` sidecar gained `POST /quality/validate-report` (proxies
  the HL7 validator service with the `hl7.fhir.us.davinci-deqm` 5.0.0 package,
  applies the same known-IG-noise allowlist as the workstation smoke) and
  `POST /quality/submit-report` (POSTs the transaction Bundle to the hosted
  Tacoma `deqm-test-server`; `body.receiver` can point at Connectathon
  receivers).
- Hosted infra on cds1: `fhir-validator` (Inferno validator service,
  `DISABLE_TX=true`) joined the stage-2 compose; `deqm-test-server` + MongoDB +
  Redis run from their own compose at `/opt/deqm-test-server` with ports bound
  to the host loopback, reached by the sidecar over the compose network.
  Caddy routes `/quality/validate-report*` and `/quality/submit-report*` to
  the sidecar. (Upstream images referenced `dhi.io`, which requires auth —
  swapped to public `node:24`/`redis:7-alpine`.)
- M routes `POST /fhir-quality-report-validate|submit?measure=` follow the
  `WSREEVAL` pattern (accept fast, `JOB` the work, status in
  `^C0FQUAL("REPORT",CMS,op)`, page reloads to show the outcome). Buttons
  appear on `/fhir-quality-reporting` next to each live report.

## Phase 3 (implemented) — evidence log

- `LOGRUN^C0FQRPT` appends `^C0FQUAL("REPORT","LOG",n)` rows (timestamp,
  measure, step, outcome, detail); the last 20 render at the bottom of
  `/fhir-quality-reporting`, so the demonstration leaves a visible audit trail.

## Verified end to end (August 9, 2026, vehu10)

- Validate: `pass` — 1 validator error, which is the known DEQM STU5 IG
  supplementalData noise also present on the IG's own golden example; 0
  actionable.
- Submit: `accepted` — receiver returned 200/201 for the reporter Organization
  and MeasureReport entries.

## Verification (Phase 1 gate)

1. Sync to vehu10 (`./scripts/vehu10-fhir-sync.sh`), XINDEX clean on
   `C0FQRPT`, `C0FQUAL`, `SYNWEBRG`.
2. `GET /fhir-quality-report?measure=CMS165v14` returns JSON whose population
   counts equal `^C0FQUAL("SUM","CMS165v14")` pieces 2–5; `python3 -m json.tool`
   parses it.
3. `&bundle=1` returns a two-entry transaction Bundle that parses.
4. `/fhir-quality-reporting` lists all active measures with working links.
