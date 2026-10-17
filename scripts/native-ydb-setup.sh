#!/usr/bin/env bash
# native-ydb-setup.sh — bare-metal YottaDB + VEHU + FHIR stack on native.vistaplex.org.
#
# The host does not run Docker. A one-shot container on this workstation is
# only how stock worldvista/vehu:latest is read. See
# docs/native/NATIVE_YDB_INSTALL.md.
#
#   scripts/native-ydb-setup.sh host|build|extract|load|install|caddy|smoke|all
#
# Env:
#   NATIVE_SSH            default root@native.vistaplex.org
#   NATIVE_DOMAIN         default native.vistaplex.org
#   NATIVE_YDB_URL        default https://gitlab.com/nars1/YDB.git
#   NATIVE_YDB_REF        default indrfast_ydb1278
#   NATIVE_YDB_COMMIT     default 80f2b92d29f14234eabb89b81b1c089b28facc31
#                         empty = branch tip
#   NATIVE_YDB_PREFIX     default /opt/yottadb/native
#   NATIVE_YDB_REBUILD=1  compile even if that commit is already installed
#   NATIVE_EXTRACT_DIR    default /tmp/native-vehu-extract
#   NATIVE_IMAGE          default worldvista/vehu:latest
#   NATIVE_LOAD_FORCE=1   replace an existing /home/vehu/g/vehu.dat
#   NATIVE_ENCODER        default JSNE
#   NATIVE_LOAD=1         after smoke, run the showfhir population loads
#   NATIVE_LOAD_BASE      default https://$NATIVE_DOMAIN. Bulk loads should
#                         use http://127.0.0.1:9080 on the host (Caddy aborts).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REHMP_ROOT="${REHMP_ROOT:-$ROOT/../rehmp}"
LOADER_ROOT="${LOADER_ROOT:-$ROOT/../VistA-FHIR-Data-Loader}"
C0T_SRC="${C0T_ROUTINES_DIR:-$ROOT/../C0T-terminology-gateway/routines}"
C0X_ROOT="${C0X_ROOT:-$ROOT/../fhir-triple-store}"
QT_ROOT="${QT_ROOT:-$ROOT/../HL7-FHIR-quality-testing}"
JOHN="${JOHN_SALT_BUNDLE:-$ROOT/../WVEHR-on-FHIR/bundles/JOHN-SALT.json}"

HOST="${NATIVE_SSH:-root@native.vistaplex.org}"
DOMAIN="${NATIVE_DOMAIN:-native.vistaplex.org}"
YDB_URL="${NATIVE_YDB_URL:-https://gitlab.com/nars1/YDB.git}"
YDB_REF="${NATIVE_YDB_REF:-indrfast_ydb1278}"
YDB_COMMIT="${NATIVE_YDB_COMMIT:-80f2b92d29f14234eabb89b81b1c089b28facc31}"
YDB_PREFIX="${NATIVE_YDB_PREFIX:-/opt/yottadb/native}"
EXTRACT_DIR="${NATIVE_EXTRACT_DIR:-/tmp/native-vehu-extract}"
IMAGE="${NATIVE_IMAGE:-worldvista/vehu:latest}"
ENCODER="${NATIVE_ENCODER:-JSNE}"
PHASE="${1:-all}"

case "$HOST" in
  *showfhir*|*fhirdev*|*devfhir*|*wvehr*|*fhir.vistaplex*|*iris2*|*rpmsfhir*)
    echo "refusing $HOST — this script is for the native lane only" >&2
    exit 2 ;;
esac

SSHCTL="/tmp/ssh-native-ydb-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=25 -o ConnectionAttempts=15 \
  -o StrictHostKeyChecking=accept-new \
  -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=300)
ssh() { command ssh "${SSHMUX[@]}" "$@"; }
scp() { command scp "${SSHMUX[@]}" "$@"; }
cleanup() { command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true; }
trap cleanup EXIT

routine_files() {
  ls "$LOADER_ROOT"/src/SYN*.m
  ls "$ROOT"/vendor/m-web-server/src/*.m "$ROOT"/vendor/m-wc/src/*.m "$ROOT"/src/*.m
  [[ -f "$ROOT/SYNWEBUT.m" ]] && echo "$ROOT/SYNWEBUT.m"
  ls "$REHMP_ROOT"/C0RG/*.m
  ls "$C0T_SRC"/C0TAPI.m "$C0T_SRC"/C0TLEX.m "$C0T_SRC"/C0TBSTS.m 2>/dev/null
  ls "$C0X_ROOT"/src/C0X*.m
}
routine_names() { routine_files | xargs -n1 basename | sed 's/\.m$//' | sort -u; }

phase_host() {
  echo "==> host packages, swap, vehu user"
  ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
dnf install -y dnf-plugins-core ca-certificates rsync gcc gcc-c++ make cmake git \
  gawk bison flex tcsh wget readline-devel ncurses-devel libicu-devel \
  openssl-devel elfutils-libelf-devel libgcrypt-devel zlib-devel pkgconf-pkg-config
dnf config-manager --set-enabled crb
dnf install -y epel-release || true
dnf install -y jansson-devel libconfig-devel gpgme-devel
id vehu >/dev/null 2>&1 || useradd -m -s /bin/bash vehu
install -d -o vehu -g vehu /home/vehu/g /home/vehu/j /home/vehu/r /home/vehu/p \
  /home/vehu/s /home/vehu/log /home/vehu/tmp /home/vehu/etc /home/vehu/lib \
  /home/vehu/www /home/vehu/lib/c0rgenc
if systemctl is-active firewalld >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
fi
echo "HOST OK \$(free -h | awk '/Swap/{print \$2}') swap"
REMOTE
}

phase_build() {
  echo "==> compile YottaDB on $HOST ($YDB_REF ${YDB_COMMIT:-tip})"
  ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
PREFIX='$YDB_PREFIX'
URL='$YDB_URL'
REF='$YDB_REF'
COMMIT='$YDB_COMMIT'
REBUILD='${NATIVE_YDB_REBUILD:-0}'
if [[ "\$REBUILD" != 1 ]]; then
  BIN=\$(find "\$PREFIX" -type f -name yottadb -print -quit 2>/dev/null || true)
  if [[ -n "\$BIN" && -n "\$COMMIT" ]] && "\$BIN" -version | grep -q "\$COMMIT"; then
    echo "BUILD OK already \$COMMIT"
    exit 0
  fi
fi
rm -rf /usr/local/src/ydb-native /tmp/ydb-native-build
git clone --depth 1 -b "\$REF" "\$URL" /usr/local/src/ydb-native
if [[ -n "\$COMMIT" ]]; then
  git -C /usr/local/src/ydb-native fetch --depth 1 origin "\$COMMIT"
  git -C /usr/local/src/ydb-native checkout --detach "\$COMMIT"
fi
cmake -S /usr/local/src/ydb-native -B /tmp/ydb-native-build \
  -D CMAKE_INSTALL_PREFIX="\$PREFIX" -D CMAKE_BUILD_TYPE=Release
cmake --build /tmp/ydb-native-build -j 2
cmake --install /tmp/ydb-native-build
BIN=\$(find "\$PREFIX" -type f -name yottadb -print -quit)
DIST=\$(dirname "\$BIN")
ln -sfn yottadb "\$DIST/mumps"
cp /tmp/ydb-native-build/gdedefaults.gtc "\$DIST/gdedefaults"
# First use compiles the utility .m files. Do that as root; vehu cannot write here.
chmod a+rX "\$DIST" "\$DIST"/*
(
  cd "\$DIST"
  export ydb_dist="\$DIST" gtm_dist="\$DIST" ydb_chset=M gtm_chset=M
  export ydb_routines="\$DIST" gtmroutines="\$DIST"
  export ydb_gbldir="\$DIST/gdehelp.gld"
  export gtmgbldir="\$ydb_gbldir"
  for src in *.m; do
    "\$DIST/yottadb" -run %XCMD "ZLINK \"\${src%.m}\""
  done
)
echo "BUILD OK"
"\$BIN" -version
REMOTE
}

phase_extract() {
  echo "==> extract stock $IMAGE (workstation docker, read only)"
  if [[ -f "$EXTRACT_DIR/default.zwr" && -f "$EXTRACT_DIR/routines.tgz" && "${NATIVE_EXTRACT_REBUILD:-0}" != 1 ]]; then
    echo "EXTRACT OK reuse $EXTRACT_DIR"
    return
  fi
  mkdir -p "$EXTRACT_DIR"
  docker rm -f native-vehu-src >/dev/null 2>&1 || true
  docker run -d --name native-vehu-src --entrypoint sleep "$IMAGE" infinity >/dev/null
  docker exec -i native-vehu-src bash -lc 'cat > /tmp/extract-vehu.sh && chmod +x /tmp/extract-vehu.sh && su - vehu -c /tmp/extract-vehu.sh' <<'EOS'
#!/bin/bash
set -euo pipefail
source /home/vehu/etc/env
mkdir -p /tmp/zwr
mupip extract -format=zwr -region=DEFAULT /tmp/zwr/default.zwr
# AIM is empty on stock VEHU. mupip exits 224 with NOSELECT.
mupip extract -format=zwr -region=AIM /tmp/zwr/aim.zwr || rm -f /tmp/zwr/aim.zwr
mupip extract -format=zwr -region=OCTO /tmp/zwr/octo.zwr
tar -C /home/vehu -czf /tmp/zwr/routines.tgz --exclude='*.o' r
echo EXTRACT_DONE
EOS
  docker cp native-vehu-src:/tmp/zwr/. "$EXTRACT_DIR/"
  docker rm -f native-vehu-src >/dev/null
  ls -lh "$EXTRACT_DIR"
  echo "EXTRACT OK"
}

phase_load() {
  echo "==> load extract onto $HOST"
  [[ -f "$EXTRACT_DIR/default.zwr" ]] || { echo "missing $EXTRACT_DIR/default.zwr — run extract" >&2; exit 1; }
  ssh "$HOST" 'mkdir -p /var/tmp/native-vehu-extract'
  rsync -a --info=stats2 "$EXTRACT_DIR"/default.zwr "$EXTRACT_DIR"/octo.zwr \
    "$EXTRACT_DIR"/routines.tgz "$HOST":/var/tmp/native-vehu-extract/
  if [[ -f "$EXTRACT_DIR/aim.zwr" ]]; then
    rsync -a "$EXTRACT_DIR"/aim.zwr "$HOST":/var/tmp/native-vehu-extract/
  fi
  ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
PREFIX='$YDB_PREFIX'
FORCE='${NATIVE_LOAD_FORCE:-0}'
if [[ -f /home/vehu/g/vehu.dat && "\$FORCE" != 1 ]]; then
  echo "vehu.dat exists; set NATIVE_LOAD_FORCE=1 to replace it" >&2
  exit 1
fi
BIN=\$(find "\$PREFIX" -type f -name yottadb -print -quit)
[[ -n "\$BIN" ]] || { echo "yottadb not installed under \$PREFIX" >&2; exit 1; }
DIST=\$(dirname "\$BIN")
cat > /home/vehu/etc/env <<'EOF'
export ydb_dist=YDBDIST
export gtm_dist=YDBDIST
export ydb_chset=M
export gtm_chset=M
export ydb_gbldir=/home/vehu/g/vehu.gld
export gtmgbldir=/home/vehu/g/vehu.gld
export ydb_lct_stdnull=1
export gtm_lct_stdnull=1
export ydb_lvnullsubs=2
export gtm_lvnullsubs=2
export ydb_zquit_anyway=1
export gtm_zquit_anyway=1
export ydb_statshare=1
export gtm_statshare=1
export ydb_readline=1
export ydb_log=/home/vehu/log
export ydb_tmp=/home/vehu/tmp
export gtm_log=/home/vehu/log
export gtm_tmp=/home/vehu/tmp
export ydb_linktmpdir=/home/vehu/tmp
export ydb_prompt="VEHU>"
export gtm_prompt="VEHU>"
export ydb_zinterrupt='I \$\$JOBEXAM^ZU(\$ZPOSITION)'
export gtm_zinterrupt='I \$\$JOBEXAM^ZU(\$ZPOSITION)'
export PATH=\$ydb_dist:\$PATH
export ydb_routines="/home/vehu/p/o*(/home/vehu/p) /home/vehu/r/o*(/home/vehu/r) \$ydb_dist"
export gtmroutines="\$ydb_routines"
EOF
sed -i "s|YDBDIST|\$DIST|g" /home/vehu/etc/env
chown vehu:vehu /home/vehu/etc/env
rm -f /home/vehu/g/vehu.dat /home/vehu/g/aim.dat /home/vehu/g/octo.dat /home/vehu/g/temp.dat /home/vehu/g/vehu.gld
tar -C /home/vehu -xzf /var/tmp/native-vehu-extract/routines.tgz
mkdir -p /home/vehu/p/o /home/vehu/r/o
chown -R vehu:vehu /home/vehu/r /home/vehu/p /home/vehu/g
su - vehu -c 'bash -s' <<'VEHU'
set -euo pipefail
source /home/vehu/etc/env
cd /home/vehu/g
"\$ydb_dist/yottadb" -run GDE <<'GDE'
change -segment DEFAULT -block_size=4096 -allocation=900000 -extension=100000 -global_buffer_count=1024 -file_name=/home/vehu/g/vehu.dat
change -region DEFAULT -record_size=16368 -key_size=1019 -null_subscripts=NEVER -nojournal
add -segment TEMP -file_name=/home/vehu/g/temp.dat -block_size=4096 -allocation=5000 -extension=5000
add -region TEMP -dynamic_segment=TEMP -record_size=16368 -key_size=1019 -null_subscripts=NEVER -nojournal
add -name BMXTMP -region=TEMP
add -name CacheTemp* -region=TEMP
add -name DISV -region=TEMP
add -name DOSV -region=TEMP
add -name HLTMP -region=TEMP
add -name KMPTMP -region=TEMP
add -name SPOOL -region=TEMP
add -name TEMP -region=TEMP
add -name TMP -region=TEMP
add -name UTILITY -region=TEMP
add -name VPRHTTP -region=TEMP
add -name XTMP -region=TEMP
add -name XUTL -region=TEMP
add -segment AIM -file_name=/home/vehu/g/aim.dat -block_size=2048 -allocation=20000 -extension=20000
add -region AIM -dynamic_segment=AIM -record_size=1048576 -key_size=1019 -null_subscripts=ALWAYS -nojournal
add -name %ydbAIM* -region=AIM
add -segment OCTO -file_name=/home/vehu/g/octo.dat -block_size=2048 -allocation=80000 -extension=20000
add -region OCTO -dynamic_segment=OCTO -record_size=1048576 -key_size=1019 -null_subscripts=ALWAYS -nojournal
add -name %ydbocto* -region=OCTO
exit
GDE
mupip create
mupip load /var/tmp/native-vehu-extract/default.zwr
if [[ -s /var/tmp/native-vehu-extract/aim.zwr ]]; then
  mupip load /var/tmp/native-vehu-extract/aim.zwr
fi
mupip load /var/tmp/native-vehu-extract/octo.zwr
yottadb -run %XCMD 'W "REL=",\$ZYRELEASE,!,"PAT=",\$O(^DPT(0)),!'
VEHU
echo LOAD OK
REMOTE
}

phase_install() {
  echo "==> FHIR stack into /home/vehu/p (encoder=$ENCODER)"
  local stage
  stage="$(mktemp -d)"
  while IFS= read -r f; do
    cp -f "$f" "$stage/"
  done < <(routine_files)
  rsync -a "$stage"/ "$HOST":/home/vehu/p/
  rm -rf "$stage"
  rsync -a "$REHMP_ROOT/plugin/c0rgenc/" "$HOST":/tmp/c0rgenc-src/
  ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
touch /home/vehu/p/*.m
chown -R vehu:vehu /home/vehu/p /tmp/c0rgenc-src
grep -q GTMXC_c0rgenc /home/vehu/etc/env || cat >> /home/vehu/etc/env <<'EOF'
export GTMXC_c0rgenc=/home/vehu/lib/c0rgenc/c0rgenc.xc
export ydb_xc_c0rgenc=/home/vehu/lib/c0rgenc/c0rgenc.xc
EOF
su - vehu -c 'bash -s' <<'VEHU'
set -euo pipefail
source /home/vehu/etc/env
cd /tmp/c0rgenc-src
gcc -O2 -fPIC -shared -Wall -I"\$ydb_dist" -o /home/vehu/lib/c0rgenc/libc0rgenc.so \
  c0rgenc.c c0rgenc_mem.c c0rgenc_flat.c c0rgenc_zw.c c0rgenc_ydb.c
{ echo /home/vehu/lib/c0rgenc/libc0rgenc.so; tail -n +2 c0rgenc.xc; } \
  > /home/vehu/lib/c0rgenc/c0rgenc.xc
VEHU
REMOTE
  {
    routine_names | while read -r r; do
      printf 'W "@@%s",!\nZLINK "%s"\n' "$r" "$r"
    done
    printf '%s\n' 'W "@@setup",!' 'D EN^C0RGSE' 'D REG^C0XWS' 'D EN^SYNWEBRG' \
      'S ^%webhome="/home/vehu/www/"' \
      'D LOADOS5^SYNOS5LD' 'D EN^SYNOS5PT' \
      'S ^C0FHIR("EXPERIMENT","GRAPHLABS")=1' \
      "D SET^C0RGPAR(\"ENCODER\",\"$ENCODER\")" \
      'W "OS5=",$$COUNT^SYNOS5LD,!,"GRAPHLABS=",$$ON^C0FHIRLG(),!,"ENCODER=",$$GETPAR^C0RGPAR("ENCODER"),!,"PING=",$&c0rgenc.ping,!,"HOME=",^%webhome,!' \
      'H'
  } | ssh "$HOST" "su - vehu -c 'source /home/vehu/etc/env && cd /home/vehu/tmp && yottadb -direct'" \
    | tee /tmp/native-ydb-link.$$ 
  grep -q "ENCODER=$ENCODER" /tmp/native-ydb-link.$$
  grep -q 'PING=1' /tmp/native-ydb-link.$$
  grep -q 'GRAPHLABS=1' /tmp/native-ydb-link.$$
  rm -f /tmp/native-ydb-link.$$

  ssh "$HOST" 'bash -s' <<'UNIT'
set -euo pipefail
cat > /etc/systemd/system/vehu-webreq.service <<'EOF'
[Unit]
Description=VEHU M-Web-Server on 9080
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=vehu
WorkingDirectory=/home/vehu/tmp
ExecStart=/bin/bash -lc 'source /home/vehu/etc/env && yottadb -run %%XCMD "do job^%%webreq(9080)"'
ExecStop=/bin/bash -lc 'source /home/vehu/etc/env && yottadb -run %%XCMD "do stop^%%webreq"'
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vehu-webreq.service
systemctl restart vehu-webreq.service
UNIT
  echo "INSTALL OK"
}

phase_caddy() {
  echo "==> Caddy for $DOMAIN"
  local cprs="$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo/dist"
  if [[ ! -f "$cprs/index.html" ]]; then
    (cd "$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo" && npm ci --silent && npm run build)
  fi
  tar -czf /tmp/native-cprs.tgz -C "$cprs" .
  scp -q /tmp/native-cprs.tgz "$HOST:/tmp/native-cprs.tgz"
  ssh "$HOST" "mkdir -p /home/vehu/www/filesystem/tjson/web /home/vehu/www/filesystem/c0x /var/www/rehmp/dist/demos/cprs"
  rsync -a -e "ssh -o BatchMode=yes" "$ROOT/vendor/tjson/web/" "$HOST:/home/vehu/www/filesystem/tjson/web/"
  scp -q "$C0X_ROOT/ui/index.html" "$C0X_ROOT/ui/app.js" "$C0X_ROOT/ui/styles.css" \
    "$HOST:/home/vehu/www/filesystem/c0x/"
  ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
DOMAIN='$DOMAIN'
if ! command -v caddy >/dev/null 2>&1; then
  curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/config.rpm.txt' -o /etc/yum.repos.d/caddy-stable.repo
  dnf install -y caddy
fi
mkdir -p /var/www/rehmp/dist/c0x /var/www/rehmp/dist/demos/cprs
tar -C /var/www/rehmp/dist/demos/cprs -xzf /tmp/native-cprs.tgz
cp -f /home/vehu/www/filesystem/c0x/index.html /home/vehu/www/filesystem/c0x/app.js /home/vehu/www/filesystem/c0x/styles.css /var/www/rehmp/dist/c0x/
chown -R vehu:vehu /home/vehu/www
if [[ ! -f /var/www/rehmp/dist/index.html ]]; then
  cat > /var/www/rehmp/dist/index.html <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>native</title></head>
<body><h1>native.vistaplex.org</h1>
<p><a href="/fhir">/fhir</a> · <a href="/demos/cprs/">CPRS demo</a> · <a href="/fhir/metadata">metadata</a></p>
</body></html>
HTML
fi
chmod -R a+rX /var/www/rehmp
# Caddy is confined. A copied tree is var_t and the file server returns 403.
if [[ "$(getenforce 2>/dev/null || true)" == Enforcing ]]; then
  ctx='/var/www/rehmp(/.*)?'
  f=/etc/selinux/targeted/contexts/files/file_contexts.local
  grep -q '/var/www/rehmp' "$f" 2>/dev/null || echo "$ctx    system_u:object_r:httpd_sys_content_t:s0" >> "$f"
  restorecon -R /var/www/rehmp || chcon -R -t httpd_sys_content_t /var/www/rehmp
fi
cat > /etc/caddy/Caddyfile <<CADDY
\${DOMAIN} {
	encode zstd gzip
	@c0x_ui path /c0x /c0x/ /c0x/index.html /c0x/app.js /c0x/styles.css
	handle @c0x_ui {
		root * /var/www/rehmp/dist
		rewrite /c0x /c0x/index.html
		rewrite /c0x/ /c0x/index.html
		file_server
	}
	redir /filesystem/c0x /c0x/ 308
	redir /filesystem/c0x/ /c0x/ 308
	redir /filesystem/c0x/index.html /c0x/ 308
	@m_api path /c0x* /fhir* /altfhir* /rehmp* /vpr* /filesystem* /tfhir* /showfhir* /tiustats* /tiuvpatients* /addpatient* /updatepatient* /aiconsult* /loadstatus* /gtree* /global* /graph* /writebacksaves* /problemselection* /ping*
	handle @m_api {
		reverse_proxy 127.0.0.1:9080 {
			header_up X-Forwarded-Proto {scheme}
			header_up X-Forwarded-Host {host}
			transport http {
				dial_timeout 30s
				response_header_timeout 300s
				read_timeout 300s
				write_timeout 300s
			}
		}
	}
	root * /var/www/rehmp/dist
	handle /demos/cprs/* {
		try_files {path} {path}/index.html /demos/cprs/index.html
		file_server
	}
	handle /demos/* {
		try_files {path} {path}/index.html /demos/index.html
		file_server
	}
	handle {
		try_files {path} /index.html
		file_server
	}
}
CADDY
caddy validate --config /etc/caddy/Caddyfile
systemctl enable caddy
systemctl restart caddy
systemctl is-active caddy
REMOTE
  echo "CADDY OK"
}

phase_smoke() {
  echo "==> smoke"
  local i code=""
  for i in $(seq 1 30); do
    code="$(ssh "$HOST" "curl -sS -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:9080/fhir/metadata" || true)"
    [[ "$code" == 200 ]] && break
    sleep 2
  done
  [[ "$code" == 200 ]] || { echo "local metadata HTTP $code" >&2; exit 1; }
  ssh "$HOST" "su - vehu -c 'source /home/vehu/etc/env && yottadb -direct'" <<'M'
W "REL=",$ZYRELEASE,!,"ENCODER=",$$GETPAR^C0RGPAR("ENCODER"),!
H
M
  curl -sS -m 30 -o /dev/null -w "public_meta=%{http_code}\n" "https://$DOMAIN/fhir/metadata"
  echo "SMOKE OK"
}

phase_population() {
  [[ "${NATIVE_LOAD:-0}" == 1 ]] || return 0
  echo "==> population loads (same order as showfhir)"
  local outdir=/tmp/native-ydb-loads
  mkdir -p "$outdir"
  local man180="$outdir/synthea-180-manifest.tsv"
  printf 'bundle_path\tpatient_id\tname\tbirthDate\tgender\n' > "$man180"
  local syn="$QT_ROOT/2026/patients/raw/synthea-1000-20260901-20260101/fhir"
  local i=0 f
  for f in "$syn"/*.json; do
    i=$((i+1))
    [[ "$i" -le 180 ]] || break
    printf '%s\t\t\t\t\n' "$f" >> "$man180"
  done
  BASE_URL="${NATIVE_LOAD_BASE:-https://$DOMAIN}" LOAD=1 OUT="$outdir/synthea-180-ingest.tsv" \
    bash "$QT_ROOT/scripts/load-cohort.sh" "$man180"
  curl -sS -m 300 -o "$outdir/john-salt.json" -w 'JOHN-SALT HTTP %{http_code}\n' \
    -H 'Expect:' -H 'Content-Type: application/json' \
    --data-binary @"$JOHN" "${NATIVE_LOAD_BASE:-https://$DOMAIN}/addpatient?load=1"
  local mancoh="$outdir/common-cohort-manifest.tsv" bp
  printf 'bundle_path\tpatient_id\tname\tbirthDate\tgender\n' > "$mancoh"
  while IFS= read -r bp; do
    [[ -n "$bp" ]] || continue
    printf '%s\t\t\t\t\n' "$bp" >> "$mancoh"
  done < <(tail -n +2 "$QT_ROOT/2026/patients/overnight-load1-manifest.tsv")
  BASE_URL="${NATIVE_LOAD_BASE:-https://$DOMAIN}" LOAD=1 OUT="$outdir/common-cohort-ingest.tsv" \
    bash "$QT_ROOT/scripts/load-cohort.sh" "$mancoh"
  echo "POPULATION OK"
}

case "$PHASE" in
  host) phase_host ;;
  build) phase_build ;;
  extract) phase_extract ;;
  load) phase_load ;;
  install) phase_install ;;
  caddy) phase_caddy ;;
  smoke) phase_smoke ;;
  population) NATIVE_LOAD=1 phase_population ;;
  all)
    phase_host
    phase_build
    phase_extract
    phase_load
    phase_install
    phase_caddy
    phase_smoke
    phase_population
    ;;
  *) echo "usage: $0 host|build|extract|load|install|caddy|smoke|all" >&2; exit 2 ;;
esac
