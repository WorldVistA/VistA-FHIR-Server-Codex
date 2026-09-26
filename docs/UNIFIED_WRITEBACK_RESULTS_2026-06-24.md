# Unified Writeback And RPMS/VistA Results

Date: 2026-06-24

This records the implementation and validation results for the unified writeback and RPMS/VistA plan. The original plan file was not edited.

## Summary

All plan todos were completed:

- Backend safety fixes for RPMS/VistA replay and readback.
- Paired RPMS and `vehu10` regression smoke tests.
- CPRS writeback intent unification with Encounter-centric and problem-only renderers.
- Problems-tab Add Problem flow using the shared diagnosis pick list.
- C0T/C0RG terminology provider selection with RPMS BSTS detection metadata and VistA Lexicon fallback.
- Notes-tab unified manual/reminder/Health Factor writeback validation on `vehu10` and RPMS.
- Near-term AI Consult custom pick-list mechanism using limited Patient + Condition input.
- External RPMS stopping criteria, snapshot image path, DigitalOcean bring-up notes, and scripted rebuild proof.

## Backend Results

Changed Codex routines:

- `src/C0FWCON.m`
  - Added replay-safe Problem List handling.
  - Existing active problems are reused instead of re-filed.
  - Problem-only `Condition` writeback can file directly to `^AUPNPROB` without requiring an Encounter.
- `src/C0FWVIT.m`
  - RPMS vitals write to `^AUPNVMSR` only.
  - Added duplicate detection for patient, visit/date, measurement type, and value.
- `src/C0FWENC.m`
  - Added RPMS visit structural-node repair for `^AUPNVSIT(VISIT,26)` and `^AUPNVSIT(VISIT,28)`.
  - Tightened RPMS profile behavior.
  - Added native RPMS V Health Factor filing to `^AUPNVHF`, including known-visit replay handling and duplicate checks.
- `src/C0FWPOL.m`
  - Tightened RPMS profile detection so `vehu10` does not incorrectly take RPMS-specific writeback paths.
- `scripts/local-fhir-container-sync.sh`
  - Syncs the core C0T terminology routines needed by C0RG/Codex deployment.

Validation:

- RPMS Health Factor writeback for DFN 4 went from `^AUPNVHF` count `0` to `1`.
- Reposting the same RPMS Notes bundle left `^AUPNVHF` at `1` and returned `Health Factor already filed on visit`.
- `/fhir?dfn=4` returned `200` after replay.
- `C0FWENC` XINDEX produced only pre-existing routine size/style warnings.
- `vehu10` Notes + diagnosis + Health Factor writeback passed using the VistA path.

## CPRS UI Results

Changed CPRS demo files:

- `rehmp/ehmp-ui/rehmp-cprs-demo/writeback/writebackBundle.js`
  - Introduced a shared writeback intent model.
  - Added Encounter-centric and problem-only bundle renderers.
  - Kept existing reminder and Notes builders as compatibility wrappers over the shared model.
- `rehmp/ehmp-ui/rehmp-cprs-demo/app.js`
  - Added Problems-tab Add Problem controls.
  - Reused the shared diagnosis pick list for problem-only writeback.
  - Wired problem-only POST and result display.
  - Updated AI Consult to POST a limited Patient + problem-list Condition bundle.
  - Parses explicit AI Consult pick-list extensions before falling back to `DiagnosticReport.conclusionCode`.
- `rehmp/ehmp-ui/rehmp-cprs-demo/scripts/start-vehu10-fhir-gateway.sh`
  - `/aiconsult` now accepts a POSTed limited Bundle from the CPRS UI.
  - It falls back to fetching `/fhir?dfn=` for older GET callers.

Validation:

- `npm run build` passed for `rehmp-cprs-demo`.
- Notes-tab writeback produced Encounter, note, diagnosis/POV/problem reuse, and Health Factor behavior on both `vehu10` and RPMS.

## AI Consult / CDS Results

Changed Stage 2 CDS files:

- `StructuredBundleFacts.java`
  - Retains submitted `Condition` resources from the limited input Bundle.
- `StructuredReviewService.java`
  - Passes problem-list Conditions to the report factory.
- `StructuredDiagnosticReportFactory.java`
  - Emits explicit `advisory-pick-list` extensions on structured reports.
  - Adds a problem-list pick-list `DiagnosticReport` from submitted Conditions.
  - Keeps existing `conclusionCode` output for backward compatibility.
- `StructuredReviewServiceTest.java`
  - Adds a Patient + Condition-only test for the custom pick-list report.

Validation:

- Stage 2 tests passed with:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace gradle:8.14.2-jdk21 gradle test
```

This implements the near-term mechanism demo: the browser does not send the full patient chart to CDS; it sends Patient + limited problem-list Conditions, and the CDS response returns a `DiagnosticReport` with custom pick-list payloads that flow into the existing CPRS note/writeback path.

## Terminology Results

Changed C0T behavior:

- C0T provider selection now records requested and selected provider metadata.
- `local-bsts` is detected but only selected when the BSTS provider wrapper is installed.
- VistA/`vehu10` retains Lexicon fallback behavior.
- Response metadata reports BSTS availability, provider installation status, Lexicon availability, and fallback reason.

Current limitation:

- Full BSTS normalized provider support still requires a real `C0TBSTS.m` provider wrapper. Until then, RPMS can report BSTS availability but falls back to VistA Lexicon behavior through the normalized C0T/C0RG path.

## External RPMS Results

Added in `rpms-fhir`:

- `docs/EXTERNAL_RPMS_DEPLOYMENT.md`
  - Stopping criteria.
  - Snapshot artifact workflow.
  - DigitalOcean bring-up command sketch.
  - Source rebuild proof and acceptance-record fields.
- `scripts/snapshot-rpms-image.sh`
  - Commits the current proven `rpms-fhir` container to a timestamped Docker image and `latest`.
- `scripts/prove-rpms-rebuild.sh`
  - Re-runs local bootstrap, Codex sync, and endpoint smoke checks from source.

Validation:

- `SMOKE_DFN=4 ./scripts/prove-rpms-rebuild.sh` passed endpoint smoke checks:
  - `/fhir/metadata`
  - `/fhir`
  - `/fhir?dfn=4`
  - `/tiustats?dfn=4`
- The bootstrap step still emits known `_webutils.m` GT.M portability warnings during `zlink`, but the web listener, Codex sync, and smoke checks completed successfully.
- Local snapshot image created:
  - `glilly/rpms-fhir-codex:20260624T194240Z`
  - `glilly/rpms-fhir-codex:latest`
  - image ID `8601dddccd5f`

## Follow-Up Notes

- Commit gating still requires the normal project gate: deploy changed M routines, run XINDEX, run smoke tests, then commit.
- The RPMS snapshot image was created locally but not pushed.
- The external rebuild path still depends on the web-stack bootstrap source; a future improvement is to vendor or package `_web*.m` and `XLFJSON*.m` so external rebuilds do not require `vehu10`.
- Pattern 3 AI Consult server auto-file remains a separate server-side path; the Notes-tab AI Consult path now uses the unified writeback model.
