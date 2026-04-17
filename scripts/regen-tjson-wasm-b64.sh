#!/usr/bin/env bash
# Regenerate vendor/tjson/tjson_bg.wasm.b64 from tjson_bg.wasm (same-origin loader
# fetches the sidecar as text; see docs/FHIR_BROWSER_TJSON_CODEX.md).
#
# This does **not** compile Rust/WASM — drop an updated tjson_bg.wasm first (e.g.
# from @rfanth/tjson npm package or tjson-tooling build), then run this script.
#
# Usage: ./scripts/regen-tjson-wasm-b64.sh
# Env:   TJSON_VENDOR=/path/to/dir (default: <repo>/vendor/tjson)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="${TJSON_VENDOR:-$ROOT/vendor/tjson}"
WASM="$V/tjson_bg.wasm"
B64="$V/tjson_bg.wasm.b64"

if [[ ! -f "$WASM" ]]; then
  echo "error: missing wasm: $WASM" >&2
  exit 1
fi

encode_one_line() {
  local wasm="$1" tmp="$2"
  if base64 -w0 "$wasm" >"$tmp" 2>/dev/null; then
    return 0
  fi
  if command -v openssl >/dev/null 2>&1 && openssl base64 -A -in "$wasm" -out "$tmp" 2>/dev/null; then
    return 0
  fi
  # macOS / BSD: no -w0
  if base64 "$wasm" | tr -d '\n\r' >"$tmp"; then
    return 0
  fi
  echo "error: could not base64-encode $wasm (need GNU base64 -w0, openssl base64 -A, or base64+tr)" >&2
  return 1
}

encode_one_line "$WASM" "$B64.part"
mv -f "$B64.part" "$B64"

python3 - <<'PY' "$WASM" "$B64"
import base64, pathlib, sys

wasm_p, b64_p = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
want = wasm_p.read_bytes()
text = b64_p.read_text().replace("\n", "").replace("\r", "").replace(" ", "")
got = base64.standard_b64decode(text)
if got != want:
    sys.stderr.write(
        f"verify failed: decoded {len(got)} bytes != wasm {len(want)} bytes\n"
    )
    sys.exit(1)
print(f"==> regen-tjson-wasm-b64: OK ({len(want)} bytes wasm -> {b64_p.stat().st_size} bytes b64)")
PY
