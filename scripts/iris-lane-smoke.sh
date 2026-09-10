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
# Public base is Caddy/TLS (Phase 1, 2026-09-10); direct :9080 is checked
# separately below so a Caddy failure is distinguishable from a listener one.
BASE="${IRIS_HTTP_BASE:-https://$HOSTNAME_ONLY}"
DIRECT="http://$HOSTNAME_ONLY:${IRIS_WEB_PORT:-9080}"
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
[[ "$code" == "200" ]] && pass "fhir/metadata (via $BASE)" || bad "fhir/metadata HTTP $code (via $BASE)"

code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 30 "$DIRECT/fhir/metadata" || echo 000)
[[ "$code" == "200" ]] && pass "fhir/metadata direct :${IRIS_WEB_PORT:-9080} (listener)" || bad "direct listener HTTP $code"

# C0FHIR browser TJSON ESM module — static FILESYS serving from ^%webhome.
ctype=$(curl -sS -o /dev/null -w "%{http_code} %{content_type}" --max-time 20 "$BASE/filesystem/tjson/web/index.js" || echo 000)
if [[ "$ctype" == 200*javascript* ]]; then
  pass "static /filesystem tjson browser module"
else
  bad "static /filesystem tjson module ($ctype)"
fi

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

# rehmp C0RG gateway (Phase 3, 2026-09-10): patient.search must find the cohort.
code=$(curl -sS -o /tmp/irissmoke-rehmp.json -w "%{http_code}" --max-time 45 \
  -X POST -H 'Content-Type: application/json' \
  -d '{"apiVersion":"1.0","requestId":"iris-smoke-rehmp","operation":"patient.search","payload":{"searchType":"auto","searchString":"MARQ","maxResults":20}}' \
  "$BASE/rehmp" || echo 000)
if [[ "$code" == "200" ]] && python3 -c "
import json,sys
r=json.load(open('/tmp/irissmoke-rehmp.json'))
sys.exit(0 if r.get('status')=='ok' and (r.get('data',{}).get('patients')) else 1)" 2>/dev/null; then
  pass "rehmp gateway patient.search (C0RG on IRIS)"
else
  bad "rehmp gateway HTTP $code or no patients"
fi

# rehmp CPRS demo UI static assets (Phase 3, served by Caddy).
code=$(curl -sS -o /tmp/irissmoke-ui.html -w "%{http_code}" --max-time 20 "$BASE/demos/cprs/" || echo 000)
if [[ "$code" == "200" ]] && grep -q "rehmp CPRS demo" /tmp/irissmoke-ui.html; then
  pass "rehmp CPRS demo UI (/demos/cprs/)"
else
  bad "rehmp CPRS demo UI HTTP $code"
fi

# One measure dashboard must render live cohort counts (Phase 4). CMS122 is the
# smallest POP so it stays well inside Caddy's window on this single-threaded box.
code=$(curl -sS -o /tmp/irissmoke-cms122.html -w "%{http_code}" --max-time 90 "$BASE/fhir-quality-dashboards/CMS122v14" || echo 000)
if [[ "$code" == "200" ]] \
  && grep -qE "IPP <strong>[0-9]+</strong>" /tmp/irissmoke-cms122.html \
  && grep -qE "NUMER <strong>[0-9]+</strong>" /tmp/irissmoke-cms122.html; then
  pass "CMS122v14 dashboard renders live cohort counts"
else
  bad "CMS122v14 dashboard HTTP $code or missing IPP/NUMER counts"
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
