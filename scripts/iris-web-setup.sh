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
ZN \"%SYS\"
K P S P(\"Database\")=\"FOIA\"
S SC=##class(Config.MapRoutines).Create(\"FOIA\",\"%WC\",.P)
W \"%WC mapping: \",\$S(+SC=1:\"created\",1:\"exists/err (ok if exists)\"),!
S SC=##class(Security.SSLConfigs).Create(\"C0SSL\")
W \"C0SSL config: \",\$S(+SC=1:\"created\",1:\"exists/err (ok if exists)\"),!
ZN \"FOIA\"
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
# SYNVPR (gtree/VPR views), SYNFHF (CarePlan health-factor filing),
# graphmap^SYNGRAPH (LOINC lab-map), etc.
#
# Two IRIS-only conversion rules (2026-09-11):
#  1. Force each .mac first code line's label to the routine name. GT.M keys a
#     routine by filename regardless of the first-line label, but IRIS makes a
#     routine whose first-line label differs from its name UNENTERABLE
#     (calling any $$label^RTN throws <SUBSCRIPT>/<COMMAND>). Two SYN files
#     trip this: SYNGRAPH (label SYNFGRAPH) and SYNHTM (label %yottahtm).
#  2. Compile in TWO passes. Several SYN routines fail to compile on the first
#     pass due to inter-routine ordering (e.g. SYNGRAPH before its deps); a
#     second ImportDir resolves them. After pass 2 only SYNYOTTA (YottaDB ZWR),
#     SYNLINIT, and SYNWEBUT's two GT.M-guarded "tstart ():serial" lines remain
#     (all non-blocking; SYNWEBUT ENCODE64/DECODE64 still work).
SYN_SRC="$(cd "$(dirname "$0")/../../VistA-FHIR-Data-Loader/src" 2>/dev/null && pwd || true)"
if [[ -n "$SYN_SRC" && -f "$SYN_SRC/SYNWEBUT.m" ]]; then
  tar -czf /tmp/syn-src.tgz -C "$SYN_SRC" $(cd "$SYN_SRC" && ls SYN*.m)
  scp -q /tmp/syn-src.tgz "$HOST:/tmp/"
  ssh -o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 "$HOST" "
mkdir -p /opt/iris/durable/import/syn /opt/iris/durable/import/syn-mac
rm -f /opt/iris/durable/import/syn/*.m /opt/iris/durable/import/syn-mac/*.mac
tar -C /opt/iris/durable/import/syn -xzf /tmp/syn-src.tgz
for f in /opt/iris/durable/import/syn/*.m; do b=\$(basename \"\$f\" .m); awk -v n=\"\$b\" 'NR==1{sub(/^[^ \t;]+/, n)} {print}' \"\$f\" > /tmp/synfix.m; printf 'ROUTINE %s [Type=MAC]\n' \"\$b\" | cat - /tmp/synfix.m > /opt/iris/durable/import/syn-mac/\$b.mac; done
docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
K ERR S SC=\$SYSTEM.OBJ.ImportDir(\"/durable/import/syn-mac\",\"*.mac\",\"ck-d\",.ERR,0)
K ERR S SC=\$SYSTEM.OBJ.ImportDir(\"/durable/import/syn-mac\",\"*.mac\",\"ck-d\",.ERR,0)
N K,C S (K,C)=\"\" S C=0 F  S K=\$O(ERR(K)) Q:K=\"\"  S C=C+1
W \"SYN compile errors after 2 passes: \",C,\" (expect ~3: SYNYOTTA/SYNLINIT/SYNWEBUT)\",!
W \"SYN base64 check: \",\$\$ENCODE64^SYNWEBUT(\"ok\"),!
W \"SYNGRAPH enterable: \",\$S(\$T(graphmap^SYNGRAPH)'=\"\":\"yes\",1:\"NO\"),!
H
EOF"
else
  echo "WARN: ../VistA-FHIR-Data-Loader/src not found; skipped SYN routine import" >&2
fi

# --- 1d. rehmp C0RG gateway routines (sibling rehmp repo) --------------------
# POST /rehmp (WSREHMP^C0RGWEB -> HTTP^C0RGAPI) needs the C0RG set; SYNWEBRG
# registers the rehmp routes only when these are present. Re-register routes
# afterward and set the quality re-eval FHIR base (cds1 fetches {base}?dfn=N —
# it must include /fhir).
C0RG_SRC="$(cd "$(dirname "$0")/../../rehmp/C0RG" 2>/dev/null && pwd || true)"
if [[ -n "$C0RG_SRC" && -f "$C0RG_SRC/C0RGAPI.m" ]]; then
  tar -czf /tmp/c0rg-src.tgz -C "$C0RG_SRC" $(cd "$C0RG_SRC" && ls *.m)
  scp -q /tmp/c0rg-src.tgz "$HOST:/tmp/"
  ssh "$HOST" "
mkdir -p /opt/iris/durable/import/rehmp-src /opt/iris/durable/import/rehmp
rm -f /opt/iris/durable/import/rehmp-src/*.m /opt/iris/durable/import/rehmp/*.mac
tar -C /opt/iris/durable/import/rehmp-src -xzf /tmp/c0rg-src.tgz
for f in /opt/iris/durable/import/rehmp-src/*.m; do b=\$(basename \"\$f\" .m); printf 'ROUTINE %s [Type=MAC]\n' \"\$b\" | cat - \"\$f\" > /opt/iris/durable/import/rehmp/\$b.mac; done
docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
K ERR S SC=\$SYSTEM.OBJ.ImportDir(\"/durable/import/rehmp\",\"*.mac\",\"ck-d\",.ERR,0)
N K,C S (K,C)=\"\" S C=0 F  S K=\$O(ERR(K)) Q:K=\"\"  S C=C+1
W \"c0rg import errors: \",C,!
D EN^SYNWEBRG
N C,I S C=0,I=0 F  S I=\$O(^%web(17.6001,I)) Q:'I  S C=C+1
W \"routes after c0rg: \",C,!
S ^C0FQUAL(\"FHIRBASE\")=\"https://${HOST#*@}/fhir\"
W \"FHIRBASE: \",^C0FQUAL(\"FHIRBASE\"),!
H
EOF"
else
  echo "WARN: ../rehmp/C0RG not found; skipped C0RG import" >&2
fi

# --- 1e. loader environment init (one-time data; a snapshot restore keeps it,
# but a PRISTINE image has none of it) ----------------------------------------
# Mirrors what EN^SYNINIT does at KIDS install time on the GT.M fleet images,
# minus two steps that break on the FOIA image:
#   * HL^SYNINIT     — crashes in VISN^SDTMPHLB (^DIC(4,1,7,1,0) absent);
#                      C0FW encounter filing does not need the generic location.
#   * ACRPBUL^SYNINIT — DIERR on FOIA; bulletin noise only.
# SYNMENU must exist first (PROV points field 201 at it; the loader's KIDS
# build normally creates it). EN^SYNGBLLD builds the ^SYN("2002.030") mapping
# globals (sct2os5 etc.) that PRCADD^SYNDHP65 needs. Finally make USER,ONE
# (DUZ 1) provider-capable so notes file as a real user instead of POSTMASTER.
# Every piece checks before creating, so this step is idempotent.
ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
D ENVINIT^C0FHIR
I \$\$FIND1^DIC(19,\"\",\"QX\",\"SYNMENU\",\"B\")<1 N FDA,IEN S FDA(19,\"?+1,\",.01)=\"SYNMENU\",FDA(19,\"?+1,\",1)=\"Synthea Loader Menu\",FDA(19,\"?+1,\",4)=\"M\" D UPDATE^DIE(\"E\",\$NA(FDA),\$NA(IEN))
W \"syn provider: \",\$\$PROV^SYNINIT(0),!
W \"syn pharmacist: \",\$\$PHARM^SYNINIT(0),!
D AMIE^SYNINIT
D IBACTION^SYNINIT
W \"pharmacy site: \",\$\$PSOSITE^SYNINIT(),!
D ALBUL^SYNINIT
D EN^SYNGBLLD
W \"sct2os5 map: \",\$S(\$D(^SYN(\"2002.030\",\"sct2os5\",\"direct\")):\"built\",1:\"MISSING\"),!
I '\$\$ACTIVEPC^C0FWENC(1) N FDA,ERR S FDA(200.05,\"+1,1,\",.01)=\$O(^USC(8932.1,0)),FDA(200.05,\"+1,1,\",2)=3200101 D UPDATE^DIE(\"\",\"FDA\",\"\",\"ERR\")
S ^XUSEC(\"PROVIDER\",1)=\"\"
S ^XUSEC(\"LRVERIFY\",1)=\"\",^XUSEC(\"LRLAB\",1)=\"\",^XUSEC(\"LRSUPER\",1)=\"\"
W \"filing user (want 1): \",\$\$USER^C0FWENC(),!
H
EOF"

# --- 1f. ISI VistA DataLoader KIDS build (labs into #60/#63 via ISIIMP12) ----
# The SYN lab filer (LABADD^SYNDHP63) calls $$LAB^ISIIMP12, which ships in the
# ISI VistA DataLoader 3.1 KIDS distribution — not present on the FOIA image.
# Installing it headlessly on IRIS needs one prerequisite the GT.M fleet never
# does: a HOME device. A piped `iris session` has principal device "00", which
# HOME^%ZIS resolves through the sign-on/virtual-terminal path
# (^%ZIS(1,"G","SYS..<$I>") + field TYPE="VTRM"); the stock device file has no
# such entry, so KIDS aborts with "HOME DEVICE (00) DOES NOT EXIST". We create
# a VTRM device for "00" (idempotent) so ^XPDIL/^XPDI can run.
# NOTE: filing labs end-to-end ALSO needs VistA Lab accessioning configured
# (accession areas per #60 test + the LRTASK ROLLOVER) — a separate Lab-package
# setup the FOIA image lacks; without it most tests fail "no appropriate
# accession area". This step gets ISIIMP12 present and the import path live.
KID_SRC="$(cd "$(dirname "$0")/../../VistA-DataLoader/VistA" 2>/dev/null && pwd || true)"
if [[ -n "$KID_SRC" && -f "$KID_SRC/VISTA_DATALOADER_3P1.KID" ]]; then
  scp -q "$KID_SRC/VISTA_DATALOADER_3P1.KID" "$HOST:/opt/iris/durable/import/"
  ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
S DUZ=1,DUZ(0)=\"@\" D DT^DICRW
I \$T(+0^ISIIMP12)'=\"\" W \"ISI already installed; skipping\",! H
; ensure a HOME device for principal \$I=\"00\" (virtual terminal)
I '\$D(^%ZIS(1,\"C\",\"00\")) N FDA,IEN S FDA(3.5,\"?+1,\",.01)=\"IRIS-00\",FDA(3.5,\"?+1,\",.02)=\"IRIS SESSION\",FDA(3.5,\"?+1,\",1)=\"00\",FDA(3.5,\"?+1,\",2)=\"VIRTUAL TERMINAL\",FDA(3.5,\"?+1,\",3)=\"P-OTHER\" D UPDATE^DIE(\"E\",\$NA(FDA),\$NA(IEN))
N DN S DN=+\$O(^%ZIS(1,\"C\",\"00\",0)) I DN S ^%ZIS(1,DN,\"TYPE\")=\"VTRM\",^%ZIS(1,\"G\",\"SYS..00\",DN)=\"\",^%ZIS(1,\"G\",\"SYS.\"_\$G(^%ZOSF(\"VOL\"))_\".00\",DN)=\"\"
W \"HOME device for 00: ien \",DN,!
H
EOF"
  # load + install (fresh session so HOME re-resolves via the new device)
  ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
S DUZ=1,DUZ(0)=\"@\" D DT^DICRW
I \$T(+0^ISIIMP12)'=\"\" H
D ^XPDIL
/durable/import/VISTA_DATALOADER_3P1.KID


H
EOF"
  ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
S DUZ=1,DUZ(0)=\"@\" D DT^DICRW
I \$T(+0^ISIIMP12)'=\"\" W \"ISI present after load; installing\",!
D ^XPDI
VISTA DATALOADER 3.1
NO
NO
NO



H
EOF"
  ssh "$HOST" "docker exec -i $NAME iris session IRIS -U FOIA <<'EOF'
W \"ISIIMP12 installed: \",\$S(\$T(+0^ISIIMP12)'=\"\":\"yes\",1:\"NO\"),!
H
EOF"
else
  echo "WARN: ../VistA-DataLoader/VistA/VISTA_DATALOADER_3P1.KID not found; skipped ISI KIDS install" >&2
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
