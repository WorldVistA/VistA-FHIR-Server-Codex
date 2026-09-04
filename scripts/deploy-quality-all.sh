#!/usr/bin/env bash
# Deploy quality-dashboard + C0X stack to all active servers, then smoke each.
#
# Active servers (default):
#   fhirdev  vehu10  rpms-candidate  rpmsfhir  fhirprod
#
# Usage:
#   ./scripts/deploy-quality-all.sh
#   QUALITY_DEPLOY_TARGETS="fhirdev vehu10" ./scripts/deploy-quality-all.sh
#   QUALITY_SKIP_DEPLOY=1 ./scripts/deploy-quality-all.sh   # smoke only
#   QUALITY_REINDEX=1 ./scripts/deploy-quality-all.sh       # enrich code triples after deploy
#
# Exact agent phrases (see AGENTS.md):
#   "deploy-quality-all"
#   "deploy quality to all active"
#   "fix this and deploy-quality-all"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
C0X_ROOT="${C0X_ROOT:-$ROOT/../fhir-triple-store}"
SMOKE="$ROOT/scripts/smoke-quality-host.sh"
TARGETS="${QUALITY_DEPLOY_TARGETS:-fhirdev vehu10 rpms-candidate rpmsfhir fhirprod}"
SKIP_DEPLOY="${QUALITY_SKIP_DEPLOY:-0}"
REINDEX="${QUALITY_REINDEX:-0}"

chmod +x "$SMOKE" 2>/dev/null || true
[[ -x "$SMOKE" ]] || chmod +x "$SMOKE"

declare -a RESULTS=()

run_seedcrit_local() {
  local cont="$1" user="$2" rdir="$3" mumps="$4" envfile="${5:-}"
  if [[ -n "$envfile" ]]; then
    docker exec -u "$user" -i "$cont" bash -lc "source $envfile >/dev/null 2>&1; cd $rdir && $mumps -dir" <<'M'
ZL "C0FQUAL"
I $T(SEEDCRIT^C0FQUAL)'="" D SEEDCRIT^C0FQUAL W "SEEDCRIT ok",!
H
M
  else
    docker exec -u "$user" -i "$cont" bash -lc "cd $rdir && $mumps -dir" <<'M'
ZL "C0FQUAL"
I $T(SEEDCRIT^C0FQUAL)'="" D SEEDCRIT^C0FQUAL W "SEEDCRIT ok",!
H
M
  fi
}

run_seedcrit_remote() {
  local sshh="$1" cont="$2" user="$3" rdir="$4" mumps="$5" envfile="$6"
  ssh -o BatchMode=yes -o ConnectTimeout=30 "$sshh" "docker exec -u '$user' -i '$cont' bash -lc 'source $envfile >/dev/null 2>&1; cd $rdir && $mumps -dir'" <<'M'
ZL "C0FQUAL"
I $T(SEEDCRIT^C0FQUAL)'="" D SEEDCRIT^C0FQUAL W "SEEDCRIT ok",!
H
M
}

maybe_reindex() {
  local base="$1"
  [[ "$REINDEX" == "1" ]] || return 0
  echo "  reindex $base ..."
  curl -sS -X POST --max-time 180 "$base/c0x/index/reindex?max=500&start=0" >/tmp/q-reindex.json \
    || echo "  WARN: reindex request failed for $base" >&2
}

deploy_one() {
  local t="$1"
  echo ""
  echo "======== DEPLOY $t ========"
  case "$t" in
    fhirdev)
      "$ROOT/scripts/fhirdev-codex-sync.sh"
      "$C0X_ROOT/scripts/deploy-c0x.sh" fhirdev || true
      run_seedcrit_remote root@devfhir.vistaplex.org fhirdev22 vehu /home/vehu/p /home/vehu/lib/gtm/mumps /home/vehu/etc/env || true
      maybe_reindex https://devfhir.vistaplex.org
      ;;
    fhirprod|fhir)
      FHIRDEV_SSH=root@fhir.vistaplex.org \
      FHIRDEV_CONTAINER=fhir \
      FHIRDEV_ROUTINE_DIR=/home/osehra/p \
      FHIRDEV_WWW=/home/osehra/www \
      VEHU_ENV=/home/osehra/etc/env \
      FHIRDEV_MUMPS=/home/osehra/lib/gtm/mumps \
      FHIRDEV_HTTP_BASE=https://fhir.vistaplex.org \
      FHIRDEV_M_USER=osehra \
      "$ROOT/scripts/fhirdev-codex-sync.sh"
      "$C0X_ROOT/scripts/deploy-c0x.sh" fhirprod || true
      run_seedcrit_remote root@fhir.vistaplex.org fhir osehra /home/osehra/p /home/osehra/lib/gtm/mumps /home/osehra/etc/env || true
      maybe_reindex https://fhir.vistaplex.org
      ;;
    vehu10)
      "$ROOT/scripts/vehu10-fhir-sync.sh" || true
      "$C0X_ROOT/scripts/deploy-c0x.sh" vehu10 || true
      run_seedcrit_local vehu10 vehu /home/vehu/p /home/vehu/lib/gtm/mumps /home/vehu/etc/env || true
      maybe_reindex http://127.0.0.1:9085
      ;;
    rpms-candidate|rpms-rebuild-candidate|rpms)
      FHIR_CONTAINER=rpms-rebuild-candidate \
      FHIR_HTTP_BASE=http://127.0.0.1:9088 \
      FHIR_REMOTE_P=/home/rpms/r \
      FHIR_M_USER=rpms \
      FHIR_REMOTE_WWW=/home/rpms/www/filesystem \
      FHIR_MUMPS=/home/rpms/lib/gtm/mumps \
      FHIR_SKIP_RPC_DEMO=1 \
      "$ROOT/scripts/local-fhir-container-sync.sh" || true
      docker exec -u rpms -i rpms-rebuild-candidate bash -lc 'cd /home/rpms/r && /home/rpms/lib/gtm/mumps -dir' <<'M' || true
I $G(^%webhome)="" S ^%webhome="/home/rpms/www/"
H
M
      "$C0X_ROOT/scripts/deploy-c0x.sh" rpms-candidate || true
      run_seedcrit_local rpms-rebuild-candidate rpms /home/rpms/r /home/rpms/lib/gtm/mumps || true
      maybe_reindex http://127.0.0.1:9088
      ;;
    rpmsfhir|rpms-fhir)
      # Public RPMS demo: Codex routines + graph-labs + quality dashboard routes
      FHIRDEV_SSH=root@rpmsfhir.vistaplex.org \
      FHIRDEV_CONTAINER=rpms-fhir \
      FHIRDEV_ROUTINE_DIR=/home/rpms/r \
      FHIRDEV_WWW=/home/rpms/www/filesystem \
      VEHU_ENV=/home/rpms/etc/env \
      FHIRDEV_MUMPS=/home/rpms/lib/gtm/mumps \
      FHIRDEV_HTTP_BASE=https://rpmsfhir.vistaplex.org \
      FHIRDEV_M_USER=rpms \
      "$ROOT/scripts/fhirdev-codex-sync.sh" || true
      "$ROOT/scripts/deploy-rpmsfhir-graphlabs.sh" 8 || true
      "$C0X_ROOT/scripts/deploy-c0x.sh" rpmsfhir || true
      run_seedcrit_remote root@rpmsfhir.vistaplex.org rpms-fhir rpms /home/rpms/r /home/rpms/lib/gtm/mumps /home/rpms/etc/env || true
      maybe_reindex https://rpmsfhir.vistaplex.org
      ;;
    *)
      echo "unknown target: $t" >&2
      return 1
      ;;
  esac
}

smoke_one() {
  local t="$1" base dfn
  case "$t" in
    fhirdev)  base=https://devfhir.vistaplex.org; dfn=101076 ;;
    fhirprod|fhir) base=https://fhir.vistaplex.org; dfn=1643 ;;  # fhirprod cohort = DFNs 1643-1661
    vehu10)   base=http://127.0.0.1:9085; dfn=101076 ;;
    rpms-candidate|rpms-rebuild-candidate|rpms) base=http://127.0.0.1:9088; dfn=4 ;;
    rpmsfhir|rpms-fhir) base=https://rpmsfhir.vistaplex.org; dfn=8 ;;
    *) echo "unknown smoke target: $t" >&2; return 1 ;;
  esac
  if "$SMOKE" "$t" "$base" "$dfn"; then
    RESULTS+=("OK  $t")
    return 0
  fi
  RESULTS+=("FAIL $t")
  return 1
}

echo "Quality deploy-all targets: $TARGETS"
echo "C0X_ROOT=$C0X_ROOT"
echo "SKIP_DEPLOY=$SKIP_DEPLOY REINDEX=$REINDEX"

overall=0
for t in $TARGETS; do
  if [[ "$SKIP_DEPLOY" != "1" ]]; then
    if ! deploy_one "$t"; then
      RESULTS+=("FAIL $t (deploy)")
      overall=1
      continue
    fi
  fi
  if ! smoke_one "$t"; then
    overall=1
  fi
done

echo ""
echo "======== SUMMARY ========"
for r in "${RESULTS[@]}"; do echo "$r"; done

if [[ "$overall" -ne 0 ]]; then
  echo "deploy-quality-all: FAILED" >&2
  exit 1
fi
echo "deploy-quality-all: OK"
exit 0
