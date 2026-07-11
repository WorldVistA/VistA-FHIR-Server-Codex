/* @ts-self-types="./tjson.d.ts" */
/* Vendored @rfanth/tjson 0.6.0 (+ this patch). */
/* Patched for %W0 static /filesystem:
   - ESM cannot import .wasm (wrong MIME).
   - fetch(.wasm) gets gzip with wrong ISIZE; browsers ignore fetch(…, { headers: { Accept-Encoding } })
     so we cannot force identity.
   Load wasm bytes from ASCII sidecar tjson_bg.wasm.b64 (atob → ArrayBuffer). */

import * as bg from "./tjson_bg.js?v=0.6.0";

function wasmBytesFromBase64Text(t) {
  const s = String(t || "").replace(/\s/g, "");
  const bin = atob(s);
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return u8.buffer;
}

const b64url = new URL("tjson_bg.wasm.b64?v=0.6.0", import.meta.url);
const b64res = await fetch(b64url);
const b64text = await b64res.text();
const ctype = (b64res.headers.get("content-type") || "").toLowerCase();
const trimmed = b64text.trimStart();
if (!b64res.ok) {
  throw new Error("tjson_bg.wasm.b64 HTTP " + b64res.status + " from " + b64url.pathname);
}
if (ctype.includes("text/html") || trimmed.startsWith("<")) {
  throw new Error(
    "tjson_bg.wasm.b64 served as HTML (SPA fallback or missing file) from " +
      b64url.pathname +
      "; sync vendor/tjson into M www and ensure /filesystem/* is not rewritten"
  );
}
const buf = wasmBytesFromBase64Text(b64text);
const wasmMod = await WebAssembly.compile(buf);
const importDesc = WebAssembly.Module.imports(wasmMod);
const imports = {};
for (const { module, name } of importDesc) {
  if (!imports[module]) imports[module] = {};
  const fn = bg[name];
  if (typeof fn !== "function") {
    throw new Error("tjson wasm import missing: " + module + " :: " + name);
  }
  imports[module][name] = fn;
}
const instance = await WebAssembly.instantiate(wasmMod, imports);
bg.__wbg_set_wasm(instance.exports);
instance.exports.__wbindgen_start();

// Re-export whatever tjson_bg.js provides (0.4+; 0.5+ adds toJson). Do not use
// `export { fromJson, ... }` — that is a parse-time error if an old tjson_bg.js is deployed.
export * from "./tjson_bg.js?v=0.6.0";
