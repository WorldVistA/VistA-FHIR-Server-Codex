#!/usr/bin/env bash
# **Host-only** (native M listener): symlink vendored @rfanth/tjson (see vendor/tjson; e.g. 0.6.0) into ~/www for %W0:
#   GET http://<host>:<port>/filesystem/tjson.js
#   GET .../filesystem/tjson_bg.js
#   GET .../filesystem/tjson_bg.wasm.b64 (browser loads wasm via atob; avoids gzip on binary)
#
# **Docker (fhir / vehu10):** do not use this — run **scripts/local-fhir-container-sync.sh** or
# **scripts/vehu10-fhir-sync.sh** (or **vehu10_bootstrap.py**) so files live under the
# container's /home/<m-user>/www.
#
# Override target directory: TJSON_WWW=/path/to/www ./scripts/link-tjson-to-www.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/tjson"
W="${TJSON_WWW:-$HOME/www}"

for f in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
  [[ -f "$V/$f" ]] || {
    echo "Missing $V/$f — update with $ROOT/scripts/update-vendored-tjson.sh <version>" >&2
    exit 1
  }
done

mkdir -p "$W"
for f in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
  ln -sfn "$V/$f" "$W/$f"
done

echo "Symlinked $V/* -> $W/ (same-origin /filesystem/tjson.js)"
