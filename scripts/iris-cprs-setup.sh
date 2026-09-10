#!/usr/bin/env bash
# iris-cprs-setup.sh — make the VistA-on-IRIS instance reachable by the CPRS
# Windows client via the RPC Broker on TCP 9430.
#
# Assumes iris-host-setup.sh already ran (FOIA namespace + product routines).
# This script adds the three things CPRS needs that a headless FHIR server does
# not:
#   1. The VistA Kernel "%"-routines (%ZIS device handler, %ZTLOAD TaskMan,
#      %ZOSV OS layer, %ZISTCPS TCP listener) mapped into the FOIA namespace.
#      In this FOIA extract those Kernel routines are compiled under the FOIA
#      routine db, so a single Routine_%Z*->FOIA mapping resolves them.
#   2. A background RPC Broker listener bound to 9430
#      (J LISTEN^%ZISTCPS(9430,"NT^XWBTCPM")), made durable with a self-healing
#      systemd timer on the host (the listener is a JOB'd process that dies with
#      the container, so it must be re-established on (re)start).
#   3. A usable clinician account for sign-on:  Access USER.1 / Verify VISTA.99
#      (USER,ONE, DUZ 1), un-terminated, keys ORES+PROVIDER+XUPROGMODE, the
#      OR CPRS GUI CHART option as a secondary menu, VC-never-expires, and
#      multiple sign-on allowed.
#
# Usage (from the host, as root):  bash iris-cprs-setup.sh
set -euo pipefail

NAME="iris"
PORT="${1:-9430}"

# --- 1. map the Kernel %Z* routines into FOIA (idempotent) ------------------
docker exec -i "$NAME" iris session IRIS -U %SYS <<'MSYS'
S P("Database")="FOIA" W "map %Z*: ",##class(Config.MapRoutines).Create("FOIA","%Z*",.P),!
H
MSYS

# --- 3. bootstrap the CPRS sign-on account (before starting the listener) ---
docker exec -i "$NAME" iris session IRIS -U FOIA <<'MFOIA'
S U="^",DUZ=.5,DUZ(0)="@"
; un-terminate + clear DISUSER on USER,ONE (DFN 1)
S $P(^VA(200,1,0),U,7)="",$P(^VA(200,1,0),U,14)=""
; access code USER.1 (identity hash) + rebuild "A" cross-reference
S AC=$$EN^XUSHSH("USER.1"),$P(^VA(200,1,0),U,3)=AC
K ^VA(200,"A") S ^VA(200,"A",AC,1)=""
; verify code VISTA.99 (hash at .1;2); never expires (0;8=1)
S $P(^VA(200,1,.1),U,2)=$$EN^XUSHSH("VISTA.99"),$P(^VA(200,1,0),U,8)=1
; clear any stuck signed-on flag; allow multiple sign-on (200;4=1)
S $P(^VA(200,1,1.1),U,3)="",$P(^VA(200,1,200),U,4)=1
; secondary menu: OR CPRS GUI CHART
N D0 S D0=$O(^DIC(19,"B","OR CPRS GUI CHART",0))
I D0 K ^VA(200,1,203) S ^VA(200,1,203,0)="^200.03P^"_D0_"^1",^VA(200,1,203,D0,0)=D0,^VA(200,1,203,"B",D0,D0)=""
; keys: ORES, PROVIDER, XUPROGMODE
N K1,K2,K3 S K1=$O(^DIC(19.1,"B","ORES",0)),K2=$O(^DIC(19.1,"B","PROVIDER",0)),K3=$O(^DIC(19.1,"B","XUPROGMODE",0))
K ^VA(200,1,51) S ^VA(200,1,51,0)="^200.051^^"
N C S C=0 F K=K1,K2,K3 I K S C=C+1,^VA(200,1,51,K,0)=K,^VA(200,1,51,"B",K,K)=""
S $P(^VA(200,1,51,0),U,3)=$O(^VA(200,1,51,"B",""),-1),$P(^VA(200,1,51,0),U,4)=C
W "USER,ONE bootstrapped; keys granted: ",C,!
H
MFOIA

# --- 2a. start the listener now --------------------------------------------
docker exec -i "$NAME" iris session IRIS -U FOIA <<MFOIA
D STOP^XWBTCP($PORT)
H 2
J LISTEN^%ZISTCPS($PORT,"NT^XWBTCPM")
H
MFOIA
sleep 3
docker exec "$NAME" bash -c "netstat -tlnp 2>/dev/null | grep $PORT" \
  && echo "broker listening on $PORT" \
  || { echo "ERROR: broker not listening on $PORT" >&2; exit 1; }

# --- 2b. make it durable (self-healing systemd timer on the host) ----------
cat > /opt/iris/ensure-broker.sh <<SH
#!/usr/bin/env bash
set -euo pipefail
docker inspect -f "{{.State.Running}}" $NAME 2>/dev/null | grep -q true || exit 0
if docker exec $NAME bash -c "netstat -tln 2>/dev/null | grep -q :$PORT"; then exit 0; fi
docker exec -i $NAME iris session IRIS -U FOIA <<M >/dev/null 2>&1 || true
J LISTEN^%ZISTCPS($PORT,"NT^XWBTCPM")
H
M
SH
chmod +x /opt/iris/ensure-broker.sh
cat > /etc/systemd/system/iris-broker.service <<UNIT
[Unit]
Description=Ensure VistA RPC Broker listener ($PORT) inside $NAME container
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
ExecStartPre=/bin/sleep 20
ExecStart=/opt/iris/ensure-broker.sh
UNIT
cat > /etc/systemd/system/iris-broker.timer <<UNIT
[Unit]
Description=Periodically ensure VistA RPC Broker listener ($PORT) is up
[Timer]
OnBootSec=45
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now iris-broker.timer
echo "iris-cprs-setup complete. Connect CPRS to <host>:$PORT with USER.1 / VISTA.99"
