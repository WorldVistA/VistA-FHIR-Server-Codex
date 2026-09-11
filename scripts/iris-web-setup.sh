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

# The droplet firewalls ssh with `ufw limit 22/tcp` (max ~6 new connections /
# 30s per IP); this script makes more than that. Multiplex everything over one
# master connection so ufw sees a single TCP session.
SSHCTL="/tmp/ssh-irisweb-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 \
        -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=180)
ssh() { command ssh "${SSHMUX[@]}" "$@"; }
scp() { command scp "${SSHMUX[@]}" "$@"; }
trap 'command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true' EXIT

echo "== iris-web-setup: $HOST (container $NAME, web $WEBPORT, broker $BROKERPORT) =="

# --- 0. current Codex sources (this repo's src/) -----------------------------
# A droplet snapshot restore reverts the container's routines to whatever the
# image held; re-import the CURRENT workstation sources first so route
# registration below uses today's code. _-prefixed files become %-routines
# (same convention as iris-host-setup.sh).
CODEX_SRC="$(cd "$(dirname "$0")/../src" && pwd)"
tar -czf /tmp/codex-src.tgz -C "$CODEX_SRC" $(cd "$CODEX_SRC" && ls *.m)
scp -q /tmp/codex-src.tgz "$HOST:/tmp/"
ssh "$HOST" "
mkdir -p /opt/iris/durable/import/codex-src /opt/iris/durable/import/codex-mac
rm -f /opt/iris/durable/import/codex-src/*.m /opt/iris/durable/import/codex-mac/*.mac
tar -C /opt/iris/durable/import/codex-src -xzf /tmp/codex-src.tgz
for f in /opt/iris/durable/import/codex-src/*.m; do
  b=\$(basename \"\$f\" .m); nb=\$(echo \"\$b\" | sed 's/^_/%/')
  printf 'ROUTINE %s [Type=MAC]\n' \"\$nb\" | cat - \"\$f\" > /opt/iris/durable/import/codex-mac/\$nb.mac
done
docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
K ERR S SC=\$SYSTEM.OBJ.ImportDir(\"/durable/import/codex-mac\",\"*.mac\",\"ck-d\",.ERR,0)
N K,C S (K,C)=\"\" S C=0 F  S K=\$O(ERR(K)) Q:K=\"\"  S C=C+1
W \"codex import errors: \",C,!
H
EOF"

# --- 1. register (or refresh) HTTP routes -----------------------------------
ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA" <<'EOF'
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
  ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "mkdir -p /opt/iris/durable/www/filesystem/tjson/web && tar -C /opt/iris/durable/www/filesystem/tjson/web -xzf /tmp/tjson-web.tgz && docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
S ^%webhome=\"/durable/www/\"
W \"webhome=\",^%webhome,!
EOF"
else
  echo "WARN: vendor/tjson/web not found; skipped browser asset deploy" >&2
fi

# --- 1c. SYN loader/support routines (sibling VistA-FHIR-Data-Loader repo) --
# The C0F read server leans on SYN helpers at runtime: $$ENCODE64^SYNWEBUT
# (DocumentReference note bodies — without it every note reads back BLANK),
# SYNVPR (gtree/VPR views), SYNFHF (CarePlan health-factor filing), etc.
# Import the whole set; ImportDir is idempotent. Known non-blocking compile
# errors: SYNYOTTA (YottaDB-only ZWR syntax), SYNLINIT, and two GT.M-guarded
# "tstart ():serial" lines in SYNWEBUT (its ENCODE64/DECODE64 still compile).
SYN_SRC="$(cd "$(dirname "$0")/../../VistA-FHIR-Data-Loader/src" 2>/dev/null && pwd || true)"
if [[ -n "$SYN_SRC" && -f "$SYN_SRC/SYNWEBUT.m" ]]; then
  tar -czf /tmp/syn-src.tgz -C "$SYN_SRC" $(cd "$SYN_SRC" && ls SYN*.m)
  scp -q /tmp/syn-src.tgz "$HOST:/tmp/"
  ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "
mkdir -p /opt/iris/durable/import/syn /opt/iris/durable/import/syn-mac
rm -f /opt/iris/durable/import/syn/*.m /opt/iris/durable/import/syn-mac/*.mac
tar -C /opt/iris/durable/import/syn -xzf /tmp/syn-src.tgz
for f in /opt/iris/durable/import/syn/*.m; do b=\$(basename \"\$f\" .m); printf 'ROUTINE %s [Type=MAC]\n' \"\$b\" | cat - \"\$f\" > /opt/iris/durable/import/syn-mac/\$b.mac; done
docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
K ERR S SC=\$SYSTEM.OBJ.ImportDir(\"/durable/import/syn-mac\",\"*.mac\",\"ck-d\",.ERR,0)
W \"SYN base64 check: \",\$\$ENCODE64^SYNWEBUT(\"ok\"),!
H
EOF"
else
  echo "WARN: ../VistA-FHIR-Data-Loader/src not found; skipped SYN routine import" >&2
fi

# --- 2. upgrade the self-healing ensure script to cover both listeners ------
ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "cat > /opt/iris/ensure-broker.sh <<SH
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
ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "/opt/iris/ensure-broker.sh; sleep 2
docker exec $NAME bash -c 'netstat -tln | grep -q :$WEBPORT' && echo 'web listening on $WEBPORT' || { echo 'ERROR: web not listening on $WEBPORT' >&2; exit 1; }
docker exec $NAME bash -c 'netstat -tln | grep -q :$BROKERPORT' && echo 'broker listening on $BROKERPORT' || { echo 'ERROR: broker not listening on $BROKERPORT' >&2; exit 1; }"

HTTPHOST="${HOST#*@}"
code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 20 "http://$HTTPHOST:$WEBPORT/fhir/metadata" || echo 000)
[[ "$code" == "200" ]] && echo "fhir/metadata HTTP 200 from outside" \
  || { echo "ERROR: fhir/metadata HTTP $code from outside" >&2; exit 1; }
echo "iris-web-setup complete: http://$HTTPHOST:$WEBPORT/"
