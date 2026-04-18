#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="${TJSON_VENDOR:-$ROOT/vendor/tjson}"

python3 - <<'PY' "$V"
import pathlib
import re
import sys

vendor = pathlib.Path(sys.argv[1])
path = vendor / "VERSION"
if not path.is_file():
    sys.stderr.write(f"error: missing vendor version file: {path}\n")
    sys.exit(1)

token = path.read_text().strip()
if not token:
    sys.stderr.write(f"error: empty vendor version file: {path}\n")
    sys.exit(1)
if not re.fullmatch(r"[A-Za-z0-9._-]+", token):
    sys.stderr.write(
        f"error: unsupported cache token {token!r}; use only letters, digits, '.', '_' or '-'\n"
    )
    sys.exit(1)

print(token)
PY
