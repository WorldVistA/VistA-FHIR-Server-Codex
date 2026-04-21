#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${TJSON_CACHE_SOURCE:-$ROOT/src/C0FHIRWS.m}"
VENDOR_JS="${TJSON_VENDOR_JS:-$ROOT/vendor/tjson/tjson.js}"

expected="$(bash "$ROOT/scripts/tjson-cache-token.sh")"
actual="$(
python3 - <<'PY' "$SRC"
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]).read_text()
match = re.search(r"tjson\.js\?v=([^'\" ]+)", src)
if not match:
    sys.stderr.write("error: could not find tjson cache token in C0FHIRWS.m\n")
    sys.exit(1)
print(match.group(1))
PY
)"

if [[ "$actual" != "$expected" ]]; then
  echo "error: tjson cache token mismatch in $SRC" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $actual" >&2
  echo "run ./scripts/update-vendored-tjson.sh <npm-version> after updating vendor/tjson." >&2
  exit 1
fi

python3 - <<'PY' "$VENDOR_JS" "$expected"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
expected = sys.argv[2]
text = path.read_text()

bg_tokens = re.findall(r'tjson_bg\.js\?v=([^\'" ]+)', text)
if len(bg_tokens) != 2:
    sys.stderr.write(f"error: expected 2 tjson_bg.js cache tokens in {path}, found {len(bg_tokens)}\n")
    sys.exit(1)
if any(token != expected for token in bg_tokens):
    sys.stderr.write(f"error: tjson_bg.js cache token mismatch in {path}: {bg_tokens!r} vs {expected!r}\n")
    sys.exit(1)

match = re.search(r'tjson_bg\.wasm\.b64\?v=([^\'" ]+)', text)
if not match:
    sys.stderr.write(f"error: missing tjson_bg.wasm.b64 cache token in {path}\n")
    sys.exit(1)
if match.group(1) != expected:
    sys.stderr.write(
        f"error: tjson_bg.wasm.b64 cache token mismatch in {path}: {match.group(1)!r} vs {expected!r}\n"
    )
    sys.exit(1)
PY

echo "==> verified tjson cache token: $actual"
