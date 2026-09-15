#!/usr/bin/env bash
# Install FMView 1.44 (routine ZZFMVIEW) + register RPC ZZFMVIEW on IRIS FOIA.
# Source: https://github.com/git-user-a/FMView/blob/master/VWFMVIEW_1_44.m
# 8994 matches vehu10: ARRAY / PUBLIC, OPTION literal + ARRAY list.
# Usage: scripts/iris-zzfmview-install.sh [ssh-host]
#   default root@irisfhir.vistaplex.org  container iris
set -euo pipefail
HOST="${1:-root@irisfhir.vistaplex.org}"
NAME="${IRIS_CONTAINER:-iris}"
SRC="${ZZFMVIEW_SRC:-}"
if [ -z "$SRC" ]; then
  SRC=/tmp/ZZFMVIEW.m
  curl -fsS -o "$SRC" 'https://raw.githubusercontent.com/git-user-a/FMView/master/VWFMVIEW_1_44.m'
fi
test -f "$SRC"
head -1 "$SRC" | grep -q '^ZZFMVIEW '

SSHCTL="/tmp/ssh-iriszzfm-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=8 \
        -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=120)
ssh() { command ssh "${SSHMUX[@]}" "$@"; }
scp() { command scp "${SSHMUX[@]}" "$@"; }
trap 'command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true' EXIT

echo "== iris-zzfmview-install: $HOST container=$NAME =="
# Host PIDs of leftover interactive FOIA sessions eat the Community license.
ssh "$HOST" 'ps -eo pid,cmd | awk "/irisdb -w .* -U FOIA/ {print \$1}" | while read -r p; do kill "$p" 2>/dev/null || true; done' || true
scp "$SRC" "$HOST:/tmp/ZZFMVIEW.m"
ssh "$HOST" "docker cp /tmp/ZZFMVIEW.m $NAME:/tmp/ZZFMVIEW.m"
ssh "$HOST" "docker exec $NAME sh -c 'printf \"ROUTINE ZZFMVIEW [Type=MAC]\\n\" | cat - /tmp/ZZFMVIEW.m > /tmp/ZZFMVIEW.mac'"

ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA" <<'MFOIA'
ZN "FOIA"
K err S sc=$SYSTEM.OBJ.ImportDir("/tmp","ZZFMVIEW.mac","ck-d",.err,1)
W "ZZFMVIEW import: ",$SYSTEM.Status.GetOneStatusText(sc),!
I $D(err) S k="" F  S k=$O(err(k)) Q:k=""  W "  err ",k,"=",err(k),!
W "T+0=",$T(+0^ZZFMVIEW),"  +2=",$T(+2^ZZFMVIEW),!
S U="^",DUZ=.5,DUZ(0)="@"
S NAME="ZZFMVIEW"
S RPCIEN=+$O(^XWB(8994,"B",NAME,0))
S IEN=$S(RPCIEN>0:RPCIEN_",",1:"+1,")
K FDA,ERR,IENR
S FDA(8994,IEN,.01)=NAME
S FDA(8994,IEN,.02)="RPC"
S FDA(8994,IEN,.03)="ZZFMVIEW"
S FDA(8994,IEN,.04)=2
S FDA(8994,IEN,.05)="P"
S FDA(8994,IEN,.06)=0
D UPDATE^DIE("","FDA","IENR","ERR")
S RPCIEN=$S(+$G(IENR(1))>0:+IENR(1),1:RPCIEN)
I $D(ERR("DIERR")) W "8994 UPDATE failed",! ZW ERR H
I RPCIEN<1 W "8994 IEN missing",! H
K ^XWB(8994,RPCIEN,2)
K PFDA,PERR
S PFDA(8994.02,"+1,"_RPCIEN_",",.01)="OPTION"
S PFDA(8994.02,"+1,"_RPCIEN_",",.02)=1
S PFDA(8994.02,"+1,"_RPCIEN_",",.03)=8
S PFDA(8994.02,"+1,"_RPCIEN_",",.04)=1
S PFDA(8994.02,"+1,"_RPCIEN_",",.05)=1
D UPDATE^DIE("","PFDA","","PERR")
I $D(PERR("DIERR")) W "PARAM OPTION failed",! ZW PERR H
K PFDA,PERR
S PFDA(8994.02,"+1,"_RPCIEN_",",.01)="ARRAY"
S PFDA(8994.02,"+1,"_RPCIEN_",",.02)=2
S PFDA(8994.02,"+1,"_RPCIEN_",",.03)=32000
S PFDA(8994.02,"+1,"_RPCIEN_",",.04)=0
S PFDA(8994.02,"+1,"_RPCIEN_",",.05)=2
D UPDATE^DIE("","PFDA","","PERR")
I $D(PERR("DIERR")) W "PARAM ARRAY failed",! ZW PERR H
W "8994 0=",^XWB(8994,RPCIEN,0)," ien=",RPCIEN,!
S CTX="ZZFMVIEW CONTEXT"
S OPTIEN=+$O(^DIC(19,"B",CTX,0))
S IEN=$S(OPTIEN>0:OPTIEN_",",1:"+1,")
K FDA,ERR,IENR
S FDA(19,IEN,.01)=CTX
S FDA(19,IEN,.04)="B"
S FDA(19,IEN,1)="FMView GUI RPC context"
D UPDATE^DIE("","FDA","IENR","ERR")
S OPTIEN=$S(+$G(IENR(1))>0:+IENR(1),1:OPTIEN)
I OPTIEN<1 W "context option failed",! I $D(ERR) ZW ERR
I OPTIEN>0,'$D(^DIC(19,OPTIEN,"RPC","B",RPCIEN)),'$D(^DIC(19,OPTIEN,10,"B",RPCIEN)) D
. K FDA,ERR
. S FDA(19.05,"+1,"_OPTIEN_",",.01)=RPCIEN
. D UPDATE^DIE("","FDA","","ERR")
. I $D(ERR("DIERR")) W "attach context RPC failed",! ZW ERR
W "context ien=",OPTIEN,!
S OR=+$O(^DIC(19,"B","OR CPRS GUI CHART",0))
I OR,'$D(^DIC(19,OR,"RPC","B",RPCIEN)),'$D(^DIC(19,OR,10,"B",RPCIEN)) D
. K FDA,ERR
. S FDA(19.05,"+1,"_OR_",",.01)=RPCIEN
. D UPDATE^DIE("","FDA","","ERR")
. I $D(ERR("DIERR")) W "attach OR CPRS RPC failed",! ZW ERR
. E  W "also attached to OR CPRS GUI CHART",!
K RESULT,ARRAY S ARRAY(1)="ping"
D RPC^ZZFMVIEW(.RESULT,"ECHO",.ARRAY)
W "ECHO RESULT(0)=",$G(RESULT(0))," RESULT(1)=",$G(RESULT(1)),!
H
MFOIA
echo "== done =="
