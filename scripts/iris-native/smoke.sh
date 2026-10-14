#!/usr/bin/env bash
# Lane smoke for a native IRIS Health host. Counterpart of iris-lane-smoke.sh
# plus the C0X checks from fhir-triple-store/scripts/iris-c0x-deploy.sh.
#
# The Docker smoke SSHes and runs `docker exec iris`. This one curls the
# public HTTPS base and runs iris-session.sh on the host.
#
# Usage: scripts/iris-native/smoke.sh root@host
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"

BASE="${IRIS_HTTP_BASE:-https://$HOSTNAME_ONLY}"
DIRECT="http://${HOSTNAME_ONLY}:${IRIS_WEB_PORT:-9080}"
BROKERPORT="${IRIS_BROKER_PORT:-9430}"
fail=0
pass() { echo "  PASS  $1"; }
bad()  { echo "  FAIL  $1" >&2; fail=1; }

echo "==> iris-native smoke: $BASE"

code="$(curl -sS -o /tmp/irissmoke-portal.html -w '%{http_code}' --max-time 20 "$BASE/" || echo 000)"
if [[ "$code" == "200" ]] && grep -q "MUMPS Restful Web-Services Portal" /tmp/irissmoke-portal.html; then
  pass "web portal /"
else
  bad "web portal HTTP $code or missing portal page"
fi

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$BASE/fhir/metadata" || echo 000)"
[[ "$code" == "200" ]] && pass "fhir/metadata (via $BASE)" || bad "fhir/metadata HTTP $code (via $BASE)"

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$DIRECT/fhir/metadata" || echo 000)"
[[ "$code" == "200" ]] && pass "fhir/metadata direct listener" || bad "direct listener HTTP $code"

ctype="$(curl -sS -o /dev/null -w '%{http_code} %{content_type}' --max-time 20 "$BASE/filesystem/tjson/web/index.js" || echo 000)"
if [[ "$ctype" == 200*javascript* ]]; then
  pass "static /filesystem tjson browser module"
else
  bad "static /filesystem tjson module ($ctype)"
fi

code="$(curl -sS -o /tmp/irissmoke-dash.html -w '%{http_code}' --max-time 30 "$BASE/fhir-quality-dashboards" || echo 000)"
if [[ "$code" == "200" ]] && grep -qE 'CMS125|CMS122|CMS165' /tmp/irissmoke-dash.html; then
  pass "fhir-quality-dashboards (measure links)"
else
  bad "fhir-quality-dashboards HTTP $code or missing measure links"
fi

code="$(curl -sS -o /tmp/irissmoke-rpt.html -w '%{http_code}' --max-time 30 "$BASE/fhir-quality-reporting" || echo 000)"
if [[ "$code" == "200" ]] && grep -q "Active measures" /tmp/irissmoke-rpt.html; then
  pass "fhir-quality-reporting page"
else
  bad "fhir-quality-reporting HTTP $code or missing Active measures"
fi

code="$(curl -sS -o /tmp/irissmoke-bundle.json -w '%{http_code}' --max-time 60 "$BASE/fhir?dfn=1" || echo 000)"
if [[ "$code" == "200" ]] && python3 -c "
import json,sys
b=json.load(open('/tmp/irissmoke-bundle.json'))
kinds=[e['resource']['resourceType'] for e in b.get('entry',[]) if 'resource' in e]
sys.exit(0 if b.get('resourceType')=='Bundle' and 'Patient' in kinds else 1)" 2>/dev/null; then
  pass "live FHIR bundle for DFN 1"
else
  bad "live FHIR bundle dfn=1 HTTP $code or no Patient entry"
fi

code="$(curl -sS -o /tmp/irissmoke-rehmp.json -w '%{http_code}' --max-time 45 \
  -X POST -H 'Content-Type: application/json' \
  -d '{"apiVersion":"1.0","requestId":"iris-native-smoke","operation":"patient.search","payload":{"searchType":"auto","searchString":"MARQ","maxResults":20}}' \
  "$BASE/rehmp" || echo 000)"
if [[ "$code" == "200" ]] && python3 -c "
import json,sys
r=json.load(open('/tmp/irissmoke-rehmp.json'))
sys.exit(0 if r.get('status')=='ok' and (r.get('data',{}).get('patients')) else 1)" 2>/dev/null; then
  pass "rehmp gateway patient.search"
else
  bad "rehmp gateway HTTP $code or no patients"
fi

code="$(curl -sS -o /tmp/irissmoke-ui.html -w '%{http_code}' --max-time 20 "$BASE/demos/cprs/" || echo 000)"
if [[ "$code" == "200" ]] && grep -q "rehmp CPRS demo" /tmp/irissmoke-ui.html; then
  pass "rehmp CPRS demo UI (/demos/cprs/)"
else
  bad "rehmp CPRS demo UI HTTP $code"
fi

code="$(curl -sS -o /tmp/irissmoke-cms122.html -w '%{http_code}' --max-time 90 "$BASE/fhir-quality-dashboards/CMS122v14" || echo 000)"
if [[ "$code" == "200" ]] \
  && grep -qE 'IPP <strong>[0-9]+</strong>' /tmp/irissmoke-cms122.html \
  && grep -qE 'NUMER <strong>[0-9]+</strong>' /tmp/irissmoke-cms122.html; then
  pass "CMS122v14 dashboard renders live cohort counts"
else
  bad "CMS122v14 dashboard HTTP $code or missing IPP/NUMER counts"
fi

code="$(curl -sS -o /tmp/irissmoke-gtree.html -w '%{http_code}' --max-time 20 "$BASE/gtree/DD(0)" || echo 000)"
if [[ "$code" == "200" ]] && grep -q '\^DD(0)' /tmp/irissmoke-gtree.html; then
  pass "SYN routines (/gtree via SYNVPR)"
else
  bad "SYN routines missing: /gtree HTTP $code"
fi

ui_code="$(curl -sS -o /tmp/irissmoke-c0x.html -w '%{http_code}' --max-time 30 "$BASE/c0x/" || echo 000)"
if [[ "$ui_code" == "200" ]] && grep -qiE 'C0X|Population' /tmp/irissmoke-c0x.html; then
  pass "C0X population UI /c0x/"
else
  bad "C0X UI HTTP $ui_code"
fi

fs_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$BASE/filesystem/c0x/index.html" || echo 000)"
[[ "$fs_code" == "308" ]] && pass "C0X filesystem URL redirects to /c0x/" || bad "C0X filesystem URL HTTP $fs_code (expect 308)"

presets="$(curl -sS --max-time 45 "$BASE/c0x/presets" || true)"
if printf '%s' "$presets" | grep -qiE 'CMS|preset|measure'; then
  pass "C0X /c0x/presets"
else
  bad "C0X /c0x/presets unexpected"
fi

if timeout 10 bash -c "exec 3<>/dev/tcp/$HOSTNAME_ONLY/$BROKERPORT" 2>/dev/null; then
  pass "RPC broker port $BROKERPORT accepting"
else
  bad "RPC broker port $BROKERPORT not accepting"
fi

OUT="$(native_m FOIA <<'M' 2>&1 || true
ZN "FOIA"
W "NS=",$NAMESPACE,!
W "DD=",$G(^DD(0,0)),!
D DT^DICRW W "DT=",DT,!
W "SHIM=",$$ISGTM^C0FWOS(),"/",$$ENV^C0FWOS("HOME"),!
W "WEB=",$$UP^%webutils("abc"),!
H
M
)"
grep -q 'NS=FOIA'      <<<"$OUT" && pass "FOIA namespace" || bad "FOIA namespace"
grep -q 'DD=ATTRIBUTE' <<<"$OUT" && pass "VistA data dictionary" || bad "DD header"
grep -qE 'DT=[0-9]{7}' <<<"$OUT" && pass "FileMan runs (DT set)" || bad "FileMan DT"
grep -q 'SHIM=0/'      <<<"$OUT" && pass "C0FWOS shim runs on IRIS" || bad "C0FWOS shim"
grep -q 'WEB=ABC'      <<<"$OUT" && pass "M-Web-Server util" || bad "webutils"

if [[ "$fail" -ne 0 ]]; then
  echo "IRIS NATIVE SMOKE FAIL" >&2
  exit 1
fi
echo "IRIS NATIVE SMOKE OK"
exit 0
