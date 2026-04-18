#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${TJSON_CACHE_SOURCE:-$ROOT/src/C0FHIRWS.m}"

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

echo "==> verified tjson cache token: $actual"
