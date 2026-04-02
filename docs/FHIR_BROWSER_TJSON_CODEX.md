# C0FHIR interactive browser — TJSON (WASM) integration

This note records the full path from **unpkg** to a **same-origin**, **container-local** TJSON setup for `GET /fhir?view=browser` in **VistA-FHIR-Server-Codex** (`C0FHIRWS.m`), including pitfalls on minimal **`fhir`** vs **VEHU**-style images and **fhirdev22**.

A copy may be mirrored under **`tjson-tools/docs/`** for the automation repo; treat this file as the **canonical** version in Codex.

## Goal

Render selected FHIR resources in the browser using **`@rfanth/tjson`** (Rust / wasm-bindgen) instead of pretty-printed JSON only.

## Steps taken (chronological)

1. **Browser default to TJSON**  
   In `C0FHIRWS.m` → `BROWSER()`, the detail pane defaults to TJSON with a TJSON / JSON toggle; preference stored in `sessionStorage` (`c0fhirBrowserFmt`).

2. **Drop unpkg**  
   Dynamic `import('https://unpkg.com/@rfanth/tjson@0.3.1/tjson.js')` fails under strict **CSP** or offline. Switched to **same-origin** loading under the M listener’s static path.

3. **Vendoring (pin 0.3.1)**  
   Under **`vendor/tjson/`**:
   - `tjson.js`, `tjson_bg.js`, `tjson_bg.wasm` from `https://unpkg.com/@rfanth/tjson@0.3.1/`.

4. **Serve via `%W0` `/filesystem/<file>`**  
   Static files must live under the M user’s **`www`** tree (listener-dependent mapping):
   - **Minimal `fhir` (osehra):** `GET /filesystem/foo` → `/home/osehra/www/foo` (flat).
   - **VEHU / vehu10 / fhirdev22 (vehu):** `GET /filesystem/foo` → `/home/vehu/www/filesystem/foo` (nested `filesystem` segment).

5. **Sync scripts**  
   - **`scripts/local-fhir-container-sync.sh`**: `docker cp` `src/*.m` and `vendor/tjson/*` into the container; default **`FHIR_REMOTE_WWW=/home/<user>/www`** for `fhir`.
   - **`scripts/vehu10-fhir-sync.sh`**: exports **`FHIR_REMOTE_WWW=/home/vehu/www/filesystem`**.
   - **`scripts/vehu10_bootstrap.py`**: copies the same vendor set to **`--www-dest`** (default `/home/vehu/www/filesystem`).
   - **`scripts/link-tjson-to-www.sh`**: host-only symlinks for a **native** M install (not Docker).

6. **Wrong MIME for `.wasm` on `/filesystem/`**  
   The static layer may serve **`tjson_bg.wasm`** as **`application/json`**. Browsers reject **ESM `import` of `.wasm`** when the MIME is wrong.

7. **Patched `tjson.js` — fetch + `WebAssembly.compile` / `instantiate`**  
   Replaced ESM wasm import with glue that:
   - Imports `./tjson_bg.js`.
   - Builds the import object from **`WebAssembly.Module.imports`** and **`instantiate`**s the module.
   - Calls **`__wbg_set_wasm`** and **`__wbindgen_start`**.

8. **Gzip corruption on binary (minimal `fhir`)**  
   With **`Accept-Encoding: gzip`**, the server sometimes produced a **bad uncompressed length** for the wasm body (e.g. declared **359826** vs actual **359825** bytes). After gunzip, **`WebAssembly.compile`** failed (e.g. end-of-module / “custom section” errors).

9. **`Accept-Encoding: identity` on `fetch()` does not work**  
   In the Fetch API, **`Accept-Encoding` is a forbidden request header**; browsers ignore script-set values. The gzip issue could not be fixed from JS that way.

10. **Base64 sidecar `tjson_bg.wasm.b64`**  
    - Generate: `base64 -w0 vendor/tjson/tjson_bg.wasm > vendor/tjson/tjson_bg.wasm.b64`  
    - Loader fetches **`tjson_bg.wasm.b64`** as **text**, strips whitespace with **`.replace(/\s/g, "")`** (handles an extra newline after gzip on ASCII), **`atob` → `Uint8Array` → `compile`**.  
    - Sync copies **four** files: `tjson.js`, `tjson_bg.js`, `tjson_bg.wasm`, **`tjson_bg.wasm.b64`**.

11. **`C0FHIRWS.m` error string**  
    On failure, the UI mentions syncing **`vendor/tjson`** including **`.b64`** and redeploying.

## Operational checklist

- [ ] After changing wasm: regenerate **`tjson_bg.wasm.b64`** and redeploy all four vendor files.
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
| Local Docker sync | `scripts/local-fhir-container-sync.sh`, `vehu10-fhir-sync.sh` |
| Remote **fhirdev22** sync | `scripts/fhirdev-codex-sync.sh` |

## References

- npm package: `@rfanth/tjson` **0.3.1**
- FHIR browser URL shape: `/fhir?dfn=<dfn>&view=browser` (or as implemented by `WEB^C0FHIRWS`).
