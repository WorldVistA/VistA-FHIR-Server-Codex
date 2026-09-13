# Public-fleet cohort reconciliation — 2026-09-12

Why the same Synthea patient shows different load tallies on each public
server, and the plan to reconcile them. Reference patient:
**HARBER290,AUDREA654** (same source bundle everywhere).

## Findings (from `/fhir-dashboard`, 2026-09-12)

| Server | DFN / IEN | Tally highlights | Diagnosis |
|---|---|---|---|
| devfhir | 101122 / 1399 | Medication 0/812, Procedure 1/738, CarePlan 0/10, Condition 31/160, Lab 2338/5094; tracks AIConsult/ServiceRequest, no Smoking | Loaded with an **early loader vintage**, before med/procedure/CarePlan writeback and lab accessioning config existed |
| fhirprod | 1652 / 1657 | Allergy 24/24, Encounter 1146/1146, Procedure 2211/2211 — everything ~3× true bundle content | **Loaded three times**; filing works (Condition 471/480), but the graph holds true duplicates |
| rpmsfhir | 1152 / 1150 | Condition 66/160, Immunization 11/13, Smoking 0/59; Lab 5035/5035 | Clean single load; shortfalls are the known **RPMS terminology-mapping gaps** |
| irisfhir | 2 / 2 | All domains 100%; Lab 5888/10685 | Healthiest. Lab denominator doubled by the 2026-09-11 accession re-file pass (attempt counter counts both passes) |

Rerunnable: `curl -sk https://<host>/fhir-dashboard` and read the
`<small>` tally row under HARBER290,AUDREA654.

## Plan

1. **Sync** current `C0F*`/`SYN*` routines to devfhir
   (`scripts/fhirdev-codex-sync.sh`).
2. **Replay from the stored graph** (IEN on the dashboard row), not from
   source files: the loader keeps per-entry `loadStatus` in the intake graph
   and can re-attempt unfiled entries (same pattern as `RELAB^C0FZLACC` on
   irisfhir).
3. **Rehearse duplicate safety first** on a disposable container: replay over
   a partially-loaded patient must skip filed entries (e.g. Condition 31/160
   → file only the 129) and end at N/N with no doubles.
4. **Check devfhir lab prerequisites** (accession areas, collection samples,
   numeric identifiers) — apply `C0FZLACC`-style fixes if gaps exist.
5. **Replay HARBER290 on devfhir**, confirm tallies move
   (Medication 0/812 → 812/812 etc.), then decide on the rest of the cohort.

Out of scope here: **fhirprod** dedupe (true duplicates from triple load;
needs the reviewed daytime flow) and RPMS terminology gaps (existing backlog).

## Findings from the rehearsal (2026-09-13)

Two `ci-roundtrip-local.sh --keep` containers, loader replayed over a
freshly loaded patient (DFN 101086):

1. **Same-vintage replay is idempotent** — second replay changed zero
   records (TIU/problems/allergies/vitals/meds/immunizations).
2. **Cross-vintage replay DUPLICATES without a guard** — the unified C0FW
   writeback marks entries under capitalized domain keys with a direct
   `loadStatus` node; the legacy `SYNF*` loaders check lowercase keys under
   `"status","loadstatus"`. With only C0FW markers present, replay re-filed
   all vitals (72 → 144).
3. **Fix: `C0FWLD^SYNFHIRU`** — shared guard consulted by every `SYNF*`
   `loadStatus`: a loaded/skipped marker at that entry index under ANY
   domain key means the entry is filed (entry indices are unique
   bundle-wide). With the guard, the same rehearsal held vitals at 135/135,
   meds/immunizations unchanged.

## devfhir replay of HARBER290 (2026-09-13)

- Synced current `C0F*` (fhirdev-codex-sync.sh) + all loader `SYN*`
  routines to fhirdev22; lab prerequisites healthy (794 tests linked to
  accession areas; no C0FZLACC fixes needed).
- Guarded replay: **zero duplication** — TIU 384, problems 25, allergies 6,
  vitals 735, CH labs 2291, visits 385 all unchanged across replays.
- **Found + fixed the meds stall**: after the first successful
  `WRITERXRXN^SYNFMED`, the PSO prescription chain KILLs `args("load")`, so
  every later MedicationRequest logged its rxnorm but silently skipped
  filing (the documented "prescription chain kills common locals" class).
  Fix: namespaced snapshot `SYNMLOAD` in `wsIntakeMeds^SYNFMED2`.
  Result: **meds 0 → 584 loaded (of 596 MedicationRequests, 12 errors)**.
- Replays must run with user context (`D ENVINIT^C0FHIR` in direct M
  sessions); without it labs error out and meds crash at `XPAR1` on
  `DUZ(2)`.

## Result and remaining gaps (devfhir HARBER290)

Dashboard tally after the guarded replay:
`meds:584/596` (was Medication 0/812 — 585 records in ^PS(55)); no other
domain changed a single record (vitals 735, TIU 384, visits 385, CH labs
2291 — all identical before/after). Note the dashboard now shows BOTH
marker families (old capitalized `Medication:0/812` plus new lowercase
`meds:584/596`) — dual bookkeeping, not duplication.

Remaining, each a distinct failure class (next work package):

1. **Procedures 0/737 + CarePlan 0/10** — `-1^Visit not found`: the legacy
   loaders resolve visits through lowercase encounter markers the original
   C0FW load never wrote. Needs a visit-linkage bridge (C0FW markers store
   `visitIen` per entry — map them across).
2. **Labs 0/1669 (+316 panels)** — three subclasses: `Invalid ENTERED_BY
   (#200,.01)` (replay ran as DUZ=.5; needs a real provider context),
   `value is null`, and LOINC→#60 gaps (e.g. 32167-9 Clarity of Urine) —
   the known terminology backlog.
3. **Conditions 31/160 + Immunization 3/13** — importers returned blank
   status; not yet diagnosed.

## CPRS-demo resource counts: gateway continuation truncation (2026-09-13)

The rehmp CPRS demo header shows "N resources" = entries in the merged
patient bundle fetched via the C0RG envelope gateway
(`patient.fhir.bundle` + `bundle.continue` until the continuation token
runs out). Replicating that walk on all four lanes:

| Server | Total | Slices | Observation | DiagnosticReport | MedicationRequest |
|---|---|---|---|---|---|
| irisfhir | 4598 | 92 | 3981 | 317 | 17 |
| rpmsfhir | 639 | 13 | 100 | 317 | 0 |
| fhirprod | 332 | 7 | 53 | 1 | 50 |
| devfhir | 317 | 7 | 100 | 1 | **0** |

Two distinct causes:

1. **irisfhir's 4598 is the true patient**: ~93% is the lab corpus (3981
   Observations + 317 lab DiagnosticReports). It is the only lane where the
   labs are fully filed AND the gateway pages to exhaustion (92 slices).
2. **The other three lanes truncate the continuation walk** (7–13 slices,
   Observations cut at ~50–100), on top of the real data gaps above. Proof
   it's truncation, not just missing data: devfhir has 584 filed
   MedicationRequests (direct `/fhir/MedicationRequest?patient=101122`
   returns them) yet its demo bundle contains **zero** — the walk ends
   before reaching the meds domain. fhirprod returns 1 DiagnosticReport
   where rpmsfhir returns all 317 → gateway-vintage differences, not DB
   content.

Rerunnable: POST `{"apiVersion":"1.0","requestId":"<36+ chars>",` 
`"operation":"patient.fhir.bundle","payload":{"dfn":"<dfn>",`
`"fhirQuery":{"domain":"","max":"100"}}}` to `https://<host>/rehmp`, then
follow `meta.continuationToken` with `bundle.continue`; count
`data.entry` per resourceType.

### Root cause (chased 2026-09-13, ~01:00)

The continuation machinery is innocent: `bundle.continue` (C0RGBNC) pages
faithfully over a bundle that `patient.fhir.bundle` already built and
persisted in `^XTMP("C0RGCONT")`. The count differences come from what the
**builder** (`GETBNDLA^C0FHIR`) put in the bundle, via three stacked causes:

1. **Stale read-through cache.** `GETBNDLA` serves from `GET^C0FWCAC`
   (cached per patient in the intake graph, keyed by request signature)
   unless `refresh=1`. Only the C0FW writeback path calls the invalidator
   (`INV^C0FWCAC`); the legacy `SYNF*` replay path does NOT. So devfhir kept
   serving a bundle cached before the 2026-09-13 meds replay: 0
   MedicationRequests, 1 DiagnosticReport. A `refresh=1` fetch rebuilt it:
   **317 → 634** (MedicationRequest 0 → 50, DiagnosticReport 1 → 317).
   → Action item: the replay path should call `INV^C0FWCAC` when done.
   fhirprod's 332 (DiagnosticReport 1, Observation 53) is the same staleness
   — its cache predates the panel-merge code; refresh deferred to the
   reviewed daytime flow (never experiment on fhirprod).
2. **Per-domain MAX caps.** The rehmp gateway clamps the client `max` to
   `CHUNKSIZE^C0RGPAR`; each domain getter (`GETCOND`, `GETOBS`, `GETMED`…)
   stops at MAX. That's the ~50-per-domain shape on every lane.
3. **Graph-labs mode decides whether panel members balloon the bundle.**
   `ON^C0FHIRLG` = `^C0FHIR("EXPERIMENT","GRAPHLABS")` flag, else ISRPMS.
   - **Graph OFF (irisfhir)**: `GETLAB^C0FHIRL` → `GETGRPNL^C0FHIRLG` →
     `REFFIX`, whose member-emit fallback (the 2026-09-12 browser nesting
     fix, commit 8d80f3d) emits every panel member Observation that doesn't
     match an in-bundle ^LR row — deliberately uncapped ("the graph
     Observation IS the record"). Only ~50 ^LR rows are in the bundle, so
     317 panels × ~12 members → **3981 Observations**. That's the 4598.
   - **Graph ON (devfhir — flag=1 confirmed; rpmsfhir — ISRPMS)**:
     `GETGRPLAB` emits graph Observations capped at MAX and never calls
     REFFIX — no member materialization. Hence devfhir 634 ≈ rpmsfhir 639,
     with panel result[] refs mostly unresolved in-bundle.

So irisfhir shows the full lab corpus because it is the only lane in
graph-OFF mode running the post-nesting-fix code; the others cap. Open
design questions: should graph-ON lanes materialize panel members too (demo
nesting parity), or should the REFFIX fallback respect some ceiling?

Rerunnable: `refresh=1` rebuild via the same envelope POST above; flag
check on devfhir:
`mumps -run %XCMD 'W $G(^C0FHIR("EXPERIMENT","GRAPHLABS"))," ",$$ON^C0FHIRLG()'`
→ `1 1`.

## Rerunnable evidence

- Guard rehearsal: `scripts/ci-roundtrip-local.sh --keep`, install loader
  src, `curl 'http://127.0.0.1:<port>/replayIntake?dfn=<dfn>'` twice;
  compare TIU/AUPNPROB/GMR/LR/PS55/AUPNVIMM counts.
- devfhir replay (direct M, needs context):
  `D ENVINIT^C0FHIR` then
  `N R,A S A("load")=1,A("dfn")=101122 D replayIntakeDomains^SYNFHIR(.R,1399,.A)`
- Tally: `curl -sk https://devfhir.vistaplex.org/fhir-dashboard` (HARBER290 row).

## Log

- 2026-09-12: Findings recorded; starting replay-mechanics review and
  rehearsal.
- 2026-09-13: Guard implemented + rehearsed; devfhir synced; HARBER290
  meds replayed (584/596, zero duplication); remaining gaps classified.
- 2026-09-13 (later): CPRS-demo resource-count divergence explained —
  irisfhir 4598 is the full patient (labs dominate); the other lanes
  truncate the C0RG continuation walk. Investigating the truncation.
- 2026-09-13 (~01:00): Truncation chased to root cause: stale C0FWCAC
  cache (replay path never invalidates; devfhir refresh=1 → 317→634),
  per-domain MAX caps, and graph-labs mode (graph-OFF iris runs the REFFIX
  member-emit fallback uncapped; graph-ON devfhir/rpmsfhir cap at MAX).
