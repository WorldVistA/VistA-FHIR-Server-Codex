#!/usr/bin/env bash
# Verify C0FHIRWS.m TJSON_PKG token matches vendor/tjson/VERSION and web entry exists.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${TJSON_CACHE_SOURCE:-$ROOT/src/C0FHIRWS.m}"
VENDOR_INDEX="${TJSON_VENDOR_JS:-$ROOT/vendor/tjson/web/index.js}"

expected="$(bash "$ROOT/scripts/tjson-cache-token.sh" | tr -d '[:space:]')"
actual="$(
python3 - <<'PY' "$SRC"
import pathlib, re, sys
src = pathlib.Path(sys.argv[1]).read_text()
match = re.search(r"/filesystem/tjson/web/index\.js\?v=([^'\" ]+)", src)
if not match:
    sys.stderr.write("error: could not find /filesystem/tjson/web/index.js?v= token in C0FHIRWS.m\n")
    sys.exit(1)
print(match.group(1))
PY
)"

if [[ "$actual" != "$expected" ]]; then
  echo "error: tjson cache token mismatch in $SRC" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $actual" >&2
  echo "run ./scripts/update-vendored-tjson.sh <npm-version>" >&2
  exit 1
fi

[[ -f "$VENDOR_INDEX" ]] || {
  echo "error: missing vendored web entry: $VENDOR_INDEX" >&2
  exit 1
}
[[ -f "$ROOT/vendor/tjson/web/tjson.js" ]] || {
  echo "error: missing vendor/tjson/web/tjson.js" >&2
  exit 1
}
[[ -d "$ROOT/vendor/tjson/web/snippets" ]] || {
  echo "error: missing vendor/tjson/web/snippets/" >&2
  exit 1
}

echo "==> verified tjson web entry token: $actual"
