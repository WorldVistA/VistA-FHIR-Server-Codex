#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <npm-version-or-spec>" >&2
  echo "example: $0 0.5.0" >&2
  echo "example: $0 @rfanth/tjson@0.5.1" >&2
  exit 1
}

SPEC="${1:-}"
[[ -n "$SPEC" ]] || usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/tjson"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ "$SPEC" != @rfanth/tjson@* ]]; then
  SPEC="@rfanth/tjson@$SPEC"
fi

echo "==> npm pack $SPEC"
pushd "$TMP" >/dev/null
npm pack "$SPEC" >/dev/null
TARBALL="$(ls ./*.tgz)"
tar -xzf "$TARBALL"
popd >/dev/null

PKG="$TMP/package"
for f in package.json tjson_bg.js tjson_bg.wasm tjson.d.ts; do
  [[ -f "$PKG/$f" ]] || {
    echo "error: missing $f in $SPEC tarball" >&2
    exit 1
  }
done

VERSION="$(
python3 - <<'PY' "$PKG/package.json"
import json
import pathlib
import sys

pkg = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(pkg["version"])
PY
)"

echo "==> vendor @rfanth/tjson $VERSION into $V"
cp "$PKG/tjson_bg.js" "$V/tjson_bg.js"
cp "$PKG/tjson_bg.wasm" "$V/tjson_bg.wasm"
cp "$PKG/tjson.d.ts" "$V/tjson.d.ts"
printf '%s\n' "$VERSION" >"$V/VERSION"

python3 - <<'PY' "$V/tjson.js" "$VERSION"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text()
text2, n = re.subn(
    r"(Vendored @rfanth/tjson )[^ ]+( \(\+ this patch\)\.)",
    rf"\g<1>{version}\g<2>",
    text,
    count=1,
)
if n != 1:
    raise SystemExit("error: could not update version comment in vendor/tjson/tjson.js")
text3, n = re.subn(
    r'"\./tjson_bg\.js(?:\?v=[^"]+)?"',
    rf'"./tjson_bg.js?v={version}"',
    text2,
)
if n != 2:
    raise SystemExit("error: could not update tjson_bg.js cache tokens in vendor/tjson/tjson.js")
text4, n = re.subn(
    r'"tjson_bg\.wasm\.b64(?:\?v=[^"]+)?"',
    rf'"tjson_bg.wasm.b64?v={version}"',
    text3,
    count=1,
)
if n != 1:
    raise SystemExit("error: could not update tjson_bg.wasm.b64 cache token in vendor/tjson/tjson.js")
path.write_text(text4)
PY

echo "==> regen wasm sidecar"
bash "$ROOT/scripts/regen-tjson-wasm-b64.sh"

TOKEN="$(bash "$ROOT/scripts/tjson-cache-token.sh")"
echo "==> update C0FHIRWS cache token to $TOKEN"
python3 - <<'PY' "$ROOT/src/C0FHIRWS.m" "$TOKEN"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
token = sys.argv[2]
text = path.read_text()
text2, n = re.subn(r"(tjson\.js\?v=)[^'\" ]+", rf"\g<1>{token}", text, count=1)
if n != 1:
    raise SystemExit("error: could not update tjson cache token in src/C0FHIRWS.m")
path.write_text(text2)
PY

bash "$ROOT/scripts/check-tjson-cache-token.sh"

echo "==> vendored tjson updated to $VERSION"
echo "next: review changes, then deploy with ./scripts/fhirdev-codex-sync.sh or ./scripts/local-fhir-container-sync.sh"
