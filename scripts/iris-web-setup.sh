#!/usr/bin/env bash
# iris-web-setup.sh — bring up the M-Web-Server HTTP listener on VistA-on-IRIS.
#
# The %web* routines ship with a native Cache/IRIS branch in %webreq (it opens
# a "|TCP|<port>" device in "ACT" mode and JOBs off CHILD handlers), so unlike
# the GT.M fleet no xinetd / ydbmwebserver plugin is needed — just:
#   1. register the SYN + C0FHIR routes into ^%web(17.6001)  (D EN^SYNWEBRG)
#   2. JOB the listener                                       (D job^%webreq(9080))
#   3. keep it self-healing: upgrade /opt/iris/ensure-broker.sh to re-establish
#      BOTH the RPC broker (9430) and the web listener (9080); the existing
#      iris-broker.timer already runs it every 5 minutes.
#
# Idempotent: safe to re-run; routes refresh in place, listener start is
# skipped when 9080 is already listening.
#
# Usage: scripts/iris-web-setup.sh [ssh-host]   (default root@irisfhir.vistaplex.org)
set -euo pipefail
HOST="${1:-root@irisfhir.vistaplex.org}"
NAME="${IRIS_CONTAINER:-iris}"
WEBPORT="${IRIS_WEB_PORT:-9080}"
BROKERPORT="${IRIS_BROKER_PORT:-9430}"

echo "== iris-web-setup: $HOST (container $NAME, web $WEBPORT, broker $BROKERPORT) =="

# --- 1. register (or refresh) HTTP routes -----------------------------------
ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA" <<'EOF'
D EN^SYNWEBRG
N C,I S C=0,I=0 F  S I=$O(^%web(17.6001,I)) Q:'I  S C=C+1
W "routes: ",C,!
H
EOF

# --- 1b. static docroot for the C0FHIR browser assets (tjson ESM module) ----
# FILESYS^%webapi serves /filesystem/* from ^%webhome via $ZU(168); the browser
# TJSON view loads /filesystem/tjson/web/index.js. Deploy the vendored bundle to
# the durable mount and point ^%webhome at it. (Fleet parity: ^%webhome=~/www/.)
TJSON_WEB="$(cd "$(dirname "$0")/../vendor/tjson/web" 2>/dev/null && pwd || true)"
if [[ -n "$TJSON_WEB" && -f "$TJSON_WEB/index.js" ]]; then
  tar -czf /tmp/tjson-web.tgz -C "$TJSON_WEB" .
  scp -q /tmp/tjson-web.tgz "$HOST:/tmp/"
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" "mkdir -p /opt/iris/durable/www/filesystem/tjson/web && tar -C /opt/iris/durable/www/filesystem/tjson/web -xzf /tmp/tjson-web.tgz && docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
S ^%webhome=\"/durable/www/\"
W \"webhome=\",^%webhome,!
EOF"
else
  echo "WARN: vendor/tjson/web not found; skipped browser asset deploy" >&2
fi

# --- 2. upgrade the self-healing ensure script to cover both listeners ------
ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" "cat > /opt/iris/ensure-broker.sh <<SH
#!/usr/bin/env bash
# Ensure VistA listeners inside the $NAME container:
#   $BROKERPORT — RPC Broker  (J LISTEN^%ZISTCPS -> NT^XWBTCPM), for CPRS
#   $WEBPORT — M-Web-Server (D job^%webreq),               for FHIR/quality HTTP
# Idempotent; run by iris-broker.timer every 5 minutes.
set -euo pipefail
docker inspect -f '{{.State.Running}}' $NAME 2>/dev/null | grep -q true || exit 0
if ! docker exec $NAME bash -c 'netstat -tln 2>/dev/null | grep -q :$BROKERPORT'; then
  docker exec -i $NAME iris session IRIS -U FOIA <<'M' >/dev/null 2>&1 || true
J LISTEN^%ZISTCPS($BROKERPORT,\"NT^XWBTCPM\")
H
M
fi
if ! docker exec $NAME bash -c 'netstat -tln 2>/dev/null | grep -q :$WEBPORT'; then
  docker exec -i $NAME iris session IRIS -U FOIA <<'M' >/dev/null 2>&1 || true
D job^%webreq($WEBPORT)
H
M
fi
SH
chmod +x /opt/iris/ensure-broker.sh"

# --- 3. start the listener now (via the ensure script) and verify -----------
ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" "/opt/iris/ensure-broker.sh; sleep 2
docker exec $NAME bash -c 'netstat -tln | grep -q :$WEBPORT' && echo 'web listening on $WEBPORT' || { echo 'ERROR: web not listening on $WEBPORT' >&2; exit 1; }
docker exec $NAME bash -c 'netstat -tln | grep -q :$BROKERPORT' && echo 'broker listening on $BROKERPORT' || { echo 'ERROR: broker not listening on $BROKERPORT' >&2; exit 1; }"

HTTPHOST="${HOST#*@}"
code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 20 "http://$HTTPHOST:$WEBPORT/fhir/metadata" || echo 000)
[[ "$code" == "200" ]] && echo "fhir/metadata HTTP 200 from outside" \
  || { echo "ERROR: fhir/metadata HTTP $code from outside" >&2; exit 1; }
echo "iris-web-setup complete: http://$HTTPHOST:$WEBPORT/"
