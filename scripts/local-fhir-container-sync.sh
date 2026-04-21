#!/usr/bin/env bash
# Sync VistA-FHIR-Server-Codex src/*.m plus required top-level routines
# (currently SYNWEBUT.m) into a local FHIR/VEHU Docker container, restart
# the M web listener, re-register routes, and smoke-test HTTP.
#
# Defaults target the minimal **fhir** image (port 9081, user osehra). For patients
# with real visit-linked **TIU** notes, use the VEHU dataset instead — see
# **scripts/vehu10-fhir-sync.sh** (vehu10, port 9085, user vehu, /home/vehu/p).
#
# Default transport is docker cp + docker exec (no SSH). Set FHIR_USE_SSH=1 to
# use scp/ssh instead (same defaults as AGENTS.md).
#
# TJSON (C0FHIR browser): **vendor/tjson/** is copied into **FHIR_REMOTE_WWW** (default
# /home/<M user>/www for **fhir**; **vehu10-fhir-sync.sh** sets ~/www/filesystem). Not the host ~/www.
# **scripts/link-tjson-to-www.sh** is for a native M listener on the host only.
#
# Environment overrides:
#   FHIR_CONTAINER   (default: fhir)
#   FHIR_HTTP_BASE   (default: http://127.0.0.1:9081)
#   FHIR_REMOTE_P    (default: /home/osehra/p)
#   FHIR_REMOTE_WWW  (fhir: .../www; vehu10 wrapper: .../www/filesystem — site-dependent)
#   FHIR_REMOTE_DEMOS_ROOT — parent dir for URL /demos/rpc/ (default: same as FHIR_REMOTE_WWW
#     for fhir; for vehu10 .../www/filesystem use .../www so files land in ~/www/demos/rpc/)
#   FHIR_SKIP_RPC_DEMO=1 — do not copy rehmp-rpc-demo into www (see below)
#   REHMP_RPC_DEMO     — path to rehmp-rpc-demo package (default: $REHMP_ROOT/ehmp-ui/rehmp-rpc-demo)
#   FHIR_M_USER      (default: osehra) — su - target for ZLINK / %webreq
#   FHIR_MUMPS       (default: /home/${FHIR_M_USER}/lib/gtm/mumps)
#   FHIR_USE_SSH=1   FHIR_SSH_HOST PORT USER KEY — scp to container SSH
#   TJSON_SKIP_REGEN_B64=1 — skip scripts/regen-tjson-wasm-b64.sh before vendor copy
#   TJSON_SKIP_VERIFY_TOKEN=1 — skip cache-token verification against src/C0FHIRWS.m
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
REHMP_ROOT="${REHMP_ROOT:-$ROOT/../rehmp}"
RG_SRC="${REHMP_C0RG_DIR:-$REHMP_ROOT/C0RG}"
EXTRA_M=()
if [[ -f "$ROOT/SYNWEBUT.m" ]]; then
  EXTRA_M+=( "$ROOT/SYNWEBUT.m" )
fi

FHIR_CONTAINER="${FHIR_CONTAINER:-fhir}"
FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9081}"
FHIR_REMOTE_P="${FHIR_REMOTE_P:-/home/osehra/p}"
FHIR_M_USER="${FHIR_M_USER:-osehra}"
FHIR_REMOTE_WWW="${FHIR_REMOTE_WWW:-/home/${FHIR_M_USER}/www}"
FHIR_MUMPS="${FHIR_MUMPS:-/home/${FHIR_M_USER}/lib/gtm/mumps}"
FHIR_USE_SSH="${FHIR_USE_SSH:-0}"
REHMP_RPC_DEMO="${REHMP_RPC_DEMO:-$REHMP_ROOT/ehmp-ui/rehmp-rpc-demo}"

# GET /demos/rpc/ is served from disk under www (not the /filesystem/ prefix).
demos_parent_dir() {
  if [[ -n "${FHIR_REMOTE_DEMOS_ROOT:-}" ]]; then
    printf '%s' "$FHIR_REMOTE_DEMOS_ROOT"
  elif [[ "$FHIR_REMOTE_WWW" == */filesystem ]]; then
    printf '%s' "${FHIR_REMOTE_WWW%/filesystem}"
  else
    printf '%s' "$FHIR_REMOTE_WWW"
  fi
}

copy_via_docker() {
  local f
  for f in "$SRC"/*.m; do
    [[ -f "$f" ]] || continue
    docker cp "$f" "$FHIR_CONTAINER:$FHIR_REMOTE_P/"
  done
  for f in "${EXTRA_M[@]}"; do
    [[ -f "$f" ]] || continue
    docker cp "$f" "$FHIR_CONTAINER:$FHIR_REMOTE_P/"
  done
  for f in "$RG_SRC"/*.m; do
    [[ -f "$f" ]] || continue
    docker cp "$f" "$FHIR_CONTAINER:$FHIR_REMOTE_P/"
  done
  # docker cp is often root-owned; M user must read the sources for ZLINK.
  docker exec "$FHIR_CONTAINER" chown "${FHIR_M_USER}:${FHIR_M_USER}" "$FHIR_REMOTE_P"/*.m 2>/dev/null || true
}

copy_rehmp_rpc_demo_via_docker() {
  local d root dest
  d="$REHMP_RPC_DEMO/dist"
  root="$(demos_parent_dir)"
  dest="$root/demos/rpc"
  [[ "${FHIR_SKIP_RPC_DEMO:-0}" == "1" ]] && return 0
  [[ -f "$d/index.html" ]] || {
    echo "WARN: rehmp RPC demo dist missing ($d/index.html) — C0FHIR /demos/rpc/ links will 404. Build: (cd $REHMP_RPC_DEMO && npm ci && npm run build)" >&2
    return 0
  }
  echo "==> docker cp rehmp-rpc-demo dist -> $FHIR_CONTAINER:$dest/ (GET /demos/rpc/)"
  docker exec "$FHIR_CONTAINER" mkdir -p "$dest/assets" "$dest/examples"
  docker cp "$d/index.html" "$FHIR_CONTAINER:$dest/"
  docker cp "$d/assets/." "$FHIR_CONTAINER:$dest/assets/"
  if [[ -d "$d/examples" ]]; then
    docker cp "$d/examples/." "$FHIR_CONTAINER:$dest/examples/"
  fi
  docker exec "$FHIR_CONTAINER" chown -R "${FHIR_M_USER}:${FHIR_M_USER}" "$dest" 2>/dev/null || true
}

copy_vendor_tjson_via_docker() {
  # C0FHIR browser loads ESM from /filesystem/tjson.js (%W0 maps to ~/www/<file>).
  local v="$ROOT/vendor/tjson" f
  [[ -f "$v/tjson.js" && -f "$v/tjson_bg.js" && -f "$v/tjson_bg.wasm" && -f "$v/tjson_bg.wasm.b64" ]] || {
    echo "WARN: vendor/tjson incomplete — update with ./scripts/update-vendored-tjson.sh <version>" >&2
    return 0
  }
  echo "==> docker cp vendor/tjson/* -> $FHIR_CONTAINER:$FHIR_REMOTE_WWW/ (for /filesystem/tjson.js)"
  docker exec "$FHIR_CONTAINER" mkdir -p "$FHIR_REMOTE_WWW"
  for f in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
    docker cp "$v/$f" "$FHIR_CONTAINER:$FHIR_REMOTE_WWW/$f"
  done
  for f in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
    docker exec "$FHIR_CONTAINER" chown "${FHIR_M_USER}:${FHIR_M_USER}" "$FHIR_REMOTE_WWW/$f"
  done
}

copy_rehmp_rpc_demo_via_ssh() {
  local d root dest
  d="$REHMP_RPC_DEMO/dist"
  root="$(demos_parent_dir)"
  dest="$root/demos/rpc"
  [[ "${FHIR_SKIP_RPC_DEMO:-0}" == "1" ]] && return 0
  [[ -f "$d/index.html" ]] || {
    echo "WARN: rehmp RPC demo dist missing ($d/index.html) — skip SSH copy" >&2
    return 0
  }
  FHIR_SSH_HOST="${FHIR_SSH_HOST:-127.0.0.1}"
  FHIR_SSH_PORT="${FHIR_SSH_PORT:-2223}"
  FHIR_SSH_USER="${FHIR_SSH_USER:-osehra}"
  FHIR_SSH_KEY="${FHIR_SSH_KEY:-$HOME/.ssh/id_ed25519_cursor_agent_test}"
  SSH_BASE=(ssh -i "$FHIR_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$FHIR_SSH_PORT")
  SCP_BASE=(scp -i "$FHIR_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -P "$FHIR_SSH_PORT")
  echo "==> scp rehmp-rpc-demo dist -> ${FHIR_SSH_USER}@${FHIR_SSH_HOST}:$dest/"
  "${SSH_BASE[@]}" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}" "mkdir -p $(printf '%q' "$dest/assets") $(printf '%q' "$dest/examples")"
  "${SCP_BASE[@]}" "$d/index.html" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${dest}/"
  "${SCP_BASE[@]}" -r "$d/assets" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${dest}/"
  if [[ -d "$d/examples" ]]; then
    "${SCP_BASE[@]}" -r "$d/examples" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${dest}/"
  fi
}

copy_vendor_tjson_via_ssh() {
  local v="$ROOT/vendor/tjson" f
  [[ -f "$v/tjson.js" && -f "$v/tjson_bg.js" && -f "$v/tjson_bg.wasm" && -f "$v/tjson_bg.wasm.b64" ]] || {
    echo "WARN: vendor/tjson incomplete — update with ./scripts/update-vendored-tjson.sh <version>" >&2
    return 0
  }
  FHIR_SSH_HOST="${FHIR_SSH_HOST:-127.0.0.1}"
  FHIR_SSH_PORT="${FHIR_SSH_PORT:-2223}"
  FHIR_SSH_USER="${FHIR_SSH_USER:-osehra}"
  FHIR_SSH_KEY="${FHIR_SSH_KEY:-$HOME/.ssh/id_ed25519_cursor_agent_test}"
  SSH_BASE=(ssh -i "$FHIR_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$FHIR_SSH_PORT")
  SCP_BASE=(scp -i "$FHIR_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -P "$FHIR_SSH_PORT")
  echo "==> scp vendor/tjson/* -> ${FHIR_SSH_USER}@${FHIR_SSH_HOST}:$FHIR_REMOTE_WWW/"
  "${SSH_BASE[@]}" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}" "mkdir -p $(printf '%q' "$FHIR_REMOTE_WWW")"
  for f in tjson.js tjson_bg.js tjson_bg.wasm tjson_bg.wasm.b64; do
    "${SCP_BASE[@]}" "$v/$f" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_WWW}/${f}"
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
  if ((${#EXTRA_M[@]})); then
    echo "==> Copying top-level routines to ${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
    "${SCP_BASE[@]}" "${EXTRA_M[@]}" "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
  fi
  if ls "$RG_SRC"/*.m >/dev/null 2>&1; then
    echo "==> Copying C0RG routines from $RG_SRC to ${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
    "${SCP_BASE[@]}" "$RG_SRC"/*.m "${FHIR_SSH_USER}@${FHIR_SSH_HOST}:${FHIR_REMOTE_P}/"
  fi
}

restart_web_and_register() {
  # su - <user> loads ~/etc/env (gtm_dist, gtmgbldir, gtmroutines).
  # ZLINK the same *.m set we copy from SRC via mumps -dir (cwd = routine dir),
  # matching interactive "cd .../p && mumps -dir" — one listener process, no giant %XCMD.
  local M="$FHIR_MUMPS" remote_p_q m_q
  remote_p_q=$(printf '%q' "$FHIR_REMOTE_P")
  m_q=$(printf '%q' "$M")
  {
    local f
    for f in "$SRC"/*.m; do
      [[ -f "$f" ]] || continue
      printf 'zlink "%s"\n' "$(basename "$f" .m)"
    done
    for f in "${EXTRA_M[@]}"; do
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
  } | docker exec -i "$FHIR_CONTAINER" su - "$FHIR_M_USER" -c \
    "cd ${remote_p_q} && ${m_q} -dir"
  docker exec "$FHIR_CONTAINER" su - "$FHIR_M_USER" -c \
    "${M} -run %XCMD \"d stop^%webreq d go^%webreq\""
}

if [[ "${TJSON_SKIP_REGEN_B64:-0}" != "1" ]]; then
  echo "==> regen tjson_bg.wasm.b64 (verify decode matches wasm)"
  bash "$ROOT/scripts/regen-tjson-wasm-b64.sh"
fi
if [[ "${TJSON_SKIP_VERIFY_TOKEN:-0}" != "1" ]]; then
  echo "==> verify C0FHIRWS tjson cache token"
  bash "$ROOT/scripts/check-tjson-cache-token.sh"
fi

if [[ "$FHIR_USE_SSH" == "1" ]]; then
  copy_via_ssh
  copy_vendor_tjson_via_ssh
  copy_rehmp_rpc_demo_via_ssh
else
  echo "==> docker cp $SRC/*.m -> $FHIR_CONTAINER:$FHIR_REMOTE_P/"
  if ((${#EXTRA_M[@]})); then
    echo "==> docker cp top-level routines -> $FHIR_CONTAINER:$FHIR_REMOTE_P/"
  fi
  if [[ -d "$RG_SRC" ]]; then
    echo "==> docker cp $RG_SRC/*.m -> $FHIR_CONTAINER:$FHIR_REMOTE_P/"
  fi
  copy_via_docker
  copy_vendor_tjson_via_docker
  copy_rehmp_rpc_demo_via_docker
fi

echo "==> Restarting M web listener and re-registering routes in $FHIR_CONTAINER"
restart_web_and_register

DFN="${1:-}"
if [[ -z "$DFN" ]]; then
  echo "==> Smoke: GET $FHIR_HTTP_BASE/filesystem/tjson.js (TJSON ESM for browser)"
  curl -sS -o /tmp/fhir-smoke-tjson.js -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/filesystem/tjson.js" | tail -1
  head -c 120 /tmp/fhir-smoke-tjson.js | cat
  echo
  echo "==> Smoke: GET $FHIR_HTTP_BASE/fhir (index HTML, no dfn)"
  curl -sS -o /tmp/fhir-smoke-index.html -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/fhir" | tail -1
  if [[ -f "$REHMP_RPC_DEMO/dist/index.html" ]]; then
    echo "==> Smoke: GET $FHIR_HTTP_BASE/demos/rpc/ (rehmp UI; needs dist copied above)"
    curl -sS -o /tmp/fhir-smoke-rpc.html -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/demos/rpc/?dfn=1&rehmpBase=/rehmp" | tail -1
    head -c 80 /tmp/fhir-smoke-rpc.html | cat
    echo
  fi
  echo "==> Smoke: GET $FHIR_HTTP_BASE/tiuvpatients?limit=2 (visit-linked TIU DFN sample)"
  curl -sS -o /tmp/fhir-smoke-tiuv.json -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/tiuvpatients?limit=2" | tail -1
  head -c 400 /tmp/fhir-smoke-tiuv.json | cat
  echo
else
  echo "==> Smoke: GET $FHIR_HTTP_BASE/fhir?dfn=$DFN"
  curl -sS -o /tmp/fhir-smoke-fhir.json -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/fhir?dfn=$DFN" | tail -1
  echo "==> Smoke: GET $FHIR_HTTP_BASE/tiustats?dfn=$DFN"
  curl -sS -o /tmp/fhir-smoke-tiustats.json -w "HTTP %{http_code}\n" "$FHIR_HTTP_BASE/tiustats?dfn=$DFN" | tail -1
  head -c 500 /tmp/fhir-smoke-tiustats.json
  echo
fi

echo "Done."
