# C0FHIR interactive browser — TJSON (WASM) integration

This note records the full path from **unpkg** to a **same-origin**, **container-local** TJSON setup for `GET /fhir?view=browser` in **VistA-FHIR-Server-Codex** (`C0FHIRWS.m`), including pitfalls on minimal **`fhir`** vs **VEHU**-style images and **fhirdev22**.

A copy is mirrored under **`~/work/vista-stack/tjson-tooling/docs/`** (repo **`glilly/tjson-tools`**). Treat **this** Codex file as **canonical**; refresh the mirror when it changes.

## Goal

Render selected FHIR resources in the browser using **`@rfanth/tjson`** (Rust / wasm-bindgen) instead of pretty-printed JSON only.

## Steps taken (chronological)

1. **Browser default to TJSON**  
   In `C0FHIRWS.m` → `BROWSER()`, the detail pane defaults to TJSON with a TJSON / JSON toggle; preference stored in `sessionStorage` (`c0fhirBrowserFmt`).

2. **Drop unpkg**  
   Dynamic `import('https://unpkg.com/@rfanth/tjson@…/tjson.js')` fails under strict **CSP** or offline. Switched to **same-origin** loading under the M listener’s static path.

3. **Vendoring (pin 0.5.0)**  
   Under **`vendor/tjson/`**:
   - `tjson_bg.js`, `tjson_bg.wasm`, `tjson.d.ts` from `https://unpkg.com/@rfanth/tjson@0.5.0/`.
   - **`tjson.js`** is a **patched** entry (not the stock npm file): see steps 7–10.
   - Supported refresh path: **`./scripts/update-vendored-tjson.sh <version>`**. It vendors the npm package, regenerates **`.b64`**, and updates the browser cache-bust token in **`src/C0FHIRWS.m`** to the readable vendored version (for example **`0.5.0`**).

4. **Serve via `%W0` `/filesystem/<file>`**  
   Static files must live under the M user’s **`www`** tree (listener-dependent mapping):
   - **Minimal `fhir` (osehra):** `GET /filesystem/foo` → `/home/osehra/www/foo` (flat).
   - **VEHU / vehu10 / fhirdev22 (vehu):** `GET /filesystem/foo` → `/home/vehu/www/filesystem/foo` (nested `filesystem` segment).

5. **Sync scripts**  
   - **`scripts/update-vendored-tjson.sh`**: supported entry point for changing vendored **`@rfanth/tjson`**; rewrites **`vendor/tjson/`**, regenerates **`tjson_bg.wasm.b64`**, writes **`vendor/tjson/VERSION`**, and updates the visible **`tjson.js?v=<version>`** token in **`C0FHIRWS.m`**.
   - **`scripts/regen-tjson-wasm-b64.sh`**: refresh **`tjson_bg.wasm.b64`** from **`tjson_bg.wasm`** with a round-trip verify (run automatically before vendor copy in **`local-fhir-container-sync.sh`** and **`fhirdev-codex-sync.sh`** unless **`TJSON_SKIP_REGEN_B64=1`**).  
   - **`scripts/local-fhir-container-sync.sh`**: `docker cp` `src/*.m` and `vendor/tjson/*` into the container; default **`FHIR_REMOTE_WWW=/home/<user>/www`** for `fhir`.
   - **`scripts/vehu10-fhir-sync.sh`**: exports **`FHIR_REMOTE_WWW=/home/vehu/www/filesystem`**.
   - **`scripts/vehu10_bootstrap.py`**: copies the same vendor set to **`--www-dest`** (default `/home/vehu/www/filesystem`).
   - **`scripts/link-tjson-to-www.sh`**: host-only symlinks for a **native** M install (not Docker).

6. **Wrong MIME for `.wasm` on `/filesystem/`**  
   The static layer may serve **`tjson_bg.wasm`** as **`application/json`**. Browsers reject **ESM `import` of `.wasm`** when the MIME is wrong.

7. **Patched `tjson.js` — fetch + `WebAssembly.compile` / `instantiate`**  
   Upstream **`tjson.js` (0.4+)** uses `import * as wasm from "./tjson_bg.wasm"`, which is fragile behind wrong MIME / gzip. Our patch:
   - Imports `./tjson_bg.js`.
   - Loads bytes from **`tjson_bg.wasm.b64`** (text), **`atob` → `compile` / `instantiate`**.
   - Calls **`__wbg_set_wasm`** and **`__wbindgen_start`**.
   - Re-exports with **`export * from "./tjson_bg.js"`** (not `export { fromJson, … }`) so a site with an **older** `tjson_bg.js` still parses; the browser uses **`fromJson`** when present and **`stringify(jsonString)`** when not.

8. **Gzip corruption on binary (minimal `fhir`)**  
   With **`Accept-Encoding: gzip`**, the server sometimes produced a **bad uncompressed length** for the wasm body. After gunzip, **`WebAssembly.compile`** failed.

9. **`Accept-Encoding: identity` on `fetch()` does not work**  
   In the Fetch API, **`Accept-Encoding` is a forbidden request header**; browsers ignore script-set values. The gzip issue could not be fixed from JS that way.

10. **Base64 sidecar `tjson_bg.wasm.b64`**  
    - Generate (preferred): `./scripts/regen-tjson-wasm-b64.sh` (encodes and **verifies** decode matches wasm).  
    - Manual: `base64 -w0 vendor/tjson/tjson_bg.wasm > vendor/tjson/tjson_bg.wasm.b64`  
    - Loader fetches **`tjson_bg.wasm.b64`** as **text**, strips whitespace with **`.replace(/\s/g, "")`**, **`atob` → `Uint8Array` → `compile`**.  
    - Sync copies **four** files: `tjson.js`, `tjson_bg.js`, `tjson_bg.wasm`, **`tjson_bg.wasm.b64`**.

11. **`C0FHIRWS.m` — JS API (0.4+ / 0.5.x)**  
    Detail pane uses **`fromJson(JSON.stringify(obj), {})`** so formatting runs on a **JSON string** inside Rust (avoids wasm-bindgen **`stringify(obj)`** paths that can throw **`RuntimeError: memory access out of bounds`** on large or deep FHIR graphs). **`import()`** uses **`tjson.js?v=<version>`** to reduce stale cached JS vs wasm while keeping the live browser token readable. **`update-vendored-tjson.sh`** rewrites this token from **`vendor/tjson/VERSION`**; sync scripts verify it before deploy unless **`TJSON_SKIP_VERIFY_TOKEN=1`**. If **`fromJson`** is missing (very old vendor), the script falls back to **`stringify(obj, {})`**.

12. **`C0FHIRWS.m` error string**  
    On failure, the UI mentions syncing **`vendor/tjson`** including **`.b64`** and redeploying.

## Operational checklist

- [ ] When updating vendored **`@rfanth/tjson`**: run **`./scripts/update-vendored-tjson.sh <version>`**.
- [ ] After changing wasm manually: regenerate **`tjson_bg.wasm.b64`** and verify the visible **`tjson.js?v=<version>`** token matches before deploy.
- [ ] **fhir:** files in **`/home/osehra/www/`** (flat).
- [ ] **vehu10 / fhirdev22:** files in **`/home/vehu/www/filesystem/`**.
- [ ] Run **`D EN^SYNWEBRG`** (or your site’s route registration) after routine updates; restart **`%webreq`** if required.
- [ ] Browser: hard refresh or DevTools “Disable cache” when testing loader changes.

## Repo / script pointers

| Artifact | Location |
|----------|----------|
| Browser HTML/JS (M-embedded) | `src/C0FHIRWS.m` |
| Route registration | `src/SYNWEBRG.m` |
| Vendored TJSON (patched entry) | `vendor/tjson/` |
| Update vendored package + cache token | `scripts/update-vendored-tjson.sh` |
| Regenerate wasm sidecar | `scripts/regen-tjson-wasm-b64.sh` |
| Verify cache token matches vendored assets | `scripts/check-tjson-cache-token.sh` |
| Local Docker sync | `scripts/local-fhir-container-sync.sh`, `vehu10-fhir-sync.sh` |
| Remote **fhirdev22** sync | `scripts/fhirdev-codex-sync.sh` (uses **SSH multiplexing** so many `scp`/`ssh` calls do not trip **MaxStartups** / rate limits; set `FHIRDEV_SSH_NO_MUX=1` to disable) |

## References

- npm package: `@rfanth/tjson` **0.5.0** (see [textjson.com](https://textjson.com/) for format + API examples)
- FHIR browser URL shape: `/fhir?dfn=<dfn>&view=browser` (or as implemented by `WEB^C0FHIRWS`).
