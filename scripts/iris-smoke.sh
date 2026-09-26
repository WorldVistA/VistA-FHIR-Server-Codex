#!/usr/bin/env bash
# iris-smoke.sh — non-blocking health check for VistA-on-IRIS (irisfhir).
# Proves: IRIS instance up, FOIA namespace present, FileMan runs on the VistA
# data dictionary, and the C0FWOS portability shim executes on IRIS.
# Usage:  scripts/iris-smoke.sh [ssh-host]   (default: root@irisfhir.vistaplex.org)
set -uo pipefail
HOST="${1:-root@irisfhir.vistaplex.org}"
PASS=0; FAIL=0
row(){ if [[ "$1" == PASS ]]; then echo "  [PASS] $2"; PASS=$((PASS+1)); else echo "  [FAIL] $2"; FAIL=$((FAIL+1)); fi; }

echo "== iris-smoke: $HOST =="
OUT="$(ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" 'docker exec -i iris iris session IRIS -U FOIA' <<'EOF' 2>&1
ZN "FOIA"
W "NS=",$NAMESPACE,!
W "DD=",$G(^DD(0,0)),!
D DT^DICRW W "DT=",DT,!
W "SHIM=",$$ISGTM^C0FWOS(),"/",$$ENV^C0FWOS("HOME"),!
W "WEB=",$$UP^%webutils("abc"),!
H
EOF
)"
grep -q 'NS=FOIA'                 <<<"$OUT" && row PASS "FOIA namespace present"        || row FAIL "FOIA namespace"
grep -q 'DD=ATTRIBUTE'            <<<"$OUT" && row PASS "VistA data dictionary intact"   || row FAIL "DD header"
grep -qE 'DT=[0-9]{7}'            <<<"$OUT" && row PASS "FileMan runs (DT set)"          || row FAIL "FileMan DT"
grep -q 'SHIM=0/'                 <<<"$OUT" && row PASS "C0FWOS shim runs on IRIS"       || row FAIL "C0FWOS shim"
grep -q 'WEB=ABC'                 <<<"$OUT" && row PASS "M-Web-Server util runs on IRIS" || row FAIL "webutils"

echo "iris-smoke: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
