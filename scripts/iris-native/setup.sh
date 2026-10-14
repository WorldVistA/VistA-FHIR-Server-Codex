#!/usr/bin/env bash
# Bring a new Rocky Linux host up to the irisfhir lane on native IRIS Health.
#
# Order, matching the Docker scripts:
#   install.sh     kit + license + systemd          (iris-host-setup's install half)
#   foia-copy.sh   optional consistent DAT copy
#   foia.sh        FOIA namespace and mappings      (iris-host-setup's namespace half)
#   cprs.sh        RPC broker and USER.1            (iris-cprs-setup.sh)
#   web.sh         routes, sources, listeners       (iris-web-setup.sh)
#   public.sh      Caddy and rehmp UI               (iris-public-setup.sh)
#   c0x.sh         population UI and routes         (iris-c0x-deploy.sh)
#   smoke.sh       HTTP + session checks            (iris-lane-smoke.sh + C0X)
#
# The license key is copied to the host and is not stored in git. The
# SuperUser password is generated on the host. The fleet lane is iris2
# (`deploy-quality-all.sh` target `iris2`). This script does not edit TARGETS.
#
# Usage:
#   scripts/iris-native/setup.sh root@newhost \
#     --kit /path/to/IRISHealth-*-lnxrh9x64.tar.gz \
#     --key /path/to/iris.key \
#     --copy-from root@irisfhir.vistaplex.org
#
# --copy-from is optional when /opt/iris/data/foia/IRIS.DAT is already on the
# destination. REHMP_FROM=root@host copies a built CPRS demo when dist/ is absent.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

HOST=""
KIT=""
KEY=""
COPY_FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kit) KIT="${2:?}"; shift 2 ;;
    --key) KEY="${2:?}"; shift 2 ;;
    --copy-from) COPY_FROM="${2:?}"; shift 2 ;;
    --rehmp-from) REHMP_FROM="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,28p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$HOST" ]]; then HOST="$1"; shift; else echo "unknown arg: $1" >&2; exit 2; fi
      ;;
  esac
done
[[ -n "$HOST" && -n "$KEY" ]] || { echo "usage: setup.sh root@host --key FILE [--kit TAR] [--copy-from root@source]" >&2; exit 2; }

echo "== 1/8 install =="
install_args=( "$HOST" --key "$KEY" )
[[ -n "$KIT" ]] && install_args+=( --kit "$KIT" )
"$DIR/install.sh" "${install_args[@]}"

if [[ -n "$COPY_FROM" ]]; then
  echo "== 2/8 foia copy =="
  "$DIR/foia-copy.sh" "$HOST" "$COPY_FROM"
else
  echo "== 2/8 foia copy skipped (DAT must already be on the host) =="
fi

echo "== 3/8 foia namespace =="
"$DIR/foia.sh" "$HOST"
echo "== 4/8 cprs =="
"$DIR/cprs.sh" "$HOST"
echo "== 5/8 web =="
"$DIR/web.sh" "$HOST"
echo "== 6/8 public =="
REHMP_FROM="${REHMP_FROM:-}" "$DIR/public.sh" "$HOST"
echo "== 7/8 c0x =="
"$DIR/c0x.sh" "$HOST"
echo "== 8/8 smoke =="
"$DIR/smoke.sh" "$HOST"
echo "iris-native setup complete: https://${HOST#*@}/"
echo "Fleet lane is iris2 in deploy-quality-all.sh. This script does not edit TARGETS."
