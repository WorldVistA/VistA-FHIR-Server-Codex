#!/usr/bin/env bash
# FHIR / quality HTTP lane on native IRIS. Counterpart of scripts/iris-web-setup.sh.
#
# Imports current Codex, SYN, and C0RG sources, registers ^%web routes, points
# ^%webhome at /opt/iris/www/, installs the TJSON browser assets, creates the
# C0SSL config, forces ENCODER=JSNE, and keeps :9080 and :9430 up with a
# systemd timer. IRIS has no YottaDB C plugin; AUTO would hard-fail encode.
#
# Paths differ from the Docker scripts: there is no /durable mount. Imports
# live in /opt/iris/import and the FILESYS docroot is /opt/iris/www/.
#
# Usage: scripts/iris-native/web.sh root@host
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"
require_session_helper

WEBPORT="${IRIS_WEB_PORT:-9080}"
BROKERPORT="${IRIS_BROKER_PORT:-9430}"
CODEX_SRC="$(codex_root)/src"
SYN_SRC="$(vista_stack)/VistA-FHIR-Data-Loader/src"
C0RG_SRC="$(vista_stack)/rehmp/C0RG"
KID_SRC="$(vista_stack)/VistA-DataLoader/VistA/VISTA_DATALOADER_3P1.KID"
LACC_SRC="$(codex_root)/scripts/artifacts/C0FZLACC.mac"
TJSON_WEB="$(codex_root)/vendor/tjson/web"

echo "== iris-native web: $HOST (web $WEBPORT, broker $BROKERPORT) =="
ssh "$HOST" 'mkdir -p /opt/iris/import /opt/iris/www/filesystem && chown irisusr:irisusr /opt/iris/import && chmod a+rX /opt/iris/www'

# --- 0. current Codex sources ------------------------------------------------
[[ -d "$CODEX_SRC" && -f "$CODEX_SRC/C0FHIR.m" ]] || { echo "ERROR: Codex src missing at $CODEX_SRC" >&2; exit 1; }
tar -czf /tmp/codex-src.tgz -C "$CODEX_SRC" $(cd "$CODEX_SRC" && ls *.m)
scp -q /tmp/codex-src.tgz "$HOST:/tmp/"
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p /opt/iris/import/codex-src /opt/iris/import/codex-mac
rm -f /opt/iris/import/codex-src/*.m /opt/iris/import/codex-mac/*.mac
tar -C /opt/iris/import/codex-src -xzf /tmp/codex-src.tgz
for f in /opt/iris/import/codex-src/*.m; do
  b=$(basename "$f" .m)
  nb=$(echo "$b" | sed 's/^_/%/')
  printf 'ROUTINE %s [Type=MAC]\n' "$nb" | cat - "$f" > "/opt/iris/import/codex-mac/${nb}.mac"
done
chown -R irisusr:irisusr /opt/iris/import/codex-src /opt/iris/import/codex-mac
chmod -R a+rX /opt/iris/import/codex-src /opt/iris/import/codex-mac
echo "codex mac: $(find /opt/iris/import/codex-mac -name '*.mac' | wc -l)"
REMOTE

native_m '%SYS' <<'M'
ZN "%SYS"
K P S P("Database")="FOIA"
S SC=##class(Config.MapRoutines).Create("FOIA","%WC",.P)
W "%WC mapping: ",$S(+SC=1:"created",1:"exists/err (ok if exists)"),!
S SC=##class(Security.SSLConfigs).Create("C0SSL")
W "C0SSL config: ",$S(+SC=1:"created",1:"exists/err (ok if exists)"),!
ZN "FOIA"
K ERR S SC=$SYSTEM.OBJ.ImportDir("/opt/iris/import/codex-mac","*.mac","ck-d",.ERR,0)
N K,C S (K,C)="" S C=0 F  S K=$O(ERR(K)) Q:K=""  S C=C+1
W "codex import errors: ",C,!
H
M

# --- 1. routes + FILESYS docroot --------------------------------------------
ssh "$HOST" 'mkdir -p /opt/iris/www && chmod a+rX /opt/iris/www'
native_m FOIA <<'M'
D EN^SYNWEBRG
S ^%webhome="/opt/iris/www/"
W "webhome=",^%webhome,!
N C,I S C=0,I=0 F  S I=$O(^%web(17.6001,I)) Q:'I  S C=C+1
W "routes: ",C,!
H
M

# --- 1b. TJSON browser assets ------------------------------------------------
if [[ -f "$TJSON_WEB/index.js" ]]; then
  tar -czf /tmp/tjson-web.tgz -C "$TJSON_WEB" .
  scp -q /tmp/tjson-web.tgz "$HOST:/tmp/"
  ssh "$HOST" 'mkdir -p /opt/iris/www/filesystem/tjson/web && tar -C /opt/iris/www/filesystem/tjson/web -xzf /tmp/tjson-web.tgz && chmod -R a+rX /opt/iris/www/filesystem/tjson && echo "tjson deployed"'
else
  echo "WARN: vendor/tjson/web not found; skipped browser asset deploy" >&2
fi

# --- 1c. SYN loader routines -------------------------------------------------
if [[ -f "$SYN_SRC/SYNWEBUT.m" ]]; then
  tar -czf /tmp/syn-src.tgz -C "$SYN_SRC" $(cd "$SYN_SRC" && ls SYN*.m)
  scp -q /tmp/syn-src.tgz "$HOST:/tmp/"
  ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p /opt/iris/import/syn /opt/iris/import/syn-mac
rm -f /opt/iris/import/syn/*.m /opt/iris/import/syn-mac/*.mac
tar -C /opt/iris/import/syn -xzf /tmp/syn-src.tgz
for f in /opt/iris/import/syn/*.m; do
  b=$(basename "$f" .m)
  awk -v n="$b" 'NR==1{sub(/^[^ \t;]+/, n)} {print}' "$f" > /tmp/synfix.m
  printf 'ROUTINE %s [Type=MAC]\n' "$b" | cat - /tmp/synfix.m > "/opt/iris/import/syn-mac/${b}.mac"
done
rm -f /tmp/synfix.m
chown -R irisusr:irisusr /opt/iris/import/syn /opt/iris/import/syn-mac
chmod -R a+rX /opt/iris/import/syn /opt/iris/import/syn-mac
echo "syn mac: $(find /opt/iris/import/syn-mac -name '*.mac' | wc -l)"
REMOTE
  native_m FOIA <<'M'
K ERR S SC=$SYSTEM.OBJ.ImportDir("/opt/iris/import/syn-mac","*.mac","ck-d",.ERR,0)
K ERR S SC=$SYSTEM.OBJ.ImportDir("/opt/iris/import/syn-mac","*.mac","ck-d",.ERR,0)
N K,C S (K,C)="" S C=0 F  S K=$O(ERR(K)) Q:K=""  S C=C+1
W "SYN compile errors after 2 passes: ",C," (expect ~3: SYNYOTTA/SYNLINIT/SYNWEBUT)",!
W "SYN base64 check: ",$$ENCODE64^SYNWEBUT("ok"),!
W "SYNGRAPH enterable: ",$S($T(graphmap^SYNGRAPH)'="":"yes",1:"NO"),!
H
M
else
  echo "WARN: VistA-FHIR-Data-Loader/src not found; skipped SYN import" >&2
fi

# --- 1d. rehmp C0RG ----------------------------------------------------------
if [[ -f "$C0RG_SRC/C0RGAPI.m" ]]; then
  tar -czf /tmp/c0rg-src.tgz -C "$C0RG_SRC" $(cd "$C0RG_SRC" && ls *.m)
  scp -q /tmp/c0rg-src.tgz "$HOST:/tmp/"
  ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p /opt/iris/import/rehmp-src /opt/iris/import/rehmp
rm -f /opt/iris/import/rehmp-src/*.m /opt/iris/import/rehmp/*.mac
tar -C /opt/iris/import/rehmp-src -xzf /tmp/c0rg-src.tgz
for f in /opt/iris/import/rehmp-src/*.m; do
  b=$(basename "$f" .m)
  printf 'ROUTINE %s [Type=MAC]\n' "$b" | cat - "$f" > "/opt/iris/import/rehmp/${b}.mac"
done
chown -R irisusr:irisusr /opt/iris/import/rehmp-src /opt/iris/import/rehmp
chmod -R a+rX /opt/iris/import/rehmp-src /opt/iris/import/rehmp
echo "c0rg mac: $(find /opt/iris/import/rehmp -name '*.mac' | wc -l)"
REMOTE
  fhirbase="https://${HOSTNAME_ONLY}/fhir"
  native_m FOIA <<EOF
K ERR S SC=\$SYSTEM.OBJ.ImportDir("/opt/iris/import/rehmp","*.mac","ck-d",.ERR,0)
N K,C S (K,C)="" S C=0 F  S K=\$O(ERR(K)) Q:K=""  S C=C+1
W "c0rg import errors: ",C,!
D EN^SYNWEBRG
N C,I S C=0,I=0 F  S I=\$O(^%web(17.6001,I)) Q:'I  S C=C+1
W "routes after c0rg: ",C,!
S ^C0FQUAL("FHIRBASE")="${fhirbase}"
W "FHIRBASE: ",^C0FQUAL("FHIRBASE"),!
D SET^C0RGPAR("ENCODER","JSNE")
W "ENCODER: ",\$\$GETPAR^C0RGPAR("ENCODER"),!
H
EOF
else
  echo "WARN: rehmp/C0RG not found; skipped C0RG import" >&2
fi

# --- 1e. loader environment (idempotent) ------------------------------------
native_m FOIA <<'M'
D ENVINIT^C0FHIR
I $$FIND1^DIC(19,"","QX","SYNMENU","B")<1 N FDA,IEN S FDA(19,"?+1,",.01)="SYNMENU",FDA(19,"?+1,",1)="Synthea Loader Menu",FDA(19,"?+1,",4)="M" D UPDATE^DIE("E",$NA(FDA),$NA(IEN))
W "syn provider: ",$$PROV^SYNINIT(0),!
W "syn pharmacist: ",$$PHARM^SYNINIT(0),!
D AMIE^SYNINIT
D IBACTION^SYNINIT
W "pharmacy site: ",$$PSOSITE^SYNINIT(),!
D ALBUL^SYNINIT
D EN^SYNGBLLD
W "sct2os5 map: ",$S($D(^SYN("2002.030","sct2os5","direct")):"built",1:"MISSING"),!
I '$$ACTIVEPC^C0FWENC(1) N FDA,ERR S FDA(200.05,"+1,1,",.01)=$O(^USC(8932.1,0)),FDA(200.05,"+1,1,",2)=3200101 D UPDATE^DIE("","FDA","","ERR")
S ^XUSEC("PROVIDER",1)=""
S ^XUSEC("LRVERIFY",1)="",^XUSEC("LRLAB",1)="",^XUSEC("LRSUPER",1)=""
W "filing user (want 1): ",$$USER^C0FWENC(),!
H
M

# --- 1f. ISI KIDS build ------------------------------------------------------
if [[ -f "$KID_SRC" ]]; then
  ssh "$HOST" 'mkdir -p /opt/iris/import && chown irisusr:irisusr /opt/iris/import'
  scp -q "$KID_SRC" "$HOST:/opt/iris/import/VISTA_DATALOADER_3P1.KID"
  ssh "$HOST" 'chown irisusr:irisusr /opt/iris/import/VISTA_DATALOADER_3P1.KID && chmod a+r /opt/iris/import/VISTA_DATALOADER_3P1.KID'
  native_m FOIA <<'M'
S DUZ=1,DUZ(0)="@" D DT^DICRW
I $T(+0^ISIIMP12)'="" W "ISI already installed; skipping",! H
I '$D(^%ZIS(1,"C","00")) N FDA,IEN S FDA(3.5,"?+1,",.01)="IRIS-00",FDA(3.5,"?+1,",.02)="IRIS SESSION",FDA(3.5,"?+1,",1)="00",FDA(3.5,"?+1,",2)="VIRTUAL TERMINAL",FDA(3.5,"?+1,",3)="P-OTHER" D UPDATE^DIE("E",$NA(FDA),$NA(IEN))
N DN S DN=+$O(^%ZIS(1,"C","00",0)) I DN S ^%ZIS(1,DN,"TYPE")="VTRM",^%ZIS(1,"G","SYS..00",DN)="",^%ZIS(1,"G","SYS."_$G(^%ZOSF("VOL"))_".00",DN)=""
W "HOME device for 00: ien ",DN,!
H
M
  native_m FOIA <<'M'
S DUZ=1,DUZ(0)="@" D DT^DICRW
I $T(+0^ISIIMP12)'="" H
D ^XPDIL
/opt/iris/import/VISTA_DATALOADER_3P1.KID


H
M
  native_m FOIA <<'M'
S DUZ=1,DUZ(0)="@" D DT^DICRW
I $T(+0^ISIIMP12)'="" W "ISI present after load; installing",!
D ^XPDI
VISTA DATALOADER 3.1
NO
NO
NO



H
M
  native_m FOIA <<'M'
W "ISIIMP12 installed: ",$S($T(+0^ISIIMP12)'="":"yes",1:"NO"),!
H
M
else
  echo "WARN: VISTA_DATALOADER_3P1.KID not found; skipped ISI KIDS install" >&2
fi

# --- 1g. Lab accessioning ----------------------------------------------------
if [[ -f "$LACC_SRC" ]]; then
  ssh "$HOST" 'mkdir -p /opt/iris/import/lacc && chown irisusr:irisusr /opt/iris/import/lacc'
  scp -q "$LACC_SRC" "$HOST:/opt/iris/import/lacc/C0FZLACC.mac"
  ssh "$HOST" 'chown irisusr:irisusr /opt/iris/import/lacc/C0FZLACC.mac && chmod a+r /opt/iris/import/lacc/C0FZLACC.mac'
  native_m FOIA <<'M'
S SC=$SYSTEM.OBJ.ImportDir("/opt/iris/import/lacc","*.mac","ck-d",.ERR,0)
W "C0FZLACC import ok=",SC,!
S DUZ=1,DUZ(0)="@" D DT^DICRW
D EN^C0FZLACC,IDS^C0FZLACC,FIX2^C0FZLACC
D ROLL^C0FZLACC
H
M
else
  echo "WARN: C0FZLACC.mac not found; skipped Lab accessioning config" >&2
fi

# --- 2. self-healing listeners (replaces docker iris-broker.timer) ----------
ssh "$HOST" "WEBPORT='$WEBPORT' BROKERPORT='$BROKERPORT' bash -s" <<'REMOTE'
set -euo pipefail
cat > /usr/local/sbin/iris-listeners.sh <<SH
#!/bin/bash
# Keep the RPC broker and the M-Web-Server listener up. Idempotent.
# Do not use "iris list | grep -q" under pipefail: grep -q closes the pipe
# early, iris list dies with SIGPIPE, and the script skips the start.
set -euo pipefail
list=\$(/usr/irissys/bin/iris list 2>/dev/null || true)
grep -q 'status:.*running' <<<"\$list" || exit 0
ports=\$(ss -lnt || true)
if ! grep -q ':${BROKERPORT} ' <<<"\$ports"; then
  /usr/local/sbin/iris-session.sh FOIA <<'M' >/dev/null 2>&1 || true
J LISTEN^%ZISTCPS(${BROKERPORT},"NT^XWBTCPM")
H
M
fi
ports=\$(ss -lnt || true)
if ! grep -q ':${WEBPORT} ' <<<"\$ports"; then
  /usr/local/sbin/iris-session.sh FOIA <<'M' >/dev/null 2>&1 || true
D job^%webreq(${WEBPORT})
H
M
fi
SH
chmod 700 /usr/local/sbin/iris-listeners.sh

cat > /etc/systemd/system/iris-listeners.service <<UNIT
[Unit]
Description=Ensure VistA RPC broker (${BROKERPORT}) and FHIR listener (${WEBPORT})
After=iris.service
Requires=iris.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/iris-listeners.sh
UNIT

cat > /etc/systemd/system/iris-listeners.timer <<UNIT
[Unit]
Description=Periodically ensure VistA listeners on native IRIS
[Timer]
OnBootSec=20
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT

# Earlier hand-written oneshots, if present, would race this timer.
systemctl disable iris-fhir-listener.service iris-rpc-broker.service >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable --now iris-listeners.timer
systemctl start iris-listeners.service
sleep 2
ss -lnt | grep -q ':${WEBPORT} ' && echo "web listening on ${WEBPORT}" || { echo "ERROR: web not listening on ${WEBPORT}" >&2; exit 1; }
ss -lnt | grep -q ':${BROKERPORT} ' && echo "broker listening on ${BROKERPORT}" || { echo "ERROR: broker not listening on ${BROKERPORT}" >&2; exit 1; }
REMOTE

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "http://${HOSTNAME_ONLY}:${WEBPORT}/fhir/metadata" || echo 000)"
[[ "$code" == "200" ]] && echo "fhir/metadata HTTP 200 from outside" \
  || { echo "ERROR: fhir/metadata HTTP $code from outside" >&2; exit 1; }
echo "iris-native web complete: http://${HOSTNAME_ONLY}:${WEBPORT}/"
echo "next: public.sh then c0x.sh"
