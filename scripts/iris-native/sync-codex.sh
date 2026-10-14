#!/usr/bin/env bash
# Refresh Codex routines on native iris2. Fleet deploy uses this.
#
# Counterpart of the Codex-import half of web.sh. It does not import SYN,
# C0RG, or the data-loader KIDS build, and it does not rewrite Caddy.
# The web listener is recycled so the long-running job picks up the new
# object code; IRIS keeps the old routine until that job exits.
#
# Usage: scripts/iris-native/sync-codex.sh root@iris2.vistaplex.org
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"
require_session_helper

WEBPORT="${IRIS_WEB_PORT:-9080}"
CODEX_SRC="$(codex_root)/src"
[[ -f "$CODEX_SRC/C0FHIR.m" ]] || { echo "ERROR: Codex src missing at $CODEX_SRC" >&2; exit 1; }

echo "== iris2 codex sync: $HOST =="
tar -czf /tmp/codex-src.tgz -C "$CODEX_SRC" $(cd "$CODEX_SRC" && ls *.m)
scp -q /tmp/codex-src.tgz "$HOST:/tmp/"
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p /opt/iris/import/codex-src /opt/iris/import/codex-mac
rm -f /opt/iris/import/codex-src/*.m /opt/iris/import/codex-mac/*.mac
tar -C /opt/iris/import/codex-src -xzf /tmp/codex-src.tgz
for f in /opt/iris/import/codex-src/*.m; do
  b=$(basename "$f" .m)
  nb=$(echo "$b" | sed 's/^_/%/')
  printf 'ROUTINE %s [Type=MAC]\n' "$nb" | cat - "$f" > "/opt/iris/import/codex-mac/${nb}.mac"
done
chown -R irisusr:irisusr /opt/iris/import/codex-src /opt/iris/import/codex-mac
chmod -R a+rX /opt/iris/import/codex-src /opt/iris/import/codex-mac
echo "codex mac: $(find /opt/iris/import/codex-mac -name '*.mac' | wc -l)"
REMOTE

native_m FOIA <<'M'
ZN "FOIA"
K ERR S SC=$SYSTEM.OBJ.ImportDir("/opt/iris/import/codex-mac","*.mac","ck-d",.ERR,0)
N K,C S (K,C)="" S C=0 F  S K=$O(ERR(K)) Q:K=""  S C=C+1
W "codex import errors: ",C,!
D stop^%webreq
W "listener stopped",!
H
M

sleep 3
native_m FOIA <<'M'
ZN "FOIA"
D job^%webreq(9080)
W "listener jobbed",!
H
M
echo "iris2 codex sync done"
