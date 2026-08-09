# Quality Reporting Pipeline on the Dashboards

**Date:** August 9, 2026
**Status:** Phase 1 implemented (`C0FQRPT.m`); Phases 2–3 planned

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

## Phase 2 (planned) — one-click Validate and Submit

- Small endpoints on the cds1 `quality-eval` sidecar: `POST /quality/validate-report`
  (proxy to HL7 validator with the davinci-deqm package) and
  `POST /quality/submit-report` (POST Bundle to a configured receiver, default
  the hosted `deqm-test-server`; Connectathon receivers configurable).
- M routes `POST /fhir-quality-report-validate|submit?measure=` follow the
  `WSREEVAL` pattern (accept fast, `JOB` the work, status global, page polls).
- Buttons appear on `/fhir-quality-reporting` next to each live report.

## Phase 3 (planned) — evidence log

- `^C0FQUAL("REPORT","LOG",ts)` rows: measure, counts, validation outcome,
  receiver status; rendered at the bottom of `/fhir-quality-reporting` so the
  demonstration leaves a visible audit trail.

## Verification (Phase 1 gate)

1. Sync to vehu10 (`./scripts/vehu10-fhir-sync.sh`), XINDEX clean on
   `C0FQRPT`, `C0FQUAL`, `SYNWEBRG`.
2. `GET /fhir-quality-report?measure=CMS165v14` returns JSON whose population
   counts equal `^C0FQUAL("SUM","CMS165v14")` pieces 2–5; `python3 -m json.tool`
   parses it.
3. `&bundle=1` returns a two-entry transaction Bundle that parses.
4. `/fhir-quality-reporting` lists all active measures with working links.
