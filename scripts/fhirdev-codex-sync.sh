#!/usr/bin/env bash
# Push VistA-FHIR-Server-Codex src/*.m + vendor/tjson/* to remote fhirdev22 (SSH + docker).
# Matches vehu layout: routines /home/vehu/p, static /home/vehu/www/filesystem (GET /filesystem/...).
#
# Defaults: root@fhirdev.vistaplex.org, container fhirdev22, smoke http://fhirdev.vistaplex.org:9080
#
# Env: FHIRDEV_SSH, FHIRDEV_CONTAINER, FHIRDEV_ROUTINE_DIR, FHIRDEV_WWW, VEHU_ENV,
#      FHIRDEV_MUMPS, FHIRDEV_HTTP_BASE
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
V="$ROOT/vendor/tjson"

FHIRDEV_SSH="${FHIRDEV_SSH:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
REMOTE_P="${FHIRDEV_ROUTINE_DIR:-/home/vehu/p}"
REMOTE_WWW="${FHIRDEV_WWW:-/home/vehu/www/filesystem}"
VEHU_ENV="${VEHU_ENV:-/home/vehu/etc/env}"
MUMPS="${FHIRDEV_MUMPS:-/home/vehu/lib/gtm/mumps}"
HTTP_BASE="${FHIRDEV_HTTP_BASE:-http://fhirdev.vistaplex.org:9080}"

SSH=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
SCP=(scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

STAGE="$("${SSH[@]}" "$FHIRDEV_SSH" 'mktemp -d /tmp/codex-sync.XXXXXX')"
echo "==> Remote stage on $FHIRDEV_SSH: $STAGE"

cleanup() {
  "${SSH[@]}" "$FHIRDEV_SSH" "rm -rf '$STAGE'" 2>/dev/null || true
}
trap cleanup EXIT

for f in "$SRC"/*.m; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  "${SCP[@]}" "$f" "$FHIRDEV_SSH:$STAGE/$bn"
  "${SSH[@]}" "$FHIRDEV_SSH" "docker cp '$STAGE/$bn' '$FHIRDEV_CONTAINER:$REMOTE_P/$bn'"
done

for fn in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
  [[ -f "$V/$fn" ]] || {
    echo "error: missing $V/$fn" >&2
    exit 1
  }
  "${SCP[@]}" "$V/$fn" "$FHIRDEV_SSH:$STAGE/$fn"
  "${SSH[@]}" "$FHIRDEV_SSH" "docker exec '$FHIRDEV_CONTAINER' mkdir -p '$REMOTE_WWW'"
  "${SSH[@]}" "$FHIRDEV_SSH" "docker cp '$STAGE/$fn' '$FHIRDEV_CONTAINER:$REMOTE_WWW/$fn'"
done

"${SSH[@]}" "$FHIRDEV_SSH" "docker exec '$FHIRDEV_CONTAINER' chown vehu:vehu $REMOTE_P/*.m 2>/dev/null || true"
"${SSH[@]}" "$FHIRDEV_SSH" "docker exec '$FHIRDEV_CONTAINER' chown vehu:vehu '$REMOTE_WWW/tjson.js' '$REMOTE_WWW/tjson_bg.js' '$REMOTE_WWW/tjson_bg.wasm' '$REMOTE_WWW/tjson_bg.wasm.b64' 2>/dev/null || true"

echo "==> ZLINK + EN^SYNWEBRG + %webreq restart in $FHIRDEV_CONTAINER"
{
  for f in "$SRC"/*.m; do
    [[ -f "$f" ]] || continue
    printf 'zlink "%s"\n' "$(basename "$f" .m)"
  done
  printf '%s\n' 'd EN^SYNWEBRG' 'h'
} | "${SSH[@]}" "$FHIRDEV_SSH" "docker exec -i -u vehu '$FHIRDEV_CONTAINER' bash -lc 'source $VEHU_ENV >/dev/null 2>&1; cd $REMOTE_P && $MUMPS -dir'"

"${SSH[@]}" "$FHIRDEV_SSH" "docker exec -u vehu '$FHIRDEV_CONTAINER' bash -lc 'source $VEHU_ENV >/dev/null 2>&1; $MUMPS -run %XCMD \"d stop^%webreq d go^%webreq\"'"

echo "==> Smoke: GET $HTTP_BASE/filesystem/tjson.js"
curl -sS -o /tmp/fhirdev-tjson-smoke.js -w "HTTP %{http_code}\n" "$HTTP_BASE/filesystem/tjson.js" | tail -1
head -c 100 /tmp/fhirdev-tjson-smoke.js | cat
echo
echo "==> Smoke: GET $HTTP_BASE/fhir (index)"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "$HTTP_BASE/fhir" | tail -1
echo "Done."
