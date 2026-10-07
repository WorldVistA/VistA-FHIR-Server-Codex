# Multi-Repo Workspace Guide

## Purpose

This guide defines how to work across the repositories involved in the
VistA-on-FHIR program. Each repository is independent and deployable on its
own; this document describes how they relate and how to work across the seams.

Last updated: 2026-10-07 (previous: 2026-06-14)

## Repository Roles

All repos live as siblings under `~/work/vista-stack/`. The agent-facing
one-line map is the workspace `CLAUDE.md` (canonical copy in
`Vista-on-FHIR/docs/claude-code/CLAUDE_CODE_ONBOARDING.md`); each repo's own
rules are in its `AGENTS.md`, bridged to Claude Code by a one-line
`CLAUDE.md` (`@AGENTS.md`). Read a repo's `AGENTS.md` before working in it.

### Core server and writeback

| Short name | Local directory | Role |
|---|---|---|
| `FHIR` | `VistA-FHIR-Server-Codex` | VistA→FHIR read server (`C0FHIR*`), unified FHIR writeback framework (`C0FW*`), quality evaluation (`C0FQUAL`), and the fleet ops scripts. The anchor repo. |
| `SOURCE` | `FHIR-source-files` | Source bundles, fixtures, and parity artifacts for FHIR read output. |

### Quality and population

| Short name | Local directory | Role |
|---|---|---|
| `C0X` | `fhir-triple-store` | Population layer: SPARQL / JSON-LD over the fhir-intake graph (`C0X*`), POPIDX, deploy per host (`scripts/deploy-c0x.sh`). |
| `HL7Q` | `HL7-FHIR-quality-testing` | CMS eCQM measures, vendored value sets, DEQM builders, Inferno scorecards, daily quality rotation, trial-matching research. |
| `QMR` | `FHIR-Quality-Measure-Reporting` | End-to-end quality reporting manuals. |
| `USQC` | `us-quality-core-test-kit` | Upstream Inferno US Quality Core kit (reference). |

### Client and gateway

| Short name | Local directory | Role |
|---|---|---|
| `REHMP` | `rehmp` | CPRS-class demo web UI (`ehmp-ui/rehmp-cprs-demo`) + C0RG JSON envelope gateway and the FHIR JSON encoder (`C0RGFENC`, `C0RGZYEN`, C plugin `$&c0rgenc`). **Codex `GETBNDLJ^C0FHIR` depends on `C0RGFENC` at run time.** |
| `CPRS` | `CPRS-on-FHIR` | CPRS-succession specs: CFH-* write contracts and harnesses (`harness/CFH-WRITE-001/harness.py`). |
| `BSTS` | `bsts-vista` | BSTS terminology source for VistA. |
| `CDS` | `cds-hooks-on-fhir` | CDS Hooks / AI Consult / CQL quality-eval sidecar (cds1). Non-MUMPS. |

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
| `TJSON` | `tjson-tooling` / `tjson-tools` / `tjson-FHIR-browser` | TJSON format tooling; FHIR browser WASM vendored into `FHIR/vendor/tjson/`; public static browser. |
| `DOCS` | `Vista-on-FHIR` | Cross-repo documentation, PDF reports, sprint records, Claude Code onboarding, **nightly correctness lane** (`scripts/nightly-correctness-lane.sh`). |
| `COLLAB` | `collaboration` | WorldVistA shared docs incl. the Cursor + Claude Code tooling report and adoption log. |
| `CLAIMS` | `AI-FHIR-CLAIMS` | Strategy and talks for the FHIR AI coding workbench. |
| `CPRS-SRC` | `CPRS-source` | Scrubbed CPRS Pascal source (read-only reference; not a git repo). |

### Platform lanes (one repo per host family)

| Short name | Local directory | Role |
|---|---|---|
| `RPMS` | `rpms-fhir` | IHS RPMS lane: local `rpms-fhir` / `rpms-rebuild-candidate` containers and public `rpmsfhir.vistaplex.org`; publish + smoke scripts. |
| `WVEHR` | `WVEHR-on-FHIR` | WorldVistA EHR 3.0 port notes; `wvehr` is production at `fhir.vistaplex.org` since 2026-09-13. |
| (Codex) | `VistA-FHIR-Server-Codex/scripts/iris-portability-scan.py` | VistA-on-IRIS (`irisfhir`) is a non-blocking fleet lane; portability is scanned nightly. |

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
| Quality measure wrong (IPP/NUMER, label, preset) | `FHIR`, `HL7Q`, `C0X` | Fix `C0FQUAL`/dashboard in `FHIR`; add a machine check to `scripts/smoke-quality-host.sh`; re-run `HL7Q` daily rotation; `deploy-quality-all.sh` |
| Population query / SPARQL | `C0X`, `FHIR` | Extend documented `C0X` entry points; POPIDX reindex (`QUALITY_REINDEX=1`) if code triples changed |
| FHIR JSON encoder (speed, fail-loud, plugin) | `REHMP`, `FHIR` | Change `C0RGFENC`/plugin in `REHMP`; **ship `C0RGFENC.m` + `C0RGZYEN.m` with every Codex sync on every host** (rpmsfhir 500'd without them, 2026-10-04) |
| RPMS-only or VistA-only FileMan field | `FHIR`, `RPMS` | DD-guard in `FHIR` (`$$VFIELD^DILFD`); prove on `rpms-candidate` via `rpms-fhir/docs/TEST_GATE.md` before `rpmsfhir` |
| Host CPRS UI stale (`ui-versions DRIFT`) | `REHMP` | `rehmp/deploy/publish-ui-all.sh` — Caddy serves the dist from the host, not the container |

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
3. Run the relevant harness — `CPRS-on-FHIR/harness/CFH-WRITE-001/harness.py`
   for the write contract, `scripts/smoke-quality-host.sh <host>` for
   quality — or `curl` the target endpoint directly.
4. For read output changes: compare resource counts/types against `SOURCE`
   parity evidence for at least one DFN.
5. Before claiming server changes work: `scripts/ci-roundtrip-local.sh`
   (fresh disposable container, Synthea → `/addpatient` → readback → write
   harness). Before touching vendored artifacts: `scripts/check-artifacts.sh`.
6. Record SHAs and result (see Reproducibility Record below).

Fleet deploys go through `scripts/deploy-quality-all.sh` (targets on its
`TARGETS=` line: fhirdev, vehu10, rpms-candidate, rpmsfhir, wvehr,
non-blocking irisfhir). `wvehr` is production — reviewed daytime deploys
only. The nightly lane re-runs the round trip, harness, artifact check,
fleet smoke (no deploy), daily quality rotation, IRIS scan, and agent-doc
convergence; reports in `Vista-on-FHIR/docs/nightly/`.

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
CONTAINER:   vehu10 (or fhirdev22 / rpms-rebuild-candidate / rpms-fhir / wvehr / ci sandbox)
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
  guide incl. listener restart §10 and TaskMan §11). `github.com/glilly/ai-m`
  is an older snapshot; `~/ops` is current.
- `~/ops/nightly-worktrees/` — detached worktrees the nightly lane pushes
  from; `git pull --ff-only` in Codex, Vista-on-FHIR, and HL7 before
  committing.

Keep host-specific details out of this document.
