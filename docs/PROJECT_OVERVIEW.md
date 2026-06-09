# Project Overview — VistA on FHIR

Status date: 2026-06-09

This document describes the overall project that this repository anchors: what
we are building across the workspace, why it matters, and how the pieces fit
together. Companion documents:

- `docs/APPROACH_AND_BENEFITS.md` — why we build the way we build.
- `docs/DEVELOPMENT_STATUS.md` — state and gap analysis for this repo (each
  sibling repo has its own `DEVELOPMENT_STATUS.md`).
- `docs/PATH_FORWARD.md` — recommended sequencing to minimize rework.

## What we are building

A complete, modern clinical interoperability and user-interface layer for
VistA-class systems (VA VistA, WorldVistA, and IHS RPMS), built **inside** the
M environment rather than alongside it:

1. **A FHIR R4 server in VistA-standard M** (this repo). One multi-domain
   FHIR `Bundle` per request, generated directly from FileMan/VPR data, served
   over the M web listener. No middle-tier servers, no data replication, no
   external cache to keep consistent.
2. **A FHIR write path** (C0FW framework here, plus SYN loader): FHIR bundles
   in, real FileMan filing out — PCE visits, POV diagnoses, health factors,
   TIU notes — with a graph store preserving the source-of-truth JSON and a
   per-resource load log enabling replay and gap repair.
3. **A CPRS-class web client** (`rehmp`): a thin browser UI that reads and
   writes through FHIR and a small JSON envelope gateway (`/rehmp`), replacing
   the abandoned eHMP middle tier with a few M routines.
4. **Clinical services on the same surface**: terminology search and
   SNOMED↔ICD mapping (`bsts-vista`, `C0T-terminology-gateway`), VistA-native
   ordering (`VistA-ordering-service`), clinical reminders writeback
   (`reminders-on-fhir`), and AI-assisted consults (CDS integration filing
   TIU notes with evidence).
5. **A synthetic-data pipeline** (`synthea` → `VistA-DataLoader` →
   `VistA-FHIR-Data-Loader`): the ability to populate any test VistA with
   realistic longitudinal patients and verify round trips mechanically.
6. **A contract workspace** (`CPRS-on-FHIR`): a catalog of CPRS capabilities
   (`CFH-*` specs) mapped to FHIR read/write shapes, with harnesses, so client
   and server evolve against one specification instead of each other.

## Why this system matters

**VistA holds decades of the richest clinical data model in production, but
its user interfaces and integration surfaces are aging out.** CPRS is a
Windows thick client; eHMP (the VA's ~billion-dollar replacement attempt)
collapsed under its middle-tier weight; commercial replacements discard the
clinical logic that makes VistA valuable. This project takes a third path:

- **FHIR as the only contract.** Every consumer — browser UI, AI services,
  loaders, analytics — speaks FHIR R4 (or a thin JSON envelope over it). This
  makes the system legible to the entire modern health-IT ecosystem: SMART
  apps, CDS services, and other EHRs can interoperate without VistA-specific
  knowledge.
- **Reads and writes both.** Most VistA FHIR efforts stop at read-only
  extraction. This stack files real clinical data back — visits, diagnoses,
  notes, health factors, reminder resolutions — which is what makes a usable
  EHR client rather than a viewer.
- **One stack, two platforms.** Because VistA and RPMS share the FileMan/
  Kernel substrate, the same server (behind a capability/profile layer) can
  serve VA-class and IHS-class systems. VPR and SYN have already been
  installed and partially demonstrated on RPMS (`docs/RPMS_DUAL_STACK_READ_WRITEBACK_PLAN.md`).
- **AI-ready by construction.** The AI Consult path (patient bundle → CDS
  service → structured findings → TIU note with graph-seed evidence) shows
  the pattern: because the data surface is FHIR, clinical AI integration is a
  bundle POST, not a bespoke interface project.
- **Synthetic-data discipline.** Synthea-generated patients with mechanical
  load/export parity checks mean every feature can be exercised end-to-end on
  disposable containers with zero PHI risk.

## Architecture at a glance

```
                 generate                load                    read/write
  synthea ───► FHIR bundles ───► VistA-FHIR-Data-Loader (SYN) ──► VistA FileMan
                                   │ (graph store ^%wd, load log)      ▲
                                   └── VistA-DataLoader (ISI) ─────────┘
                                                                        │
                  VistA-FHIR-Server-Codex (M, in-container)             │
                  ├─ GET /fhir            FHIR R4 Bundles  ◄────────────┘
                  ├─ POST /addpatient, /updatepatient   (C0FW writeback)
                  ├─ GET /fhir?view=browser             (TJSON WASM UI)
                  ├─ GET /aiconsult                     (CDS → TIU note)
                  ├─ POST /rehmp                        (JSON envelope gateway)
                  └─ /bsts/*                            (terminology HTTP)
                          ▲                       ▲
            rehmp CPRS demo (browser)    C0T gateway ── bsts-vista / Lexicon
            VistA-ordering-service UI    reminders-on-fhir bundle builder
                          ▲
            CPRS-on-FHIR (specs + harnesses define the contracts)
```

Supporting assets: `FHIR-source-files` (VPR/C0CDA/DDE reference corpus and
parity fixtures), `vista-update-source` (CPRS RPC reference routines),
`tjson-tooling` (TJSON/`%wd` tooling), `~/ops` (deployment playbooks and
container operations).

## Repository roles

| Repo | Role | Status doc |
|---|---|---|
| `VistA-FHIR-Server-Codex` | FHIR server + writeback + browser + bridges | `docs/DEVELOPMENT_STATUS.md` |
| `rehmp` | CPRS-class web client + C0RG gateway | `docs/DEVELOPMENT_STATUS.md` |
| `CPRS-on-FHIR` | Capability catalog, specs, harnesses | `docs/DEVELOPMENT_STATUS.md` |
| `VistA-FHIR-Data-Loader` | FHIR→VistA ingest (SYN) | `docs/DEVELOPMENT_STATUS.md` |
| `VistA-DataLoader` | FileMan filing layer (ISI) | `DEVELOPMENT_STATUS.md` |
| `synthea` | Synthetic patient generation (unforked) | `DEVELOPMENT_STATUS.md` |
| `bsts-vista` | BSTS terminology + C0TS HTTP | `docs/DEVELOPMENT_STATUS.md` |
| `C0T-terminology-gateway` | Normalized terminology gateway | `docs/DEVELOPMENT_STATUS.md` |
| `VistA-ordering-service` | VistA-native ordering (OROS) | `docs/DEVELOPMENT_STATUS.md` |
| `reminders-on-fhir` | Reminder writeback bundles | `docs/DEVELOPMENT_STATUS.md` |
| `tjson-tooling` | TJSON/`%wd` shared tooling | `docs/DEVELOPMENT_STATUS.md` |
| `FHIR-source-files` | Reference corpus / fixtures | `DEVELOPMENT_STATUS.md` |

## What is demonstrably working today

- End-to-end synthetic patient lifecycle: generate in Synthea → POST
  `/addpatient` → file into FileMan → read back as a FHIR Bundle → browse in
  the TJSON browser UI.
- CPRS demo against vehu10 through the port-5177 gateway: patient index,
  chart tabs, diagnosis picker with terminology search and fileability
  metadata, encounter+POV+health-factor+note writeback, AI Consult flow.
- Stage 1 clinical diagnosis test cases with smoke runners.
- Ordering demo (outpatient med renew) through `/rehmp` → OROS.
- Reminder writeback bundle builder with 25 worked examples.
- Terminology search via Lexicon with SNOMED→ICD-10 mapping.
- Deployments on local containers (vehu10, fhir) and remote hosts
  (devfhir.vistaplex.org / fhir.vistaplex.org).

See each repo's `DEVELOPMENT_STATUS.md` for the corresponding gap analysis,
and `docs/PATH_FORWARD.md` for sequencing.
