# Path Forward — Sequencing to Minimize Rework

Status date: 2026-06-09

This roadmap synthesizes the gap analyses in every repo's
`DEVELOPMENT_STATUS.md`. It is ordered by **rework risk**: the things that,
left unfixed, will force other repos to be rewritten later. The guiding test
for each item is "what gets cheaper if we do this first?"

## Where rework will come from if we do nothing

1. **The write contract is tripling.** Three clients (rehmp CPRS demo,
   reminders-on-fhir, AI Consult filing) write through
   `/updatepatient?dfn=…&load=1` query conventions, while CPRS-on-FHIR has
   already specified the encounter-note simulation `batch` Bundle as the
   normative first write and `patient.fhir.write` exists only in docs. Every
   week of divergence adds client code that must be migrated later.
2. **Terminology code is mirrored in three repos.** `C0TSWS*`/`C0TSFM`/
   `C0TSUTL` live in bsts-vista, Codex, and C0T; `C0TAPI` is 3/4 stubs and
   `C0TBSTS` doesn't exist. Each mirror edit is a future three-way merge.
3. **VA-specific assumptions are hardening.** Routes are gated implicitly by
   routine presence; CDS endpoints and LOINC maps are hardcoded. The longer
   the RPMS profile layer waits, the more code must be retrofitted.
4. **Validation is manual.** Without automated round-trip and conformance
   checks, every refactor above carries regression risk that slows it down —
   the meta-rework problem.
5. **Writeback UI logic is forked.** `reminderDialog.js`/`writebackBundle.js`
   exist in both rehmp and reminders-on-fhir and will drift.

## Phase 1 — Fix the seams (highest leverage, ~now)

**1a. Standardize the clinical write route.**
- Promote CPRS-on-FHIR `FIRST_CLINICAL_WRITE_TARGET.md` from draft to v1:
  freeze the encounter-note simulation Bundle shape and the response
  contract (per-entry outcomes mirroring the C0FW load log).
- Implement it in Codex as a real route (either `POST /fhir` batch or a
  `patient.fhir.write` C0RG operation — pick one; recommend the C0RG
  operation first since all three clients already speak `/rehmp`, and a pure
  FHIR endpoint can wrap it later).
- Build the **write harness** in CPRS-on-FHIR (post fixture bundle →
  read back → assert) against a disposable container. This is the single
  cheapest anti-drift investment in the workspace.
- Keep `/updatepatient` as a compatibility alias during migration; migrate
  rehmp `writebackBundle.js`, reminders-on-fhir `app.js`, and AI Consult
  filing to the standard route; then deprecate the query-flag convention.

**1b. Consolidate terminology ownership.**
- Declare C0T-terminology-gateway the sole owner of the gateway layer and
  bsts-vista the sole owner of BSTS/C0TS internals; reduce the Codex and C0T
  copies of `C0TSWS*` to synced vendored files with a documented sync
  direction (or a sync script, as done for TJSON docs).
- Implement `C0TBSTS.m` (in-process `SEARCH^BSTSAPI` + subset enumeration)
  so picklists and codesets flow through the same `terminology.search` /
  future `terminology.codesets` contract the CPRS demo already uses.
- Resolve the ICD-mapping ambiguity (return candidates, don't silently pick
  the first association).

**1c. Branch hygiene (cheap, do alongside).** Merge or close:
`vaready-wd-compat` vs `master` (SYN), `fix/patient-state-pointer-file5`
(ISI — then cut a 3.1.x KIDS), `feature/c0ts-format-bsts-integration`
(bsts-vista), and commit or shelve the staged `C0FHIRD.m`/`C0FWAIS.m` work
here. Exclude `output_c0fw*` in the synthea clone.

## Phase 2 — Make correctness mechanical

- **Round-trip CI lane**: scripted container bring-up (or a standing test
  container) running: Synthea bundle → `/addpatient` → `/fhir` readback →
  parity counts; plus the Phase 1 write harness; plus the existing Stage 1
  diagnosis smoke. Even nightly-on-laptop beats manual.
- **FHIR validation in the loop**: run generated bundles through a standard
  R4/US Core validator (answers `OPEN_QUESTIONS.md` #3–4) *before* expanding
  domain mappings — otherwise every mapping added now may need terminology
  rework later (`UNRESOLVED_ISSUES.md` already flags this).
- **Doc-sync checks**: checksum the mirrored TJSON docs and vendored C0TS
  routines in verify scripts.

## Phase 3 — Capability layer, then breadth

- **Profile/capability layer** (`vista` vs `rpms`) per
  `RPMS_DUAL_STACK_READ_WRITEBACK_PLAN.md`: explicit capability checks for
  route registration, site parameters for the CDS URL and other hardcoded
  values. Do this *before* adding many more routes/domains so new code is
  born profile-aware instead of retrofitted.
- **Complete C0FW writeback domains** in client-demand order: labs and
  vitals (needed by reminders bundles), medications, allergies, then
  procedures/care plans/appointments — each landing with a write-harness
  fixture rather than a one-off validation doc.
- **RPMS Phase 0 manifest**: capture the already-demonstrated RPMS read
  baseline in the manifest format the plan defines, so RPMS work resumes
  from evidence.

## Phase 4 — Converge the clients

- Extract the shared writeback bundle-builder module used by both rehmp and
  reminders-on-fhir (post-contract, so it's extracted once, correctly).
- Wire ordering into the CPRS demo Orders tab (read first, renew action
  second) and resolve the OROS preview-commit semantics upstream.
- Begin auth hardening on the `/rehmp` surface (ordering first — it's the
  highest-risk write), per the rehmp Phase 1 roadmap.
- CPRS-on-FHIR: promote the priority specs from draft as each gains a
  passing harness; publish the extension/profile package when shapes
  stabilize.

## Deliberately deferred

- **M webserver CLOSE_WAIT/runaway fixes** — outlined and characterized;
  upstream maintainer work, not on the critical path of any phase above.
- **Synthea upstream rebase** — only when US Core 7 output is wanted.
- **Legacy surface cleanup in rehmp** (`ehmp-ui` Grunt tree, `hmp/`) —
  reference value still exceeds carrying cost; revisit after Phase 4.
- **Full 757-reminder runtime** — stay with curated slices until the write
  contract and C0FW domain coverage justify breadth.

## Why this ordering minimizes rework

Phase 1 freezes the two contracts (write route, terminology operation) that
every client codes against — contracts are where rework multiplies, because
N clients × M divergent conventions all need migration later. Phase 2 makes
the subsequent refactors safe and cheap, instead of each one re-paying a
manual validation tax. Phase 3 widens functionality only after new code can
be born profile-aware and validator-checked, preventing the
"map now, re-map for US Core later" and "retrofit for RPMS later" loops.
Phase 4 converges UIs last, when the seams they sit on have stopped moving.
