# FHIR browser: default TJSON with JSON toggle — feasibility

This note ties together the official **TJSON** / **TextJSON** project ([textjson.com](https://textjson.com/)), the browser-capable npm build, and the **C0FHIR** interactive FHIR browser (`/fhir?view=browser` in `VistA-FHIR-Server-Codex`), so we can decide how to implement “TJSON by default, button back to JSON.”

## Sources reviewed (April 2026)

| Source | URL | Relevance |
|--------|-----|-----------|
| Project site | [https://textjson.com/](https://textjson.com/) | Format description, live demo (JSON ↔ TJSON), install pointers, **updated JS API** (`toJson`, `fromJson`, ESM examples) |
| Rust + WASM reference repo | [https://github.com/rfanth/tjson](https://github.com/rfanth/tjson) | README: **binary, library (including WASM), serde** |
| npm package (browser build) | [https://www.npmjs.com/package/@rfanth/tjson](https://www.npmjs.com/package/@rfanth/tjson) | **ESM + `.wasm`** (~391 KB wasm @ 0.4.x, zero runtime deps); see “Files” on npm |
| Type declarations (unpkg) | `@rfanth/tjson` → `tjson.d.ts` | JS API surface |

### What “runs in the browser” means today

The published **`@rfanth/tjson`** package is **not** a pure-JS parser. It is **Rust compiled to WebAssembly**, loaded from JavaScript:

- `tjson.js` — ESM entry (upstream may use `import` of `.wasm`; we **vendor a patched** loader — see runbook).
- `tjson_bg.wasm` — the engine

The **consumer-facing API** (verified for **`@rfanth/tjson@0.4.3`**) is:

| Export | Role |
|--------|------|
| **`stringify(value, options?)`** | Render a **JavaScript value** (object, array, …) as **TJSON** text. Prefer this when you already hold a parsed object (e.g. FHIR `resource`). |
| **`fromJson(jsonString, options?)`** | Render a **JSON string** as TJSON — same output as parsing then `stringify`, but avoids an extra JS round-trip if you only have a string. |
| **`parse(tjsonString)`** | Parse **TJSON** → **JavaScript value** (not a JSON string). |
| **`toJson(tjsonString)`** | Parse **TJSON** → **JSON string** (for handing off to JSON-only consumers). |

**Breaking change from 0.3.x:** `stringify` used to accept a **JSON string** as the first argument. It now accepts a **live JS value**. For a JSON string, use **`fromJson`**. The FHIR browser (`C0FHIRWS.m` → `BROWSER`) uses **`fromJson(JSON.stringify(resource), {})`** so TJSON generation does not cross the deep **JsValue** bridge (which can **`memory access out of bounds`** on some bundles); it falls back to **`stringify(obj, {})`** only if **`fromJson`** is absent.

**CDN (upstream docs):** e.g. `import { parse, toJson } from "https://esm.sh/@rfanth/tjson"` — we still recommend **vendoring** for production (CSP, offline, supply chain).

So: **yes, there is an official browser-oriented distribution**—**WASM-backed ESM**, not a separate tiny handwritten parser.

## Where our FHIR browser lives today

In **VistA-FHIR-Server-Codex**, the interactive UI is built in M as HTML + inline JS in **`C0FHIRWS.m`**, tag **`BROWSER`**. It:

1. `fetch('/fhir?dfn=' + dfn)` and parses JSON.
2. Renders a resource list and, for the selection, sets detail text with TJSON via **`stringify(obj, {})`** or pretty JSON with `JSON.stringify(obj, null, 2)`.

There is no bundler in the loop—the page is a single generated HTML document.

We already have a **server-side** TJSON HTML view on **`GET /tfhir`** in `C0FHIR.m` (rust **`tjson`** CLI / pipeline—separate from this browser question).

## Can we default the pane to TJSON with a JSON toggle?

**Yes.** The imagined UX is straightforward:

1. **Default view:** show the selected resource as **TJSON** using **`stringify(resource, options)`** (or **`fromJson(JSON.stringify(resource), options)`** if you only have a string).
2. **Toggle:** TJSON / JSON; optional `sessionStorage` (`c0fhirBrowserFmt`).
3. **WASM load:** dynamic `import()` of same-origin **`/filesystem/tjson.js`** (vendored).

### Implementation patterns (pick one)

| Approach | Pros | Cons |
|----------|------|------|
| **A. ESM `import` from npm CDN** (unpkg, esm.sh) | No build step; quick to try | **CSP** / cross-origin wasm; third-party uptime |
| **B. Vendor `tjson.js`, `tjson_bg.js`, `tjson_bg.wasm` (+ `.b64`)** | Same-origin wasm, reproducible deploy | Pin version when upgrading; regenerate **`.b64`** after wasm changes |
| **C. Bundler** | Single file possible | Extra pipeline |

For **WorldVistA / container** images, **B** is usually the most predictable.

### Caveats (plan for these)

1. **Async init:** WASM initializes asynchronously; preload on `boot()` (current code preloads `ensureTjson()`).
2. **Performance:** Large bundles are heavy; TJSON only the **selected `resource`** (current behavior).
3. **`options`:** Pass `{}` for defaults or use **`StringifyOptions`** / **`canonical: true`** etc. (see `tjson.d.ts`).
4. **Security / privacy:** Patient data stays in-browser if conversion runs client-side after fetch from your `/fhir`.
5. **Offline:** Requires vendored wasm (**B**).

## Recommended next steps (Codex + tjson-tooling)

1. **Pin a version** in docs and deploy scripts (currently **`@rfanth/tjson@0.4.3`**).
2. On upgrade: replace **`tjson_bg.js`**, **`tjson_bg.wasm`**, re-patch **`tjson.js`** (b64 loader), regenerate **`tjson_bg.wasm.b64`**, sync **`www`** / **`www/filesystem`**.

## Bottom line

- **Official browser path:** **`@rfanth/tjson`** — **WASM + ESM**, **`stringify` / `fromJson` / `parse` / `toJson`**, zero npm dependencies.
- **FHIR browser:** vendored same-origin loader + **`stringify(obj, {})`** for the detail pane.

## Implementation status

**Shipped** in **`VistA-FHIR-Server-Codex`**: same-origin **`/filesystem/tjson.js`**, vendored **`@rfanth/tjson@0.4.3`** (patched loader + **`tjson_bg.wasm.b64`**).

**Documents (keep in sync in both repos):** this note (**`FHIR_BROWSER_TJSON.md`**) and the operational runbook (**`FHIR_BROWSER_TJSON_CODEX.md`**) live under **`docs/`** in **VistA-FHIR-Server-Codex** and in **tjson-tooling** (`~/work/vista-stack/tjson-tooling`, remote **`glilly/tjson-tools`**). After editing, copy both files to the other repo so they stay identical.

To use: **`/fhir?view=browser&dfn=<dfn>`** (or your site’s equivalent).
