# AI Consult Test Path

## Purpose

The first AI Consult slice lets the FHIR patient dashboard test the
`cds-hooks-on-fhir` Stage 1 server on `cds1.vistaplex.org`.

The flow is intentionally hybrid:

- Codex still owns the patient dashboard and the FHIR Browser.
- The local reHMP FHIR UI gateway performs the outbound HTTPS call to `cds1`.
- C0FW owns VistA filing by converting returned AI Consult `DiagnosticReport`
  resources into visit-linked TIU documents.

This avoids adding M-side outbound HTTPS for the first test while keeping the
medical-record filing behavior inside the VistA stack.

## User Flow

1. Start the current FHIR UI gateway against `vehu10`.
2. Open `http://localhost:5177/fhir`.
3. Pick a patient row and click `AI Consult`.
4. The existing C0FHIR Browser opens with `source=aiconsult`.
5. The browser fetches `/aiconsult?dfn=<dfn>&format=json&file=1`.
6. The gateway calls:
   - Codex `/fhir?dfn=<dfn>` for the patient Bundle;
   - `https://cds1.vistaplex.org/analyze` for advisory reports;
   - Codex `/updatepatient?dfn=<dfn>` to file returned reports.
7. The browser displays a response Bundle containing the Patient, AI Consult
   `DiagnosticReport` resources, and an `OperationOutcome` with filing status.

## Endpoint Contract

Gateway endpoint:

```text
GET /aiconsult?dfn=<dfn>&format=json&file=1
```

Parameters:

- `dfn`: required VistA patient DFN.
- `file`: optional. Defaults to filing enabled. Use `file=0` to call `cds1`
  and return the Bundle without writing TIU documents.
- `format`: accepted for browser readability; JSON is the only current output.

Output:

- FHIR R4 `Bundle.type = collection`.
- Contains one `Patient`.
- Contains zero or more `DiagnosticReport` resources returned from `cds1`.
- Contains one `OperationOutcome` summarizing filing or no-match status.

## Filing Behavior

C0FW routes AI Consult `DiagnosticReport` resources to `C0FWAIC`.

The adapter:

- recognizes reports marked by `AI Consult` metadata or the
  `cds-hooks-on-fhir` case system;
- resolves the patient from `DiagnosticReport.subject`;
- resolves a VistA visit from `DiagnosticReport.encounter`;
- builds TIU text from `DiagnosticReport.conclusion`,
  `DiagnosticReport.conclusionCode`, and `DiagnosticReport.presentedForm`;
- files one visit-linked TIU document per report using the existing
  `MAKE^C0FWTIU` path;
- titles the note with `AI Consult`, for example
  `AI Consult - Essential hypertension advisory review`.

Duplicate protection uses the existing visit-linked TIU snippet check in
`C0FWTIU`. Reopening or refreshing the browser should skip an identical already
filed AI Consult document rather than repeatedly creating new TIU entries.

## Current Limits

- This is not yet tied to `VistA-ordering-service`.
- C0RG is not required for this first test path.
- The first slice files TIU documents from `DiagnosticReport`; it does not yet
  create a VistA consult order.
- Read-back is expected to show the AI Consult content as visit-linked TIU,
  currently represented in FHIR as `DocumentReference` and Encounter note text.
  Native read-back as `DiagnosticReport` can be added as a follow-up.

## Smoke Tests

Local gateway:

```bash
cd /home/glilly/work/vista-stack/rehmp/ehmp-ui/rehmp-cprs-demo
npm run dev:wsl:links:vehu10
```

Open:

```text
http://localhost:5177/fhir
```

Direct endpoint check:

```bash
curl -sS 'http://127.0.0.1:5177/aiconsult?dfn=<dfn>&file=0'
curl -sS 'http://127.0.0.1:5177/aiconsult?dfn=<dfn>&file=1'
```

After filing, verify read-back:

```bash
curl -sS 'http://127.0.0.1:5177/fhir?dfn=<dfn>'
```

Look for visit-linked `DocumentReference` content with an `AI Consult` title.

