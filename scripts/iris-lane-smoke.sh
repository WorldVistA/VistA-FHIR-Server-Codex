#!/usr/bin/env bash
# iris-lane-smoke.sh — sixth-lane (non-blocking) smoke for VistA-on-IRIS.
#
# Right-sized for the pristine irisfhir box (no patients, no C0X triple store):
#   HTTP  — portal, fhir/metadata (fleet contract: HTTP 200), quality
#           dashboards page with CMS measure links, reporting page
#   TCP   — RPC broker port accepting (CPRS lane)
#   M     — iris-smoke.sh session checks (namespace/DD/FileMan/shim/webutils)
#
# This lane must NEVER gate the five GT.M servers: deploy-quality-all.sh calls
# it non-blockingly and reports WARN instead of FAIL on the summary.
#
# Usage: scripts/iris-lane-smoke.sh [host] [ssh-user]
set -uo pipefail
HOSTNAME_ONLY="${1:-irisfhir.vistaplex.org}"
SSHHOST="${2:-root}@$HOSTNAME_ONLY"
BASE="http://$HOSTNAME_ONLY:${IRIS_WEB_PORT:-9080}"
BROKERPORT="${IRIS_BROKER_PORT:-9430}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail=0
pass() { echo "  PASS  $1"; }
bad()  { echo "  FAIL  $1" >&2; fail=1; }

echo "==> iris lane smoke: $BASE"

code=$(curl -sS -o /tmp/irissmoke-portal.html -w "%{http_code}" --max-time 20 "$BASE/" || echo 000)
if [[ "$code" == "200" ]] && grep -q "MUMPS Restful Web-Services Portal" /tmp/irissmoke-portal.html; then
  pass "web portal /"
else
  bad "web portal HTTP $code or missing portal page"
fi

code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 30 "$BASE/fhir/metadata" || echo 000)
[[ "$code" == "200" ]] && pass "fhir/metadata" || bad "fhir/metadata HTTP $code"

code=$(curl -sS -o /tmp/irissmoke-dash.html -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-dashboards" || echo 000)
if [[ "$code" == "200" ]] && grep -q "CMS125\|CMS122\|CMS165" /tmp/irissmoke-dash.html; then
  pass "fhir-quality-dashboards (measure links)"
else
  bad "fhir-quality-dashboards HTTP $code or missing measure links"
fi

code=$(curl -sS -o /tmp/irissmoke-rpt.html -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-reporting" || echo 000)
if [[ "$code" == "200" ]] && grep -q "Active measures" /tmp/irissmoke-rpt.html; then
  pass "fhir-quality-reporting page"
else
  bad "fhir-quality-reporting HTTP $code or missing Active measures"
fi

# Live FHIR round trip (needs the Aaron697 test patient, DFN 1, loaded
# 2026-09-10; after a pristine-snapshot restore re-run the addpatient POST —
# see docs/iris/IRIS_SIXTH_LANE_2026-09-10.md).
code=$(curl -sS -o /tmp/irissmoke-bundle.json -w "%{http_code}" --max-time 60 "$BASE/fhir?dfn=1" || echo 000)
if [[ "$code" == "200" ]] && python3 -c "
import json,sys
b=json.load(open('/tmp/irissmoke-bundle.json'))
kinds=[e['resource']['resourceType'] for e in b.get('entry',[]) if 'resource' in e]
sys.exit(0 if b.get('resourceType')=='Bundle' and 'Patient' in kinds else 1)" 2>/dev/null; then
  pass "live FHIR bundle for DFN 1 (read server on IRIS)"
else
  bad "live FHIR bundle dfn=1 HTTP $code or no Patient entry (test patient missing?)"
fi

if timeout 10 bash -c "exec 3<>/dev/tcp/$HOSTNAME_ONLY/$BROKERPORT" 2>/dev/null; then
  pass "RPC broker port $BROKERPORT accepting (CPRS)"
else
  bad "RPC broker port $BROKERPORT not accepting"
fi

if "$ROOT/scripts/iris-smoke.sh" "$SSHHOST"; then
  pass "iris-smoke session checks"
else
  bad "iris-smoke session checks"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "IRIS LANE SMOKE FAIL (non-blocking lane)" >&2
  exit 1
fi
echo "IRIS LANE SMOKE OK"
exit 0
