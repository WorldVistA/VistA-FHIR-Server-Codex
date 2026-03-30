#!/usr/bin/env bash
# Sync VistA-FHIR-Server-Codex src/*.m into the local FHIR Docker container,
# restart the M web listener, re-register routes, and smoke-test HTTP.
#
# Default transport is docker cp + docker exec (no SSH). Set FHIR_USE_SSH=1 to
# use scp/ssh instead (same defaults as AGENTS.md).
#
# Environment overrides:
#   FHIR_CONTAINER   (default: fhir)
#   FHIR_HTTP_BASE   (default: http://127.0.0.1:9081)
#   FHIR_REMOTE_P    (default: /home/osehra/p)
#   FHIR_USE_SSH=1   FHIR_SSH_HOST PORT USER KEY — scp to container SSH
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"

FHIR_CONTAINER="${FHIR_CONTAINER:-fhir}"
FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9081}"
FHIR_REMOTE_P="${FHIR_REMOTE_P:-/home/osehra/p}"
FHIR_USE_SSH="${FHIR_USE_SSH:-0}"

copy_via_docker() {
  local f
  for f in "$SRC"/*.m; do
    [[ -f "$f" ]] || continue
    docker cp "$f" "$FHIR_CONTAINER:$FHIR_REMOTE_P/"
  done
}

copy_via_ssh() {
  FHIR_SSH_HOST="${FHIR_SSH_HOST:-127.0.0.1}"
  FHIR_SSH_PORT="${FHIR_SSH_PORT:-2223}"
  FHIR_SSH_USER="${FHIR_SSH_USER:-osehra}"
  FHIR_SSH_KEY="${FHIR_SSH_KEY:-$HOME/.ssh/id_ed25519_cursor_agent_test}"
  SCP_BASE=(scp -i "$FHIR_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -P "$FHIR_SSH_PORT")
  echo "==> Copying routines from $SRC to ${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
  "${SCP_BASE[@]}" "$SRC"/*.m "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
}

restart_web_and_register() {
  # su - osehra loads ~/etc/env (gtm_dist, gtmgbldir, gtmroutines). Plain docker exec -u
  # osehra bash -lc can hit %GTM-E-JOBFAIL from stop^%webreq on some images (nvm/stderr).
  docker exec "$FHIR_CONTAINER" su - osehra -c '/home/osehra/lib/gtm/mumps -run %XCMD "zlink \"C0FTIUST\" zlink \"SYNWEBRG\" d EN^SYNWEBRG"'
  docker exec "$FHIR_CONTAINER" su - osehra -c '/home/osehra/lib/gtm/mumps -run %XCMD "d stop^%webreq d go^%webreq"'
}

if [[ "$FHIR_USE_SSH" == "1" ]]; then
  copy_via_ssh
else
  echo "==> docker cp $SRC/*.m -> $FHIR_CONTAINER:$FHIR_REMOTE_P/"
  copy_via_docker
fi

echo "==> Restarting M web listener and re-registering routes in $FHIR_CONTAINER"
restart_web_and_register

DFN="${1:-}"
if [[ -z "$DFN" ]]; then
  echo "==> Smoke: GET $FHIR_HTTP_BASE/fhir (index HTML, no dfn)"
  curl -sS -o /tmp/fhir-smoke-index.html -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/fhir" | tail -1
else
  echo "==> Smoke: GET $FHIR_HTTP_BASE/fhir?dfn=$DFN"
  curl -sS -o /tmp/fhir-smoke-fhir.json -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/fhir?dfn=$DFN" | tail -1
  echo "==> Smoke: GET $FHIR_HTTP_BASE/tiustats?dfn=$DFN"
  curl -sS -o /tmp/fhir-smoke-tiustats.json -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/tiustats?dfn=$DFN" | tail -1
  head -c 500 /tmp/fhir-smoke-tiustats.json
  echo
fi

echo "Done."
