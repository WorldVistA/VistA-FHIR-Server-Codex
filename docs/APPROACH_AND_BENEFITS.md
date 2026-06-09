# The Way We Build, and Why It Works

Status date: 2026-06-09

`docs/PROJECT_OVERVIEW.md` describes what the system is. This document makes
the case for *how* it is being built — the engineering approach — because the
approach is itself one of the project's main results. eHMP failed with
hundreds of engineers; this stack reached working read/write/UI/AI
demonstrations with a tiny team. The difference is method, not effort.

## 1. In-process M, no middle tier

All server logic runs as VistA-standard M routines inside the same process
space as FileMan. The FHIR server is ~43 routines; the gateway envelope
(`/rehmp`) is a handful more.

**Benefits**

- **No synchronization problem.** There is no replicated data store (the
  failure mode that sank JDS/eHMP). Reads are generated from FileMan at
  request time; writes file through the same APIs CPRS uses (PCE, TIU,
  OE/RR).
- **Radically small operational surface.** One container, one listener
  (`%webreq`). Deployment is copying routine files and re-registering routes.
- **Portability across VistA-class systems.** Anything that runs FileMan +
  Kernel can host the stack — the basis of the RPMS dual-stack plan.

**Cost accepted**: M tooling is spartan (no unit-test framework in the loop
yet); we compensate with smoke harnesses and validation records (see §5).

## 2. FHIR as the single contract, thin envelopes where needed

Every cross-boundary interaction is FHIR R4 or a deliberately thin JSON
envelope (`RequestEnvelope`/`ResponseEnvelope`) over it. Clients never see
FileMan internals; servers never see UI concerns.

**Benefits**

- **Decoupled evolution.** The CPRS demo, reminders builder, ordering UI, and
  AI consult service all consume the same surface; each can be rewritten
  without touching the others.
- **Ecosystem leverage.** Standard FHIR means standard tooling — validators,
  TJSON browsing, Synthea fixtures, external CDS services — works without
  adapters.
- **A real spec lane.** CPRS-on-FHIR's `CFH-*` catalog turns "what would CPRS
  do" into testable contracts before code ossifies in clients.

## 3. Bundle-first, graph-backed intake

Writes arrive as whole bundles; raw JSON is stored in a named graph before
any filing happens, and every resource gets a per-item load result.

**Benefits**

- **Nothing is lost.** Filing failures (missing terminology, lab setup,
  inpatient TIU semantics) are recorded, not fatal; `replayIntake` and the
  gap-repair workflow re-run categories after a fix — which converts loader
  improvement from "reload the world" to targeted replay.
- **Auditability.** The graph row is the source of truth for what was sent;
  the load log is the truth for what was filed. Stage 1/2 evidence for AI
  consults rides on the same mechanism.
- **Additive-only safety.** The writeback contract refuses destructive
  updates by design, which is the right default for clinical data.

## 4. Synthetic data end-to-end

Synthea is kept unforked; all VistA-specific behavior lives downstream. Every
feature is exercised on disposable containers with generated patients.

**Benefits**

- **Zero PHI exposure** in development, demos, and public repos.
- **Reproducibility tuple** (`SYNTHEA_SHA`/`ISI_SHA`/`SYN_SHA`/`FHIR_SHA`/
  `SOURCE_REF` + DFN) makes regressions debuggable months later.
- **Honest demos.** The CPRS demo shows "backend needed" instead of mocking —
  so demo progress is real progress.

## 5. Validation by recorded evidence, not assertion

The required gate (sync to test server → XINDEX → smoke → commit) is written
into `AGENTS.md`. Every significant validation run leaves a dated document
(`CPT_HAPPY_PATH_VALIDATION_*`, `TEST_SERVER_VALIDATION.md`, clinical test
case manifests) — including incident responses when things went wrong.

**Benefits**

- **State is reconstructible.** A new contributor (or agent) can establish
  what works from documents, not tribal memory — this is what made the
  per-repo gap analyses in this documentation set possible.
- **Failures become assets.** The M-webserver leak analyses and the container
  incident responses are reusable operational knowledge, not lost firefights.

## 6. Many small repos with explicit seams

Each concern lives in its own repository with documented ownership
(generation / filing / ingest / serving / UI / specs / terminology /
ordering / reminders / tooling / ops), and `MULTIREPO_WORKSPACE_GUIDE.md`
defines the cross-repo change order and validation gates.

**Benefits**

- **Parallel work without merge wars** — UI, server, and loader development
  proceed independently against the FHIR seam.
- **Honest dependency direction.** Upstream repos (synthea, ISI) stay
  pristine; innovation concentrates where it belongs (SYN, C0FW, C0RG).
- **Right-sized review.** A terminology change never hides inside a UI PR.

**Cost accepted**: a few routines are intentionally mirrored across repos
(C0TS, TJSON docs) and require manual sync — flagged in the gap analyses,
with consolidation steps in `docs/PATH_FORWARD.md`.

## 7. Agent-accelerated development with guardrails

The repos are structured for AI-agent collaboration: `AGENTS.md` working
agreements, behavioral guidelines, runbooks with exact commands, and
machine-checkable smoke scripts. Overnight/marathon runs (CPRS-on-FHIR
synthesis, focused reminder writeback) produced large, reviewed work products.

**Benefits**

- **Throughput.** Spec catalogs, harnesses, and demo UIs that would take a
  team months emerge in days — *because* the contracts, evidence trails, and
  gates above make agent output verifiable.
- **Safety.** The commit gate (deploy → XINDEX → smoke → then commit) applies
  to agents and humans equally; nothing lands on evidence-free assertion.

## The compounding effect

Each choice reinforces the others: in-process M makes deployment trivial,
which makes container-based validation cheap, which makes synthetic
end-to-end testing routine, which makes evidence-based gating practical,
which makes agent acceleration safe, which makes the small team fast enough
to keep the whole surface in FHIR rather than shortcutting around it. The
result is a system whose *development process* is as portable and inspectable
as its runtime — and that is the strongest protection against the rework
spiral that consumed previous VistA modernization attempts.
