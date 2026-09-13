# Panel + replay work plan — 2026-09-13

Work package assembled from the findings in
`PUBLIC_FLEET_COHORT_RECONCILIATION_2026-09-12.md`. Decisions recorded
2026-09-13 PM:

- **fhirprod is being retired** (container at fhir.vistaplex.org; the host
  stays and gets a new WorldVistA container — separate migration effort).
  All fhirprod dedupe/cache items are dropped from this plan.
- **Bundle parity approved**: graph-ON lanes (devfhir, rpmsfhir) should
  materialize panel member Observations like irisfhir does. Big bundles are
  wanted.
- **New experiment**: time continuation-slice processing on irisfhir vs the
  YottaDB lanes (which have gzip configured) to decide whether IRIS needs
  its compression enabled for long downloads.

## Phase 1 — Loader correctness (in progress)

1. **Namespace the SYNFPAN loop locals.** The panel entry loop dies after
   the first `LAB^ISIIMP12` filing (live iris run: 2 of 316 entries
   processed) — the lab chain KILLs an un-namespaced local, same class as
   the SYNFMED2 `args("load")` kill (fixed with SYNMLOAD) and the Sept
   Day-4 `LAST` kill. Identify the exact victim on a CI container, then
   namespace the loop state.
2. **Invalidate the bundle cache on replay** — `replayIntakeDomains^SYNFHIR`
   (and the panel/lab replay entries) should call `INV^C0FWCAC` so replays
   are immediately visible in rehmp/CPRS demos. devfhir served a
   pre-replay cached bundle (0 meds) until a manual `refresh=1`.
3. **Rehearse on a disposable `ci-roundtrip` container**: replay twice,
   counts hold, cache node cleared, panel loop reaches all entries.

## Phase 2 — Finish devfhir HARBER290

4. Visit-linkage bridge for Procedures (0/737) + CarePlans (0/10):
   `-1^Visit not found` — legacy loaders resolve visits via lowercase
   encounter markers; C0FW stored `visitIen` per entry. Map across.
5. Lab replay with a keyed user: ENTERED_BY requires a DUZ holding
   **LRLAB + LRVERIFY** (`^XUSEC`) — proven on iris (user 95
   PROVIDER,UNKNOWN SYNTHEA). Find devfhir's equivalent, replay labs
   (0/1669 + 316 panels), then triage null-value and LOINC→#60 residue.
6. Diagnose conditions (31/160) + immunizations (3/13) blank importer
   statuses (DEBUG-traced replay).
7. Decide whether to replay the rest of the devfhir cohort.

## Phase 3 — Panels in CPRS on iris

File-60 config is done (C0FZPAN: BMP 5091, CMP 5092, COAG 5093, DIFF 5094
+ 60.03 collection samples). Remaining:

8. Per-lane labs-map aliases so members resolve on FOIA: TOT PROT→TOTAL
   PROTEIN, TOT. BIL→BILIRUBIN,TOTAL, ALT→SGPT, ALK PHOS→ALKALINE
   PHOSPHATASE, + UA/CBC drops (NITRITE, LEUCOCYTE ESTERASE, RDW-CV, MPV).
9. Foreground lab rollover on IRIS (`ROLL^C0FZLACC`) scheduled daily (host
   cron → `iris session`); Taskman does not run on IRIS.
10. **Migration** for already-loaded patients: replay duplicates (LABDUP
    only checks the panel's exact RESULT_DT; individual filings sit at +1s
    offsets). Migration = delete individual CH rows, refile through the
    panel path. Rehearse on a VEHU CI container, then iris DFN 2 with CPRS
    visual verify, then the 13-patient cohort.
11. **C0FW panel bridge** so future loads file panels natively: the C0FW
    lab writeback files individuals only. Teach it to file panel-mapped
    DiagnosticReports through ISIIMP12 first, remainder to the individual
    filer.
12. Upstream (coordinate with Sam): LABDUP ±window hardening; push the
    PMEM null-LIEN guard (committed on VistA-DataLoader
    `fix/patient-state-pointer-file5`, unpushed).

## Phase 4 — Read layer

13. **Parity (approved)**: make graph-ON lanes materialize panel members —
    run the REFFIX member-emit pass in the graph-ON path too. Expected:
    devfhir/rpmsfhir demo bundles grow ~600 → ~4,600 resources.
14. **Slice-timing experiment**: measure per-slice latency, bytes, and
    Content-Encoding across irisfhir/devfhir/rpmsfhir walking the full
    bundle. Decide whether IRIS compression is needed for long downloads.

## Verification per phase (evidence gate)

| Phase | Rerunnable proof |
|---|---|
| 1 | CI container: replay ×2 + panel loop entry count + cache node check |
| 2 | devfhir dashboard tally row → N/N per domain |
| 3 | iris CPRS labs tab shows grouped panels for DFN 2; ^LR CH counts stable |
| 4 | walk script: slices × latency × bytes table per lane |
