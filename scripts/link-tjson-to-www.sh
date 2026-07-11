#!/usr/bin/env bash
# **Host-only** (native M listener): symlink vendored @rfanth/tjson/web into ~/www:
#   GET .../filesystem/tjson/web/index.js
#
# **Docker (fhir / vehu10):** use **scripts/local-fhir-container-sync.sh** or
# **scripts/vehu10-fhir-sync.sh** instead.
#
# Override: TJSON_WWW=/path/to/www ./scripts/link-tjson-to-www.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/tjson/web"
W="${TJSON_WWW:-$HOME/www}/tjson/web"

[[ -f "$V/index.js" && -f "$V/tjson.js" && -d "$V/snippets" ]] || {
  echo "Missing $V — run $ROOT/scripts/update-vendored-tjson.sh <version>" >&2
  exit 1
}

mkdir -p "$W"
rm -rf "$W"
mkdir -p "$(dirname "$W")"
ln -sfn "$V" "$W"

echo "Symlinked $V -> $W (same-origin /filesystem/tjson/web/index.js)"
