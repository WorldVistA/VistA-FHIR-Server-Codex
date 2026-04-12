# M Web Server HTTP Response Enhancements

This note is for the M Web Server maintainer. It records two HTTP response-layer behaviors observed while integrating `POST /rehmp` and turns them into a concrete enhancement request.

The application code already knows how to build the correct JSON body for both success and failure. The remaining problem is that the web-server response layer does not let the handler fully control the final HTTP status/body combination.

## Summary Of The Ask

Requested improvements:

- Let a POST handler return an explicit success status such as `200 OK` without the listener rewriting the response to `201 Created`.
- Preserve the application-generated response body for non-2xx statuses. If the handler already populated `RESULT` and set `HTTPRSP("mime")`, the listener should send that body unchanged instead of collapsing it to `{}` or an empty default body.
- Separate "HTTP status to send" from "should the listener synthesize an error response". The handler should be able to say "send this JSON body with HTTP 400/502/200" without the listener taking over the body.

The first two items are the required behavior changes. The third item is one plausible way to expose that control cleanly.

## Why This Came Up

The new `POST /rehmp` endpoint is an RPC-style JSON API wrapper around `C0RG` and `C0FHIR`.

- The handler builds a JSON `ResponseEnvelope` for both success and failure.
- On failure it maps application error codes like `VALIDATION` and `UPSTREAM` to HTTP status codes.
- The handler needs the transport status to match the envelope, but it also needs the JSON body to survive unchanged so clients can read `requestId`, `error.code`, and `error.message`.

During smoke testing, two response-layer behaviors in the current M Web Server got in the way.

## Observed Behavior

### 1. Successful POST defaults to `201 Created`

For `POST /rehmp`, a normal successful RPC-style call such as `operation="health"` should be allowed to return `200 OK`.

Observed behavior:

- Leaving `HTTPERR=0` caused the listener to send `201`.
- Forcing `HTTPERR=200` caused the listener to fail the request instead of returning a normal `200` response.

That means the handler currently cannot express "successful POST with status 200" even when no resource was created.

### 2. Non-2xx responses lose the JSON body

For validation and upstream failures, the handler built a proper JSON error envelope in `RESULT`, but the final client-visible response body was reduced to `{}` instead of the application-generated payload.

Observed consequence:

- The HTTP code was useful (`400`, `502`, etc.).
- The JSON diagnostics were lost at the transport layer.

This forced the regression script to assert only the status code for error cases and skip envelope-content assertions on those paths.

## Why The Ask Matters

- `POST /rehmp` is RPC-style and does not create a new server resource on success, so `201 Created` is the wrong default for this endpoint class.
- JSON API clients need structured error bodies, not just HTTP status codes. The body carries correlation and diagnosis fields the transport code alone does not convey.
- The current behavior weakens regression coverage because error-path tests cannot assert the real application envelope.
- This is not specific to `C0RG`. Any JSON endpoint that wants precise transport semantics plus an application-defined body would benefit.

## Concrete Requested Behavior

Desired response semantics:

1. A handler can explicitly set `200`, `400`, `502`, or any other intended status for the response, including on `POST`.
2. If the handler has already populated `RESULT`, that body is sent unchanged regardless of whether the status is 2xx, 4xx, or 5xx.
3. The listener only synthesizes a default body when the handler did not provide one.
4. `HTTPRSP("mime")` should continue to govern the content type for both success and error responses when the handler supplied the body.

Possible implementation direction:

- Add a first-class response-status field such as `HTTPRSP("status")` or equivalent, separate from any "error shortcut" behavior.
- Treat `HTTPERR` as transport metadata only, not as a signal to discard or replace an already-built response body.
- Keep the current fallback behavior for legacy handlers that do not populate `RESULT`.

## Minimal Repro Cases

### Repro A: Success should be `200`, not forced `201`

Request:

```bash
curl -i \
  -H 'Content-Type: application/json' \
  --data-binary '{"apiVersion":"1.0","requestId":"rehmp-health-demo","operation":"health","payload":{}}' \
  http://127.0.0.1:9085/rehmp
```

Desired result:

- HTTP status `200`
- JSON body preserved exactly as returned by the application

Observed result during `/rehmp` validation:

- HTTP status `201` when the handler leaves the success path alone

### Repro B: Error body should be preserved on `400`

Request:

```bash
curl -i \
  -H 'Content-Type: application/json' \
  --data-binary '{"apiVersion":"1.0","requestId":"rehmp-missingop-demo","payload":{"dfn":"101075"}}' \
  http://127.0.0.1:9085/rehmp
```

Desired result:

- HTTP status `400`
- JSON body like:

```json
{
  "apiVersion": "1.0",
  "requestId": "rehmp-missingop-demo",
  "status": "error",
  "error": {
    "code": "VALIDATION",
    "message": "Missing operation"
  }
}
```

Observed result during `/rehmp` validation:

- HTTP status `400`
- Response body collapsed to `{}` instead of the application-generated envelope

## Acceptance Criteria For The Web Server

- A JSON handler can return `200` on `POST` without special hacks.
- A JSON handler can return `400`/`502` with a caller-provided JSON body intact.
- The listener does not replace a supplied body merely because the status is non-2xx.
- A regression test can assert both the HTTP status and the full JSON body for success and failure cases.

## Local Code References

Relevant application-side files in this repo:

- `src/C0RGWEB.m`
- `scripts/rehmp-smoke.sh`

Those files are not the root cause. They are the reproducer and the reason this maintainer request is now concrete.

## Relationship To Earlier M Web Server Notes

This request is separate from the earlier worker/socket notes:

- `docs/M_WEBSERVER_RUNAWAY_JOBS_ANALYSIS_2026-03-12.md`
- `docs/M_WEBSERVER_CLOSE_WAIT_FIX_OUTLINE.md`

Those notes describe worker lifecycle and socket cleanup problems. This note is about response semantics at the HTTP layer once the handler has already produced the correct body.
