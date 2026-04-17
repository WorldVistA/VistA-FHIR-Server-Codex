#!/usr/bin/env bash
# Push VistA-FHIR-Server-Codex src/*.m + vendor/tjson/* to remote fhirdev22 (SSH + docker).
# Matches vehu layout: routines /home/vehu/p, static /home/vehu/www/filesystem (GET /filesystem/...).
#
# Uses SSH connection multiplexing (ControlMaster) so all scp/ssh share one TCP session.
# File copies are batched (few scp invocations + one ssh for all docker cp) so even with
# FHIRDEV_SSH_NO_MUX=1 you do not open 2 connections per routine (which can exhaust
# sshd MaxStartups and yield mid-run "Connection refused"). Prefer leaving multiplexing
# **enabled** (omit FHIRDEV_SSH_NO_MUX) when the server allows it.
#
# Defaults: root@fhirdev.vistaplex.org, container fhirdev22, smoke http://fhirdev.vistaplex.org:9080
#
# Env: FHIRDEV_SSH, FHIRDEV_CONTAINER, FHIRDEV_ROUTINE_DIR, FHIRDEV_WWW, VEHU_ENV,
#      FHIRDEV_MUMPS, FHIRDEV_HTTP_BASE, FHIRDEV_M_USER (default vehu; use osehra for fhir.vistaplex.org)
#      FHIRDEV_SSH_NO_MUX=1  — disable ControlMaster (debug only; increases TCP churn)
#      TJSON_SKIP_REGEN_B64=1 — skip scripts/regen-tjson-wasm-b64.sh before vendor scp
set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
V="$ROOT/vendor/tjson"
REHMP_ROOT="${REHMP_ROOT:-$ROOT/../rehmp}"
RG_SRC="${REHMP_C0RG_DIR:-$REHMP_ROOT/C0RG}"

FHIRDEV_SSH="${FHIRDEV_SSH:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
REMOTE_P="${FHIRDEV_ROUTINE_DIR:-/home/vehu/p}"
REMOTE_WWW="${FHIRDEV_WWW:-/home/vehu/www/filesystem}"
VEHU_ENV="${VEHU_ENV:-/home/vehu/etc/env}"
MUMPS="${FHIRDEV_MUMPS:-/home/vehu/lib/gtm/mumps}"
HTTP_BASE="${FHIRDEV_HTTP_BASE:-http://fhirdev.vistaplex.org:9080}"
FHIRDEV_M_USER="${FHIRDEV_M_USER:-vehu}"

CTL="${TMPDIR:-/tmp}/fhirdev-codex-$$.sock"
if [[ "${FHIRDEV_SSH_NO_MUX:-0}" == "1" ]]; then
  SSH_COMMON=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)
else
  SSH_COMMON=(
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o ControlMaster=auto
    -o "ControlPath=$CTL"
    -o ControlPersist=120
  )
fi
SSH=(ssh "${SSH_COMMON[@]}")
SCP=(scp "${SSH_COMMON[@]}")

STAGE="$("${SSH[@]}" "$FHIRDEV_SSH" 'mktemp -d /tmp/codex-sync.XXXXXX')"
echo "==> Remote stage on $FHIRDEV_SSH: $STAGE"

cleanup() {
  "${SSH[@]}" "$FHIRDEV_SSH" "rm -rf '$STAGE'" 2>/dev/null || true
  if [[ "${FHIRDEV_SSH_NO_MUX:-0}" != "1" ]] && [[ -S "$CTL" ]]; then
    ssh -o BatchMode=yes -S "$CTL" -O exit "$FHIRDEV_SSH" 2>/dev/null || true
  fi
  rm -f "$CTL" 2>/dev/null || true
}
trap cleanup EXIT

SRC_M=( "$SRC"/*.m )
RG_M=( "$RG_SRC"/*.m )
TJSON_FILES=( "$V/tjson.js" "$V/tjson_bg.js" "$V/tjson_bg.wasm" "$V/tjson_bg.wasm.b64" )
for tf in "${TJSON_FILES[@]}"; do
  [[ -f "$tf" ]] || {
    echo "error: missing vendor file: $tf" >&2
    exit 1
  }
done

if [[ "${TJSON_SKIP_REGEN_B64:-0}" != "1" ]]; then
  echo "==> regen tjson_bg.wasm.b64 (verify decode matches wasm)"
  bash "$ROOT/scripts/regen-tjson-wasm-b64.sh"
fi

echo "==> scp batched routines + tjson -> stage (few connections)"
if ((${#SRC_M[@]})); then
  "${SCP[@]}" "${SRC_M[@]}" "$FHIRDEV_SSH:$STAGE/"
fi
if ((${#RG_M[@]})); then
  "${SCP[@]}" "${RG_M[@]}" "$FHIRDEV_SSH:$STAGE/"
fi
"${SCP[@]}" "${TJSON_FILES[@]}" "$FHIRDEV_SSH:$STAGE/"

echo "==> one ssh: docker cp stage -> container ($FHIRDEV_CONTAINER)"
"${SSH[@]}" "$FHIRDEV_SSH" "env STAGE=$(printf '%q' "$STAGE") FHIRDEV_CONTAINER=$(printf '%q' "$FHIRDEV_CONTAINER") REMOTE_P=$(printf '%q' "$REMOTE_P") REMOTE_WWW=$(printf '%q' "$REMOTE_WWW") bash -s" <<'EOS'
set -euo pipefail
shopt -s nullglob
docker exec "$FHIRDEV_CONTAINER" mkdir -p "$REMOTE_WWW"
for f in "$STAGE"/*.m; do
  bn=$(basename "$f")
  docker cp "$f" "${FHIRDEV_CONTAINER}:${REMOTE_P}/${bn}"
done
for fn in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
  docker cp "${STAGE}/${fn}" "${FHIRDEV_CONTAINER}:${REMOTE_WWW}/${fn}"
done
EOS

"${SSH[@]}" "$FHIRDEV_SSH" "docker exec '$FHIRDEV_CONTAINER' chown '${FHIRDEV_M_USER}:${FHIRDEV_M_USER}' $REMOTE_P/*.m 2>/dev/null || true"
"${SSH[@]}" "$FHIRDEV_SSH" "docker exec '$FHIRDEV_CONTAINER' chown '${FHIRDEV_M_USER}:${FHIRDEV_M_USER}' '$REMOTE_WWW/tjson.js' '$REMOTE_WWW/tjson_bg.js' '$REMOTE_WWW/tjson_bg.wasm' '$REMOTE_WWW/tjson_bg.wasm.b64' 2>/dev/null || true"

echo "==> ZLINK + EN^SYNWEBRG + %webreq restart in $FHIRDEV_CONTAINER"
{
  for f in "$SRC"/*.m; do
    [[ -f "$f" ]] || continue
    printf 'zlink "%s"\n' "$(basename "$f" .m)"
  done
  for f in "$RG_SRC"/*.m; do
    [[ -f "$f" ]] || continue
    printf 'zlink "%s"\n' "$(basename "$f" .m)"
  done
  if [[ -f "$RG_SRC/C0RGSE.m" ]]; then
    printf '%s\n' 'd EN^C0RGSE'
  fi
  printf '%s\n' 'd EN^SYNWEBRG' 'h'
} | "${SSH[@]}" "$FHIRDEV_SSH" "docker exec -i -u '${FHIRDEV_M_USER}' '$FHIRDEV_CONTAINER' bash -lc 'source $VEHU_ENV >/dev/null 2>&1; cd $REMOTE_P && $MUMPS -dir'"

"${SSH[@]}" "$FHIRDEV_SSH" "docker exec -u '${FHIRDEV_M_USER}' '$FHIRDEV_CONTAINER' bash -lc 'source $VEHU_ENV >/dev/null 2>&1; $MUMPS -run %XCMD \"d stop^%webreq d go^%webreq\"'"

echo "==> Smoke: GET $HTTP_BASE/filesystem/tjson.js"
curl -sS -o /tmp/fhirdev-tjson-smoke.js -w "HTTP %{http_code}\n" "$HTTP_BASE/filesystem/tjson.js" | tail -1
head -c 100 /tmp/fhirdev-tjson-smoke.js | cat
echo
echo "==> Smoke: GET $HTTP_BASE/fhir (index)"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "$HTTP_BASE/fhir" | tail -1
echo "Done."
