#!/usr/bin/env bash
# Print the cache-bust token for vendored tjson (vendor/tjson/VERSION).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="${TJSON_VENDOR:-$ROOT/vendor/tjson}"
if [[ -f "$V/VERSION" ]]; then
  tr -d '[:space:]' <"$V/VERSION"
  echo
  exit 0
fi
echo "error: missing $V/VERSION" >&2
exit 1
