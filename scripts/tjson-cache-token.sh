#!/usr/bin/env bash
# Print the cache-bust token for vendored tjson: version plus a short content
# hash of web/index.js, so any change to the entry file (including import
# rewrites) forces browsers to refetch it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="${TJSON_VENDOR:-$ROOT/vendor/tjson}"
if [[ -f "$V/VERSION" && -f "$V/web/index.js" ]]; then
  ver="$(tr -d '[:space:]' <"$V/VERSION")"
  hash="$(md5sum "$V/web/index.js" | cut -c1-8)"
  echo "$ver-$hash"
  exit 0
fi
echo "error: missing $V/VERSION or $V/web/index.js" >&2
exit 1
