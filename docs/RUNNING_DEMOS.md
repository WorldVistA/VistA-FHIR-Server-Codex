# Running Demos

This document is a living runbook for demos that can be shown directly from the repository. Add new sections here as more features become demo-ready.

## rehmp Regression Demo

The current `rehmp` demo is a terminal-friendly regression walkthrough for the new `/rehmp` bridge and its compatibility relationship to `/fhir`.

### What It Demonstrates

- `POST /rehmp` health path
- `POST /rehmp` patient FHIR bundle path
- `POST /rehmp` domain-filtered bundle path using `domain=lab,meds` and `max=25`
- Validation/error paths for bad requests
- Compatibility check that `GET /fhir?dfn=<DFN>` still returns a JSON `Bundle`

This is useful as both:

- a live demo for someone watching the terminal
- a regression test run that leaves behind reviewable artifacts

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

- `[1/7] Health check envelope`
- `[2/7] Bundle request for one patient`
- `[3/7] Domain-filtered bundle request`
- `[4/7] Validation error for missing operation`
- `[5/7] Validation error for bad apiVersion`
- `[6/7] Validation error for missing dfn`
- `[7/7] Compatibility check for GET /fhir`

### What The Underlying Smoke Test Does

The smoke test is `scripts/rehmp-smoke.sh`.

It now:

- accepts `--base-url`
- can keep artifacts with `--artifacts-dir` or `--keep-artifacts`
- prints each HTTP step as it runs
- saves request and response files for every checked path
- verifies expected HTTP status codes
- verifies JSON envelope shape on successful `/rehmp` responses
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
- `bundle-basic.request.json`
- `bundle-basic.response.json`
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
- seven numbered progress steps
- HTTP status for each request
- request/response artifact paths
- a preview of each response body
- `assertions: pass` for each checked step
- a final pointer to the artifact directory

### Current Known Behaviors The Demo Makes Visible

The demo currently highlights two transport-layer behaviors that are still important to show:

- successful `POST /rehmp` calls return HTTP `201`
- error-path `POST /rehmp` calls return HTTP `400`, but the response body is currently `{}` rather than the full application error envelope

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
2. Point out that the test covers both success and failure paths for `/rehmp`.
3. Show that a filtered FHIR bundle request works and keeps the response smaller.
4. Show that `/fhir` still works for the same patient.
5. Call out the current HTTP-layer behavior: `201` on success and `{}` on error responses.
6. Open the saved artifact directory if anyone wants to inspect exact request/response payloads afterward.
