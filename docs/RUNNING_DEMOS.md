# Running Demos

This document is a living runbook for demos that can be shown directly from the repository. Add new sections here as more features become demo-ready.

## rehmp Regression Demo

The current `rehmp` demo is a terminal-friendly regression walkthrough for the new `/rehmp` bridge and its compatibility relationship to `/fhir`.

### What It Demonstrates

- `POST /rehmp` health path
- `POST /rehmp` patient search path using the same RequestEnvelope / ResponseEnvelope contract the browser demo uses
- `POST /rehmp` patient FHIR bundle path
- `POST /rehmp` bundle continuation path when a large real bundle exceeds the configured response size
- `POST /rehmp` domain-filtered bundle path using `domain=lab,meds` and `max=25`
- Validation/error paths for bad requests
- Compatibility check that `GET /fhir?dfn=<DFN>` still returns a JSON `Bundle`

This is useful as both:

- a live demo for someone watching the terminal
- a regression test run that leaves behind reviewable artifacts

For browser-side proof of the same architecture, the companion demos now live in
the `rehmp` repo:

- `ehmp-ui/rehmp-rpc-demo/` — a richer `/rehmp` gateway workspace with a patient
  worklist, selected-context panel, transport/status cards, and exact
  request/response inspectors
- `ehmp-ui/rehmp-fhir-demo/` — a split-pane FHIR shell comparison with a
  persistent side inspector beside the patient narrative

Those browser demos are the current proof that the active Vite + `/rehmp` +
FHIR path can support a more interactive single-screen shell without reviving
ADK, RDK, or `core/rdk`.

### Easiest Command

Run this from the repo root:

```bash
./scripts/demo-rehmp-regression.sh 101075
```

You can also point it at a different base URL:

```bash
./scripts/demo-rehmp-regression.sh --base-url http://127.0.0.1:9085 101075
```

### What The Demo Script Does

The wrapper script:

- creates a dated artifact directory under `tmp/demo-artifacts/`
- prints a simple step-by-step progress view in the terminal
- runs the underlying `rehmp` smoke test
- saves the full terminal transcript to `demo.log`

The progress view looks like this:

- `[1/9] Health check envelope`
- `[2/9] Patient search`
- `[3/9] Bundle request for one patient`
- `[4/9] Bundle continuation when token is returned`
- `[5/9] Domain-filtered bundle request`
- `[6/9] Validation error for missing operation`
- `[7/9] Validation error for bad apiVersion`
- `[8/9] Validation error for missing dfn`
- `[9/9] Compatibility check for GET /fhir`

### What The Underlying Smoke Test Does

The smoke test is `scripts/rehmp-smoke.sh`.

It now:

- accepts `--base-url`
- can keep artifacts with `--artifacts-dir` or `--keep-artifacts`
- prints each HTTP step as it runs
- saves request and response files for every checked path
- verifies expected HTTP status codes
- verifies JSON envelope shape on successful `/rehmp` responses
- verifies that `patient.search` returns `data.patients`
- follows `meta.continuationToken` into a live `bundle.continue` request when the first bundle response is `partial`
- verifies that `/fhir?dfn=<DFN>` returns a FHIR `Bundle`

### Artifacts Produced

Each demo run creates a directory like:

```text
tmp/demo-artifacts/rehmp-YYYYMMDD-HHMMSS-dfn-<DFN>/
```

Expected contents:

- `demo.log`: full terminal transcript from the wrapper run
- `summary.txt`: run metadata such as start time, finish time, base URL, DFN, and exit code
- `results.tsv`: one-line manifest of each request/response pair
- `*.request.json`: the outgoing `/rehmp` JSON requests
- `*.response.json`: the returned `/rehmp` and `/fhir` bodies

Typical files include:

- `health.request.json`
- `health.response.json`
- `patient-search.request.json`
- `patient-search.response.json`
- `bundle-basic.request.json`
- `bundle-basic.response.json`
- `bundle-continue.request.json`
- `bundle-continue.response.json`
- `bundle-domain-filter.request.json`
- `bundle-domain-filter.response.json`
- `missing-operation.request.json`
- `missing-operation.response.json`
- `bad-version.request.json`
- `bad-version.response.json`
- `missing-dfn.request.json`
- `missing-dfn.response.json`
- `fhir.response.json`

### What A Successful Demo Looks Like

On a passing run, the terminal shows:

- the wrapper header with base URL, DFN, run directory, and log path
- nine numbered progress steps
- HTTP status for each request
- request/response artifact paths
- a preview of each response body
- `assertions: pass` for each checked step
- a `skip:` message for the continuation step if the current dataset/configuration never returns a continuation token
- a final pointer to the artifact directory

### Current Known Behaviors The Demo Makes Visible

The demo currently highlights two transport-layer behaviors that are still important to show:

- successful `POST /rehmp` calls may still return HTTP `201`
- some error-path `POST /rehmp` calls may still return HTTP `400` with body `{}` rather than the full application error envelope, depending on the M web listener version

The application-side `/rehmp` behavior underneath that transport is now richer than the original stub phase:

- `patient.search` returns real candidate patients instead of the original stub payload
- `patient.fhir.bundle` uses real in-process `C0FHIR` bundle generation when `GETBNDLA^C0FHIR` is installed
- oversized bundles may return `status: "partial"` with `meta.continuationToken`
- application error codes now include `AUTH`, `FORBIDDEN`, `SIZE`, and `TIMEOUT` in addition to the earlier validation/upstream cases

Those are not demo-script bugs. They are current M web server response-layer behaviors and are documented separately in:

- `docs/M_WEBSERVER_HTTP_RESPONSE_ENHANCEMENTS.md`

### Running The Smoke Test Directly

If you want the assertions without the dated wrapper directory, you can still run the smoke test directly:

```bash
./scripts/rehmp-smoke.sh 101075
```

To keep artifacts from the smoke test itself:

```bash
./scripts/rehmp-smoke.sh --keep-artifacts 101075
```

Or write them to a chosen directory:

```bash
./scripts/rehmp-smoke.sh --artifacts-dir /tmp/rehmp-demo 101075
```

### Suggested Demo Narrative

When showing this live, a simple narration is:

1. Start the wrapper so the audience can see progress one step at a time.
2. Point out that the test covers both search and bundle read paths on `/rehmp`.
3. If the dataset is large enough, show the continuation step and the returned `meta.continuationToken`.
4. Show that a filtered FHIR bundle request works and keeps the response smaller.
5. Show that `/fhir` still works for the same patient.
6. Call out the current HTTP-layer behavior: `201` on success and `{}` on error responses.
7. Open the saved artifact directory if anyone wants to inspect exact request/response payloads afterward.
