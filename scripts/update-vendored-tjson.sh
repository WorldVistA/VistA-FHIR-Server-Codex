#!/usr/bin/env bash
# Vendor @rfanth/tjson web/ entry (inlined wasm) into vendor/tjson/web/.
# Usage: ./scripts/update-vendored-tjson.sh 0.6.5
#        ./scripts/update-vendored-tjson.sh @rfanth/tjson@0.6.5
set -euo pipefail

usage() {
  echo "usage: $0 <npm-version-or-spec>" >&2
  echo "example: $0 0.6.5" >&2
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
[[ -f "$PKG/web/index.js" && -f "$PKG/web/tjson.js" ]] || {
  echo "error: $SPEC tarball missing web/index.js or web/tjson.js (need >= 0.6.5)" >&2
  exit 1
}
[[ -d "$PKG/web/snippets" ]] || {
  echo "error: $SPEC tarball missing web/snippets/" >&2
  exit 1
}

VERSION="$(
python3 - <<'PY' "$PKG/package.json"
import json, pathlib, sys
print(json.loads(pathlib.Path(sys.argv[1]).read_text())["version"])
PY
)"

echo "==> vendor @rfanth/tjson $VERSION web/ into $V/web"
rm -rf "$V/web"
mkdir -p "$V/web"
# JS + types + snippets only (wasm is inlined in index.js)
cp "$PKG/web/index.js" "$V/web/index.js"
cp "$PKG/web/tjson.js" "$V/web/tjson.js"
[[ -f "$PKG/web/index.d.ts" ]] && cp "$PKG/web/index.d.ts" "$V/web/index.d.ts"
[[ -f "$PKG/web/tjson.d.ts" ]] && cp "$PKG/web/tjson.d.ts" "$V/web/tjson.d.ts"
cp -a "$PKG/web/snippets" "$V/web/snippets"

# Drop legacy patched loader / binary sidecar if present
rm -f "$V/tjson.js" "$V/tjson_bg.js" "$V/tjson_bg.wasm" "$V/tjson_bg.wasm.b64" "$V/tjson.d.ts"

printf '%s\n' "$VERSION" >"$V/VERSION"
cat >"$V/README.md" <<EOF
# Vendored @rfanth/tjson $VERSION

Browser entry: **\`web/index.js\`** (\`@rfanth/tjson/web\`) — wasm inlined as
base64; top-level await initializes on import. Also needs sibling
\`web/tjson.js\` and \`web/snippets/\`.

Served at \`/filesystem/tjson/web/index.js\` (sync copies \`vendor/tjson/web\`
→ M user \`www/.../tjson/web\`).

Refresh: \`./scripts/update-vendored-tjson.sh $VERSION\`
EOF

TOKEN="$(bash "$ROOT/scripts/tjson-cache-token.sh")"
echo "==> update C0FHIRWS cache token to $TOKEN"
python3 - <<'PY' "$ROOT/src/C0FHIRWS.m" "$TOKEN"
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
token = sys.argv[2]
text = path.read_text()
# Prefer web entry; accept legacy tjson.js?v= during transition
text2, n = re.subn(
    r"(/filesystem/(?:tjson/web/index|tjson)\.js\?v=)[^'\" ]+",
    rf"/filesystem/tjson/web/index.js?v={token}",
    text,
    count=1,
)
if n != 1:
    # insert/replace TJSON_PKG line if pattern drifted
    text2, n = re.subn(
        r"const TJSON_PKG=location\.origin\+'/filesystem/[^']+'",
        f"const TJSON_PKG=location.origin+'/filesystem/tjson/web/index.js?v={token}'",
        text,
        count=1,
    )
if n != 1:
    raise SystemExit("error: could not update tjson cache token in src/C0FHIRWS.m")
path.write_text(text2)
PY

bash "$ROOT/scripts/check-tjson-cache-token.sh"

echo "==> vendored tjson web/ updated to $VERSION"
echo "next: deploy with ./scripts/vehu10-fhir-sync.sh or ./scripts/fhirdev-codex-sync.sh"
