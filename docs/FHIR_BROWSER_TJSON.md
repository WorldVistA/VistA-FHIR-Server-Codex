# FHIR browser: default TJSON with JSON toggle — feasibility

This note ties together the official **TJSON** / **TextJSON** project, the browser-capable npm build, and the **C0FHIR** interactive FHIR browser (`/fhir?view=browser` in `VistA-FHIR-Server-Codex`), so we can decide how to implement “TJSON by default, button back to JSON.”

## Sources reviewed (April 2026)

| Source | URL | Relevance |
|--------|-----|-----------|
| Project site | [https://textjson.com/](https://textjson.com/) | Format description, live demo (JSON ↔ TJSON), install pointers |
| Rust + WASM reference repo | [https://github.com/rfanth/tjson](https://github.com/rfanth/tjson) | README states library supports **binary, library (including WASM), serde** |
| npm package (browser build) | [https://www.npmjs.com/package/@rfanth/tjson](https://www.npmjs.com/package/@rfanth/tjson) | **ESM + `.wasm`** (~351 KB wasm, zero runtime deps); see “Files” on npm |
| Type declarations (unpkg) | `@rfanth/tjson` → `tjson.d.ts` | JS API surface |

### What “runs in the browser” means today

The published **`@rfanth/tjson`** package is **not** a pure-JS parser. It is **Rust compiled to WebAssembly**, loaded from JavaScript:

- `tjson.js` — ESM entry; wires up wasm and re-exports `parse` / `stringify` from `tjson_bg.js`
- `tjson_bg.wasm` — the actual engine

The npm README documents:

```text
wasm-pack build --target bundler
```

The **consumer-facing API** exposed to TypeScript (verified on unpkg for `0.3.1`) is:

- **`parse(input: string): string`** — interpret a **TJSON** string and return a **JSON** string.
- **`stringify(input: string, options: any): string`** — take a **JSON** string and return **TJSON** text. The second argument is the options bag (shape should match whatever the WASM bindings expect—demo presets on the site map to generator options).

The website markets **“WebAssembly-powered, zero dependencies”** for **JavaScript / TypeScript** and lists **browsers** explicitly.

So: **yes, there is an official browser-oriented distribution**—it is **WASM-backed ESM**, not a separate tiny handwritten parser.

## Where our FHIR browser lives today

In **VistA-FHIR-Server-Codex**, the interactive UI is built in M as HTML + inline JS in **`C0FHIRWS.m`**, tag **`BROWSER`**. It:

1. `fetch('/fhir?dfn=' + dfn)` and parses JSON.
2. Renders a resource list and, for the selection, sets detail text with:

   `JSON.stringify((st.pick||{}).resource||{}, null, 2)`

There is no bundler in the loop—the page is a single generated HTML document.

We already have a **server-side** TJSON HTML view on **`GET /tfhir`** in `C0FHIR.m` (rust `tjson` CLI / pipeline—separate from this browser question).

## Can we default the pane to TJSON with a JSON toggle?

**Yes.** The imagined UX is straightforward:

1. **Default view:** after loading the bundle, show the selected resource (or whole bundle, if you prefer) as **TJSON**, using `stringify(JSON.stringify(resource), options)`.
2. **Toggle:** a control (e.g. “JSON” / “TJSON”) that switches `drawDetail()` between pretty JSON and TJSON, optionally persisting choice in `sessionStorage` or `localStorage`.
3. **WASM load:** the first time you need TJSON, **dynamically `import()`** the module from a **pinned version URL** (e.g. `https://unpkg.com/@rfanth/tjson@0.3.1/tjson.js`) or from **static files** you vendor under your own origin (recommended for production—see below).

Nothing in the current browser architecture prevents this: you already have the object in memory; TJSON generation is a **client-side** transform.

### Implementation patterns (pick one)

| Approach | Pros | Cons |
|----------|------|------|
| **A. ESM `import` from npm CDN** (unpkg, jsDelivr) | No build step; quick to try | Needs **HTTPS**; **CSP** may block `wasm-eval` / cross-origin wasm unless relaxed; depends on third-party uptime |
| **B. Vendor `tjson.js`, `tjson_bg.js`, `tjson_bg.wasm` beside the listener** (or nginx in front) | Same-origin wasm, easier CSP, reproducible deploy | You must **copy pinned versions** when upgrading (fits **tjson-tooling** / **`glilly/tjson-tools`** automation story) |
| **C. Small bundler step** that outputs one script the browser loads | Single file possible | Extra build pipeline—not required if A or B is acceptable |

For **WorldVistA / container** images, **B** is usually the most predictable: mirror the three files into something like `/opt/c0fhir/vendor/tjson/` and serve with correct `Content-Type` for `.wasm` (`application/wasm`).

### Caveats (plan for these)

1. **Async init:** WASM modules initialize asynchronously. The first `stringify` call may need to wait on `import()` (or a one-time `init` promise). The UI should show “Loading formatter…” until ready, or preload on `boot()`.
2. **Performance:** Large `Bundle` JSON strings (full patient) can be heavy to stringify to TJSON on every click; you may TJSON only the **selected `resource`** (current behavior) or debounce.
3. **`options`:** Pass `{}` for defaults or align with site presets once we map names to the WASM option object (may require reading `tjson_bg.js` / Rust `TjsonOptions` for exact keys).
4. **Security / privacy:** Using a CDN leaks **patient JSON** to the CDN only if you **load the library** from there—not if you only load the wasm **from** your site. Loading **code** from CDN is a supply-chain/CSP discussion; data stays local if conversion runs client-side after fetch from your `/fhir`.
5. **Offline / air-gapped:** Requires vendored wasm (**B**).

## Recommended next steps (Codex + tjson-tooling)

1. **Pin a version** in docs and deploy scripts (e.g. `@rfanth/tjson@0.3.1`).
2. **Prototype** in `C0FHIRWS.m` `BROWSER`: add `type="module"` script block OR external `/static/tjson-browser.mjs` that imports vendored `tjson.js`, extends `drawDetail()` with `viewMode: 'tjson'|'json'`, default `'tjson'`.
3. **Add a script in tjson-tooling** (optional) to `curl`/checksum vendor files into `assets/` for container copy—similar spirit to existing `deploy-tjson*.sh` docs.

## Bottom line

- **Official browser path:** **`@rfanth/tjson`** on npm — **WASM + ESM**, `stringify` / `parse` on **JSON strings**, zero npm dependencies.
- **Your idea (default TJSON, button for JSON):** **Feasible and a good fit** for the current FHIR browser, with the main engineering choices being **CDN vs vendored wasm** and **async initialization**.

## Implementation status

**Shipped** in **`VistA-FHIR-Server-Codex`**: same-origin **`/filesystem/tjson.js`**, vendored **`@rfanth/tjson@0.3.1`**, patched loader, and **`tjson_bg.wasm.b64`** to survive bad gzip / MIME on static file paths.

**Documents (keep in sync in both repos):** this note (**`FHIR_BROWSER_TJSON.md`**) and the operational runbook (**`FHIR_BROWSER_TJSON_CODEX.md`**) live under **`docs/`** in **VistA-FHIR-Server-Codex** and in **tjson-tooling** (`~/work/vista-stack/tjson-tooling`, remote **`glilly/tjson-tools`**). After editing, copy both files to the other repo so they stay identical.

To use: **`/fhir?view=browser&dfn=<dfn>`** (or your site’s equivalent).
