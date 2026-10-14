#!/usr/bin/env bash
# CPRS RPC Broker on native IRIS. Counterpart of scripts/iris-cprs-setup.sh.
#
# Assumes foia.sh has mounted the FOIA namespace. This script:
#   1. maps Kernel %-routines (%Z*, %RCR) into FOIA
#   2. imports the standard XUSRB1 cipher pad (src/iris-kernel/XUSRB1.mac)
#   3. sets USER,ONE to Access USER.1 / Verify VISTA.99
#   4. JOBs LISTEN^%ZISTCPS on 9430
#
# The self-healing timer that keeps 9430 and 9080 up is installed by web.sh
# (same split as the Docker scripts: cprs starts the broker, web owns the
# ensure script). A copied FOIA database already has a clinician account;
# this step still resets USER,ONE to the documented demo pair, as
# iris-cprs-setup.sh does.
#
# Usage: scripts/iris-native/cprs.sh root@host
# Env:   CPRS_VER (default 1.33.109.1), IRIS_BROKER_PORT (default 9430)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"
require_session_helper

PORT="${IRIS_BROKER_PORT:-9430}"
CPRS_VER="${CPRS_VER:-1.33.109.1}"
KDIR="$(codex_root)/src/iris-kernel"
[[ -f "$KDIR/XUSRB1.mac" ]] || { echo "ERROR: missing $KDIR/XUSRB1.mac" >&2; exit 1; }

echo "== iris-native cprs: $HOST broker $PORT =="

native_m '%SYS' <<'M'
S P("Database")="FOIA" F R="%Z*","%RCR" W "map ",R,": ",##class(Config.MapRoutines).Create("FOIA",R,.P),!
H
M

ssh "$HOST" 'mkdir -p /opt/iris/import/xus && chown irisusr:irisusr /opt/iris/import /opt/iris/import/xus'
scp -q "$KDIR/XUSRB1.mac" "$HOST:/opt/iris/import/xus/XUSRB1.mac"
ssh "$HOST" 'chown irisusr:irisusr /opt/iris/import/xus/XUSRB1.mac && chmod a+r /opt/iris/import/xus/XUSRB1.mac'

native_m FOIA <<'M'
K err S sc=$SYSTEM.OBJ.ImportDir("/opt/iris/import/xus","XUSRB1.mac","ck-d",.err,1)
W "XUSRB1 import: ",$SYSTEM.Status.GetOneStatusText(sc),!
H
M

native_m FOIA <<'M'
S U="^",DUZ=.5,DUZ(0)="@"
S $P(^VA(200,1,0),U,7)="",$P(^VA(200,1,0),U,14)=""
S AC=$$EN^XUSHSH("USER.1"),$P(^VA(200,1,0),U,3)=AC
K ^VA(200,"A") S ^VA(200,"A",AC,1)=""
S $P(^VA(200,1,.1),U,2)=$$EN^XUSHSH("VISTA.99"),$P(^VA(200,1,0),U,8)=1
S $P(^VA(200,1,1.1),U,3)="",$P(^VA(200,1,200),U,4)=1
N D0 S D0=$O(^DIC(19,"B","OR CPRS GUI CHART",0))
I D0 K ^VA(200,1,203) S ^VA(200,1,203,0)="^200.03P^"_D0_"^1",^VA(200,1,203,D0,0)=D0,^VA(200,1,203,"B",D0,D0)=""
N K1,K2,K3 S K1=$O(^DIC(19.1,"B","ORES",0)),K2=$O(^DIC(19.1,"B","PROVIDER",0)),K3=$O(^DIC(19.1,"B","XUPROGMODE",0))
K ^VA(200,1,51) S ^VA(200,1,51,0)="^200.051^^"
N C S C=0 F K=K1,K2,K3 I K S C=C+1,^VA(200,1,51,K,0)=K,^VA(200,1,51,"B",K,K)=""
S $P(^VA(200,1,51,0),U,3)=$O(^VA(200,1,51,"B",""),-1),$P(^VA(200,1,51,0),U,4)=C
W "USER,ONE bootstrapped; keys granted: ",C,!
H
M

native_m FOIA <<M
S U="^"
N I S I=\$O(^DIC(19,"B","OR CPRS GUI CHART",0))
I I S \$P(^DIC(19,I,0),U,2)="CPRSChart version ${CPRS_VER}" W "option version set: ",^DIC(19,I,0),!
N VAL D VERSRV^ORWU(.VAL,"OR CPRS GUI CHART","${CPRS_VER}") W "ORWU VERSRV now: ",VAL,!
H
M

native_m FOIA <<M
D STOP^XWBTCP($PORT)
H 2
J LISTEN^%ZISTCPS($PORT,"NT^XWBTCPM")
H
M

sleep 3
ssh "$HOST" "ss -lnt | grep -q ':${PORT} '" \
  && echo "broker listening on $PORT" \
  || { echo "ERROR: broker not listening on $PORT" >&2; exit 1; }
echo "iris-native cprs complete. USER.1 / VISTA.99 on port $PORT"
echo "next: web.sh installs the listener timer that keeps 9430 and 9080 up"
