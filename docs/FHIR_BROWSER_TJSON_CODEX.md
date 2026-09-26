# C0FHIR interactive browser — TJSON (WASM) integration

This note records how **`GET /fhir?view=browser`** loads **`@rfanth/tjson`** in
**VistA-FHIR-Server-Codex** (`C0FHIRWS.m`).

A copy is mirrored under **`~/work/vista-stack/tjson-tooling/docs/`** (repo
**`glilly/tjson-tools`**). Treat **this** Codex file as **canonical**.

## Goal

Render selected FHIR resources with **`@rfanth/tjson`** instead of
pretty-printed JSON only.

## Current approach (0.6.5+ / current **0.10.1**): `@rfanth/tjson/web`

From **0.6.5**, the package ships a zero-setup browser entry under **`web/`**:

| File | Role |
|------|------|
| `web/index.js` | Inlined wasm (base64) + top-level `await init(...)`; re-exports API |
| `web/tjson.js` | Glue / exports (`fromJson`, `stringify`, …) |
| `web/tjson_bg.wasm` | Sibling wasm (0.10+); needed if importing `tjson.js` directly |
| `web/snippets/…/value_transport.js` | Required sibling import |

**No** custom loader, **no** `.wasm` MIME games for the `web/index.js` entry.

### Vendoring

```bash
./scripts/update-vendored-tjson.sh 0.10.1
```

Writes **`vendor/tjson/web/`**, **`vendor/tjson/VERSION`**, and updates
`TJSON_PKG` in **`src/C0FHIRWS.m`** to a cache-busted URL such as:

```text
/filesystem/tjson/web/index.js?v=0.10.1-<token>
```

(Current vendored release: **`@rfanth/tjson` 0.10.1** — post-fuzzer fixes.)
### Serve / sync

Sync copies `vendor/tjson/web` → M user www as **`…/tjson/web/`**:

- **vehu10 / fhirdev22:** `/home/vehu/www/filesystem/tjson/web/`
- **minimal fhir (osehra):** `/home/osehra/www/tjson/web/`

Scripts: `local-fhir-container-sync.sh`, `vehu10-fhir-sync.sh`,
`fhirdev-codex-sync.sh`, `vehu10_bootstrap.py`, `link-tjson-to-www.sh`.

Browser import (embedded in `C0FHIRWS`):

```js
const TJSON_PKG = location.origin + '/filesystem/tjson/web/index.js?v=0.10.1-<token>';
const m = await import(TJSON_PKG);
// m.fromJson(JSON.stringify(obj), {})
```

Nested `/filesystem/tjson/web/...` is served by the M-Web-Server static
handler (verified on vehu10). Prefer that path over `WSASSET^C0FHIRWS`
(single-segment allowlist / `%ZISH` line reads).

### MIME

`.js` must be `text/javascript` or `application/javascript`. Soft-404 HTML
for a module URL fails loudly at `import()` (better than silent wasm
`CompileError`).

## Historical notes (pre-0.6.5)

Before **`web/`**, Codex used a **patched** `tjson.js` that fetched
`tjson_bg.wasm.b64`, `atob`’d it, and `WebAssembly.compile`’d locally — to
avoid wrong `.wasm` MIME and gzip ISIZE bugs. That pipeline also required
**76-column wrapping** of the `.b64` file because `%ZISH` truncated single
huge lines (~256KB), which produced `function body length too big`.

Those files and `scripts/regen-tjson-wasm-b64.sh` are obsolete for the
browser path once **0.6.5+ web/** is deployed. Keep the regen script only if
you still need a binary sidecar for non-web consumers.

## Operational checklist

- [ ] `./scripts/update-vendored-tjson.sh <version>` (≥ 0.6.5)
- [ ] Deploy with `vehu10-fhir-sync.sh` / `fhirdev-codex-sync.sh`
- [ ] Smoke: `GET /filesystem/tjson/web/index.js` returns JS (not HTML)
- [ ] Smoke: `/fhir?dfn=…&view=browser` detail pane renders TJSON
- [ ] Hard-refresh after upgrade (`?v=` token changes with VERSION)

## Repo pointers

| Artifact | Location |
|----------|----------|
| Browser HTML/JS | `src/C0FHIRWS.m` |
| Vendored web entry | `vendor/tjson/web/` |
| Update script | `scripts/update-vendored-tjson.sh` |
| Token check | `scripts/check-tjson-cache-token.sh` |

## References

- npm: `@rfanth/tjson` **0.10.1** (requires **0.6.5+** `web/` entry)
- [textjson.com](https://textjson.com/)
- FHIR browser: `/fhir?dfn=<dfn>&view=browser`
