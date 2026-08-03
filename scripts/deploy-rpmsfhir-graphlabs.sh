#!/usr/bin/env bash
# Deploy EXPERIMENT graph-labs (C0FHIRLG + C0FHIRL hook) to disposable rpmsfhir only.
# Does NOT enable the flag on any other host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_HOST="${RPMSFHIR_SSH:-root@rpmsfhir.vistaplex.org}"
CONT="${RPMSFHIR_CONTAINER:-rpms-fhir}"
REMOTE_P="${RPMSFHIR_ROUTINE_DIR:-/home/rpms/r}"
M_USER="${RPMSFHIR_M_USER:-rpms}"
MUMPS="${RPMSFHIR_MUMPS:-/home/rpms/lib/gtm/mumps}"
HTTP_BASE="${RPMSFHIR_HTTP_BASE:-https://rpmsfhir.vistaplex.org}"
DFN="${1:-8}"

SSH=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
SCP=(scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

need=(C0FHIRLG.m C0FHIRL.m)
for f in "${need[@]}"; do
  [[ -f "$ROOT/src/$f" ]] || { echo "missing $ROOT/src/$f" >&2; exit 1; }
done

echo "==> stage on $SSH_HOST"
STAGE=$("${SSH[@]}" "$SSH_HOST" 'mktemp -d /tmp/graphlabs.XXXXXX')
cleanup() { "${SSH[@]}" "$SSH_HOST" "rm -rf '$STAGE'" 2>/dev/null || true; }
trap cleanup EXIT

"${SCP[@]}" "$ROOT/src/C0FHIRLG.m" "$ROOT/src/C0FHIRL.m" "$SSH_HOST:$STAGE/"

echo "==> docker cp + chown into $CONT:$REMOTE_P"
"${SSH[@]}" "$SSH_HOST" "docker cp '$STAGE/C0FHIRLG.m' '$CONT:$REMOTE_P/C0FHIRLG.m' && docker cp '$STAGE/C0FHIRL.m' '$CONT:$REMOTE_P/C0FHIRL.m' && docker exec '$CONT' chown '$M_USER:$M_USER' '$REMOTE_P/C0FHIRLG.m' '$REMOTE_P/C0FHIRL.m'"

echo "==> ZLINK + enable EXPERIMENT GRAPHLABS + %webreq restart"
"${SSH[@]}" "$SSH_HOST" "docker exec -i -u '$M_USER' '$CONT' bash -lc 'cd $REMOTE_P && $MUMPS -dir'" <<'M'
zlink "C0FHIRLG"
zlink "C0FHIRL"
s ^C0FHIR("EXPERIMENT","GRAPHLABS")=1
w "GRAPHLABS=",+$g(^C0FHIR("EXPERIMENT","GRAPHLABS")),!
w "ON=",$$ON^C0FHIRLG(),!
d stop^%webreq
d go^%webreq
h
M

echo "==> HTTP smoke metadata"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$HTTP_BASE/fhir/metadata" || true)
echo "metadata HTTP $code"
[[ "$code" == "200" ]] || echo "WARN: metadata not 200 (continuing)"

echo "==> seed + labs domain smoke dfn=$DFN"
chmod +x "$ROOT/scripts/smoke-rpmsfhir-graphlabs.sh"
"$ROOT/scripts/smoke-rpmsfhir-graphlabs.sh" "$HTTP_BASE" "$DFN"

echo "==> DONE graph-labs experiment on $HTTP_BASE"
