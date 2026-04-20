# FHIR browser: `DocumentReference` text attachment decoding

This note records the follow-up request and implementation for the interactive
FHIR browser when it is used against stored Synthea source bundles from
`/showfhir`.

## Request

After the Synthea browser-view change, the next request was:

- recognize `DocumentReference` resources whose attachment MIME is plain text
- base64-decode the attachment body before sending the JSON to TJSON
- keep the change specific to browser rendering rather than rewriting the
  stored FHIR payload

The motivating payload shape is:

```json
{
  "resourceType": "DocumentReference",
  "content": [
    {
      "attachment": {
        "contentType": "text/plain; charset=utf-8",
        "data": "CjIwMjEtMTEtMDIKCiMgQ2hpZWYgQ29tcGxhaW50..."
      }
    }
  ]
}
```

The same logic also accepts the variant MIME token `plain/text`.

## Why this was needed

The light-theme Synthea browser view already made `/showfhir` data easier to
inspect, but `DocumentReference.content[].attachment.data` still appeared as a
long base64 string in TJSON. For clinical-note style attachments, that made the
browser much less useful than it could be.

The goal was to let the browser show the decoded note text in TJSON while
leaving raw JSON mode unchanged so operators can still inspect the original FHIR
representation.

## Implementation

The change is in `src/C0FHIRWS.m`, inside the browser page's embedded
JavaScript.

Added helper functions:

- `isPlainTextMime(ct)` checks for `text/plain...` and `plain/text...`
- `decodeBase64Utf8(b64)` decodes base64 with `atob()` and then converts bytes
  to UTF-8 text with `TextDecoder`
- `prepareForTjson(obj)` performs a display-only transform for matching
  `DocumentReference` resources before TJSON rendering

Behavior:

1. If the selected resource is not a `DocumentReference`, the browser leaves it
   untouched.
2. If it is a `DocumentReference`, each `content[].attachment` is checked.
3. When an attachment has a plain-text MIME and a populated `data` field, the
   browser decodes the base64 payload to UTF-8 text.
4. The decoded text replaces `attachment.data` only in the temporary object
   sent to TJSON.
5. JSON mode still shows the original resource object, including the original
   base64.

In other words: this is a browser-display transform, not a server-side change
to stored or returned FHIR data.

## Live data confirmation

Before finalizing the change, the stored Synthea source bundles on
`devfhir.vistaplex.org` were probed directly.

Observed:

- `https://devfhir.vistaplex.org/showfhir?ien=10` contained multiple matching
  `DocumentReference` resources with `text/plain; charset=utf-8`
- the generated `/fhir?dfn=101085` bundle did not contain matching
  `DocumentReference` resources

That confirmed the decode path matters specifically for the stored Synthea
source browser view and does not alter the normal generated-FHIR browser path.

Example matching live resource during validation:

- resource id: `83885ceb-e418-8dc4-79fe-a957f9e870e1`
- MIME: `text/plain; charset=utf-8`
- base64 prefix: `CjIwMTMtMDgtMjgKCiMgQ2hpZWYgQ29tcGxhaW50...`

## Validation performed

Local validation:

- `./scripts/local-fhir-container-sync.sh`
- `QUICK^XINDX6("C0FHIRWS")` inside the local `fhir` container
- `python3 scripts/fhir_regression_smoke.py --base-url http://127.0.0.1:9081`

Remote validation on `devfhir.vistaplex.org`:

- `./scripts/fhirdev-codex-sync.sh`
- `QUICK^XINDX6("C0FHIRWS")` inside `fhirdev22`
- `python3 scripts/fhir_regression_smoke.py --base-url https://devfhir.vistaplex.org`

Smoke coverage was extended in `scripts/fhir_regression_smoke.py` so the
Synthea browser path now checks for the presence of:

- the `prepareForTjson` hook
- `DocumentReference` detection
- the base64 decode helper
- plain-text MIME recognition

Observed validation result:

- local browser smoke passed
- public `devfhir` browser smoke passed
- `XINDEX` showed only the existing `C0FHIRWS` size warning

## Result

When the browser opens a stored Synthea `DocumentReference` that carries note
text in a base64 plain-text attachment, TJSON now shows the decoded text instead
of the encoded blob.

This keeps the browser useful for note inspection while preserving the original
FHIR payload in raw JSON mode.
