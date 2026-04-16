# Multi-Repo Workspace Guide

## Purpose

This guide defines how to work across the repositories involved in the VistA FHIR workflow while keeping each repository independent, reproducible, and easy to debug.

## Repository Names and Roles

- `SYNTHEA`: synthetic patient/FHIR generator.
  - https://github.com/synthetichealth/synthea.git
- `ISI`: core VistA data import infrastructure (`ISI DATA IMPORT`).
  - https://github.com/WorldVistA/VistA-DataLoader.git
- `SYN`: Synthea/FHIR-to-VistA ingest pipeline and load diagnostics.
  - https://github.com/WorldVistA/VistA-FHIR-Data-Loader.git
- `FHIR`: VistA-to-FHIR Bundle generation/serving (`C0FHIR*` routines).
  - local repository: `VistA-FHIR-Server-Codex`
- `SOURCE`: source bundles, fixtures, and parity artifacts.
  - local folder/repository: `FHIR-source-files`

## Recommended Local Layout

Keep repos as siblings (not submodules):

`~/work/vista-stack/`
- `synthea/`
- `VistA-DataLoader/`
- `VistA-FHIR-Data-Loader/`
- `VistA-FHIR-Server-Codex/`
- `FHIR-source-files/`

## Local Machine Companion

Store machine-specific paths, ports, and command shortcuts in:

- `FHIR-source-files/WORKSPACE_LOCAL.md`

Keep shared, repository-safe guidance in this document, and keep host-specific details in the local companion. For **Docker VEHU (`vehu10`) shell access, global naming (`^VA` vs `^va`), and sync commands**, see the companion section **“Local VEHU container (`vehu10`) — accessing VistA”** in `FHIR-source-files/WORKSPACE_LOCAL.md`.

## Workspace Profiles (Cursor)

### 1) Core Development (default)

Use for most day-to-day mapping and endpoint work:

- `VistA-FHIR-Server-Codex`
- `FHIR-source-files`

### 2) Ingest Debug

Use when import behavior is in scope:

- `VistA-FHIR-Server-Codex`
- `FHIR-source-files`
- `VistA-FHIR-Data-Loader`
- `VistA-DataLoader`

### 3) Generator Analysis (on demand)

Use only when generation assumptions are changing:

- everything in Ingest Debug
- `synthea`

## Why This Structure

- keeps indexing/search fast.
- reduces accidental edits in upstream repos.
- matches the real dependency chain:
  - `SYNTHEA` -> `ISI`/`SYN` ingest -> `FHIR` output.

## Cross-Repo Change Order

When changes span repositories, use this order:

1. `ISI` (import primitives, if needed)
2. `SYN` (ingest behavior, mappings, load flow)
3. `FHIR` (Bundle generation and endpoint behavior)
4. `SOURCE` (baseline/parity evidence updates)

If a change is FHIR mapping-only, start in `FHIR` and update `SOURCE` evidence as needed.

## Validation Gate (Before Merge)

At minimum:

1. Confirm import/ingest behavior for target patient(s).
2. Run `XINDEX` on changed M routines.
3. Run smoke request(s) for `/fhir?dfn=<DFN>`.
4. Compare source vs output counts/resources for expected domains.
5. Record result and repository SHAs.

## Reproducibility Record (Required)

For each significant validation run, capture:

- `SYNTHEA_SHA`
- `ISI_SHA`
- `SYN_SHA`
- `FHIR_SHA`
- `SOURCE_REF` (commit SHA, file set, or dated snapshot)
- test `DFN`
- date/time
- pass/fail notes

This tuple is the canonical reference for debugging regressions.
