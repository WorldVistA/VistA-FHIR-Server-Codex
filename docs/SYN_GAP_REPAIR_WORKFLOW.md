# SYN Gap Repair Workflow

This workflow analyzes existing ingested patients and selectively reruns `SYN` loader categories to fill gaps (for example labs) after loader improvements.

## Why

Older patients may have incomplete load categories (for example `labs`) because they were ingested before newer loader fixes. This process lets you:

- identify category gaps per patient
- rerun only selected categories
- verify what improved and what still needs follow-up

## Prerequisites

- `SYN` routines on test server are current (`VistA-FHIR-Data-Loader/src/SYN*.m` copied to `/home/osehra/p`).
- `ISI` routines on test server are current (`VistA-DataLoader/VistA/Routines/ISI*.m` copied to `/home/osehra/p`).
- SYN initialization has been refreshed at least once after routine updates:
  - `D EN^SYNINIT`

## Tool

Script path:

- `scripts/syn_gap_repair.py`

Default mode is read-only analysis.

## Analyze One Patient

```bash
python3 scripts/syn_gap_repair.py --dfn 29
```

Output columns:

- `source`: count from stored source bundle (`/showfhir` → `wsShow^SYNFHIR`)
- `loaded`: count with `loadstatus="loaded"` in graph load log
- `gap`: `max(source - loaded, 0)`
- `status_summary`: per-category status buckets (`loaded`, `readytoload`, `cannotload`, etc.)

## Rerun Specific Categories

Example: rerun only labs for one patient.

```bash
python3 scripts/syn_gap_repair.py --dfn 29 --repair --category labs
```

Example: rerun multiple categories.

```bash
python3 scripts/syn_gap_repair.py --dfn 29 --repair --category labs,vitals,encounters
```

Example: rerun only categories with positive gap.

```bash
python3 scripts/syn_gap_repair.py --dfn 29 --repair --auto-gap
```

## Analyze / Repair Multiple Patients

```bash
python3 scripts/syn_gap_repair.py --dfn 27,28,29
python3 scripts/syn_gap_repair.py --dfn 27 --dfn 28 --dfn 29 --repair --category labs
```

## Notes On Warnings

- For this maintenance flow, prioritize runtime results and hard failures.
- `XINDEX` warnings in legacy routines are expected and can be reviewed later.

## Interpreting Results

- If `loaded` rises after rerun: gap is being repaired.
- If entries remain `readytoload`: loader attempted prep but downstream filing did not complete; inspect `load` logs for that category/entry.
- If entries are `cannotload`: mapping/terminology/data constraints likely need routine-level remediation.

## Remote fhirdev22 (SSH + Docker)

`syn_gap_repair.py` runs `docker exec` against a **local** container. On **`fhirdev.vistaplex.org`** / **`fhirdev22`**, use:

```bash
# After copying updated SYN* routines and running XINDEX on the container:
./scripts/fhirdev-repair-category.sh --dfn 101086 --category labs
```

Env: `FHIRDEV_SSH` (default `root@fhirdev.vistaplex.org`), `FHIRDEV_CONTAINER` (default `fhirdev22`). Resolves the graph **IEN** as the maximum `^...("DFN",dfn,ien)` under `$$setroot^SYNWD("fhir-intake")`, then merges each category the same way as `syn_gap_repair.py` (but with **`SYNWD`** for ROOT).

## Quick Validation Pattern

1. Run analysis (`--dfn ...`).
2. Run selective repair (`--repair --category ...` or `--auto-gap`).
3. Re-run analysis and confirm `loaded` increased.
4. Inspect unresolved entries in `/global/%25wd(17.040801,3,<IEN>,"load")`.
