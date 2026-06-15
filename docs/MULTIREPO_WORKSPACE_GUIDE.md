# Multi-Repo Workspace Guide

## Purpose

This guide defines how to work across the repositories involved in the
VistA-on-FHIR program. Each repository is independent and deployable on its
own; this document describes how they relate and how to work across the seams.

Last updated: 2026-06-14

## Repository Roles

All repos live as siblings under `~/work/vista-stack/`.

### Core server and writeback

| Short name | Local directory | Role |
|---|---|---|
| `FHIR` | `VistA-FHIR-Server-Codex` | VistA→FHIR read server (`C0FHIR*`) and unified FHIR writeback framework (`C0FW*`). The anchor repo. |
| `SOURCE` | `FHIR-source-files` | Source bundles, fixtures, and parity artifacts for FHIR read output. |

### Client and gateway

| Short name | Local directory | Role |
|---|---|---|
| `REHMP` | `rehmp` | C0RG JSON envelope gateway (client↔VistA RPC bridge). M routines in `C0RG` namespace. |
| `CPRS` | `CPRS-on-FHIR` | CPRS-succession web client. CFH-* specs, write harness (`cfh-smoke.sh`), domain analysis. |
| `BSTS` | `bsts-vista` | Browser-side tooling and SMART app scaffolding. |
| `CDS` | `cds-hooks-on-fhir` | CDS Hooks service layer. |

### Domain services

| Short name | Local directory | Role |
|---|---|---|
| `C0FO` | `VistA-ordering-service` | Order management M routines (`C0FO*`), ported and extended from CPRS Pascal. KIDS file is source of truth. |
| `C0T` | `C0T-terminology-gateway` | Terminology gateway and value set services. |
| `REMIND` | `reminders-on-fhir` | Clinical reminders domain. |

### Data pipeline

| Short name | Local directory | Role |
|---|---|---|
| `SYN` | `VistA-FHIR-Data-Loader` | Synthea/FHIR-to-VistA ingest pipeline and load diagnostics. |
| `ISI` | `VistA-DataLoader` | Core VistA data import infrastructure (`ISI DATA IMPORT`). |
| `SYNTHEA` | `synthea` | Synthetic patient / FHIR R4 bundle generator. |

### Tooling and documentation

| Short name | Local directory | Role |
|---|---|---|
| `TJSON` | `tjson-tooling` | TJSON format tooling; FHIR browser WASM vendored into `FHIR/vendor/tjson/`. |
| `DOCS` | `Vista-on-FHIR` | Cross-repo documentation, PDF reports, connectathon planning. |
| `CPRS-SRC` | `CPRS-source` | Scrubbed CPRS Pascal source (read-only reference; not a git repo). |

## Common multi-repo problem patterns

Most work touches one of these seam pairs. State the repos at the start of
your session so the agent loads the right context.

| Problem type | Primary repos | Change order |
|---|---|---|
| FHIR read mapping bug | `FHIR`, `SOURCE` | Fix in `FHIR`; update parity evidence in `SOURCE` |
| FHIR writeback / C0FW | `FHIR` | Self-contained; `SYN`/`ISI` only if ingest is also broken |
| Order management | `C0FO`, `FHIR` | Implement in `C0FO`; wire route in `FHIR` if needed |
| Client↔server contract | `CPRS`, `REHMP`, `FHIR` | Define CFH-* spec first; then implement server side; then client |
| Ingest/load failure | `ISI`, `SYN`, `FHIR` | Fix ingest in order: `ISI` → `SYN` → verify with `FHIR` read |
| Synthea generation change | `SYNTHEA`, `SYN`, `FHIR`, `SOURCE` | Full pipeline; rarely needed |
| Terminology gap | `C0T`, `FHIR` | Fix in `C0T`; update any `FHIR` mapping that references it |

## Practical guidance for 2–3 repo sessions

1. **Name the repos in your first message.** The agent loads context
   per-repo; naming them upfront avoids guesswork.

2. **Workspace profiles matter for Cursor indexing/search, not for agent
   file access.** The agent can read and edit any sibling repo by absolute
   path regardless of which roots are active. Open a broader profile only
   when you need semantic search across a repo's full codebase.

3. **Define the seam contract before touching either side.** For a
   client↔server change, write the CFH-* spec or document the RPC/HTTP
   interface first. This is what separates parallel-safe work from
   integration-order-sensitive work.

4. **Commit each repo independently before crossing the seam.** Do not
   have unstaged changes in repo A while making changes in repo B that
   depend on A's new behavior.

5. **Deploy with `vehu10-fhir-sync.sh` before cross-repo smoke tests.**
   If ordering-service routines also changed, copy those first, then sync
   Codex, then run smokes — the listener must be restarted if it was down.

## Validation gate (before merge)

Required for any change that touches M routines or FHIR output:

1. Run `XINDEX` on every changed M routine.
2. Deploy to `vehu10` via `scripts/vehu10-fhir-sync.sh` (or
   `scripts/local-fhir-container-sync.sh` for the minimal container).
3. Run the relevant `cfh-smoke.sh` harness checks, or `curl` the
   target endpoint directly.
4. For read output changes: compare resource counts/types against `SOURCE`
   parity evidence for at least one DFN.
5. Record SHAs and result (see Reproducibility Record below).

## Reproducibility record

For any significant validation run, capture this tuple (in a commit
message, test log, or doc):

```
FHIR_SHA:    <git sha>
C0FO_SHA:    <git sha, if ordering was involved>
REHMP_SHA:   <git sha, if gateway was involved>
CPRS_SHA:    <git sha, if harness was involved>
SYN_SHA:     <git sha, if ingest was involved>
ISI_SHA:     <git sha, if ingest was involved>
CONTAINER:   vehu10 (or fhir / fhirdev22)
TEST_DFN:    <patient DFN>
DATE:        <ISO date>
RESULT:      pass / partial / fail
NOTES:       <one line>
```

Omit rows not involved. The minimum useful record is `FHIR_SHA` + `TEST_DFN`
+ `DATE` + `RESULT`.

## Local machine companion

Machine-specific paths, ports, and command shortcuts live in `~/ops`:

- `~/ops/docs/WORKSPACE_LOCAL.md` — canonical machine profile (Docker ports,
  SSH keys, container names, vehu10 access patterns).
- `~/ops/agent-context/` — shared agent context (workflow, security, dev
  guide). Also available at `~/ai-m/agent-context/`.

Keep host-specific details out of this document.
