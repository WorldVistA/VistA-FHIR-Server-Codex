# ICN generation for FHIR intake patients

This note describes how an **Integration Control Number (ICN)** is assigned when a patient is filed through the **fhir-intake** graph store and `IMPORTPT^ISIIMP03`, and how that behavior was extended for non-UUID bundles and missing Synthea identifiers.

## Goals

- **Synthea bundles**: When the stable Synthea patient UUID is available, derive a **10-digit MPI base (field 991.01)** the same way as before so the same synthetic patient gets the **same numeric base** on every VistA system that runs the same algorithm. The **Kernel** checksum **`$$CHECKDG^MPIFSPC`** is always applied when filing; the **full ICN** stored in indexes and in `Patient` is **`base` + `"V"` + checksum** (as before).
- **Non-Synthea or short `Patient.id`**: Many bundles use a short `id` (for example `"75"`) and keep the real UUID only under `Patient.identifier` with the Synthea GitHub system URL. The old path only ran `pid2icn` on the top-level `pid`, which often **failed** and produced unusable values such as **`-1V…`** after checksum.
- **Supplied ICN**: If the incoming `Patient` already carries an ICN-style identifier, **use that numeric base** (still re-filed with **`CHECKDG^MPIFSPC`** for 991.02 / 991.1).
- **Fallback**: If there is no Synthea UUID and no usable ICN identifier, build a **deterministic pseudo-base** from the **nine-digit SSN** so two sites that import the **same** FHIR patient still get the **same** base.

## Resolution order (`newIcn2^SYNFPAT`)

After a successful `IMPORTPT^ISIIMP03` (new `DFN` on file), `importPatient^SYNFPAT` calls `newIcn2(dfn,pid,ien,ssn)`:

1. **Already filed** — If `$$icn(dfn)` finds 991.01 already set, return that full ICN and refresh the graph **ICN** index if needed.
2. **UUID-shaped `pid`** — `$$pid2icn^SYNFUTL(pid)` (legacy: fifth hyphen segment of a UUID, hex to decimal, first 10 digits).
3. **Synthea identifier on the graph** — Scan `Patient.identifier` for a system containing `synthetichealth` or `synthea` and a UUID-shaped `value`; run `pid2icn` on that string.
4. **FHIR-supplied ICN** — Scan identifiers whose system contains **`ICN`** or VA enterprise OID fragment **`2.16.840.1.113883.4.349`**; accept a **10-digit** value or **`10digits` + `V` + suffix**.
5. **SSN pseudo-base** — `$$ssn2icnBase^SYNFUTL(ssn)` returns **`8`** concatenated with the **nine-digit** SSN (digits only, hyphens stripped). That yields a **10-digit** 991.01-class base that is **stable across systems** for the same SSN. **`CHECKDG^MPIFSPC`** is applied when filing like any other base.
6. **Graph URL fallback** — Retry `pid2icn` on `$$ien2pid^SYNFUTL` (bundle `fullUrl` / `Patient/id` style index).
7. **Last resort** — `newIcn^SYNFPAT` sequential allocator (existing behavior).

## Code locations

| Piece | Routine | Role |
|--------|---------|------|
| Patient import, `newIcn2` call | `SYNFPAT` | After import, assigns ICN and sets graph indexes. |
| UUID → base | `SYNFUTL` → `pid2icn` | Synthea-stable numeric base. |
| SSN → base | `SYNFUTL` → `ssn2icnBase` | `8` + 9-digit SSN. |
| Synthea / FHIR ICN / graph helpers | `SYNFPAT` | `syntheaPidFromGraph`, `fhirIcnNumericBase`, `patientEntryZntry`, `ssnFromPatientGraph`, `applyMpiIcn`. |

`applyMpiIcn^SYNFPAT` centralizes **UPDATE^DIE** on 991.01 / 991.02 / 991.1 and **`^DPT("AFICN")` / `^DPT("ARFICN")`** plus **`setIndex^SYNFUTL`** for the graph.

## GT.M note (`ssnFromPatientGraph`)

GT.M treats some **`FOR`-line `QUIT` forms** as invalid (`QUITARGUSE`). **`ssnFromPatientGraph`** uses **`$ORDER`** over `identifier` nodes and a **`G ssnout`** branch instead of a compound `QUIT` on the `FOR` line.

## Related: `updatepatient` vs `addpatient`

- **`POST /addpatient`** — New graph row, decode bundle, `importPatient^SYNFPAT` (ICN logic above), then domain imports when `load` is enabled.
- **`POST /updatepatient`** — Merge a new bundle **into an existing** graph row, keyed by **`ien=`**, **`dfn=`**, or **`icn=`** / **`id=`**. Does **not** re-run `IMPORTPT`; useful when **`addpatient`** would fail with **duplicate SSN** but you still want to refresh or extend the stored bundle and run loaders. See **`docs/FHIR_INTAKE_CURL_RECIPES.md`** and **`docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md`** for routes and ops context.

## Deploying routine changes

Data-Loader routines (`SYNFPAT`, `SYNFUTL`, `SYNFHIRU`, …) are **not** in the Codex `src/` tree. Copy the updated **`.m`** files into the target container’s routine directory (for example **`fhir`**: `/home/osehra/p`), **`ZLINK`**, and restart the web listener if your site requires it after route or listener changes. Codex **`scripts/local-fhir-container-sync.sh`** only syncs **Codex** `src/*.m` by default.
