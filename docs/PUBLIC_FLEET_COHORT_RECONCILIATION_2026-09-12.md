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
