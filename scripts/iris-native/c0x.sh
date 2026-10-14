#!/usr/bin/env bash
# Deploy C0X routines, UI, and routes on native IRIS.
# Counterpart of fhir-triple-store/scripts/iris-c0x-deploy.sh.
#
# Static UI is served by Caddy from /var/www/rehmp/dist/c0x. A copy is also
# placed under ^%webhome (/opt/iris/www/filesystem/c0x) for FILESYS. Caddy
# 308-redirects /filesystem/c0x/index.html to /c0x/. API paths stay on the
# M listener via reverse_proxy.
#
# Usage: scripts/iris-native/c0x.sh root@host
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"
require_session_helper

C0X_ROOT="$(vista_stack)/fhir-triple-store"
[[ -f "$C0X_ROOT/src/C0XWS.m" ]] || { echo "ERROR: $C0X_ROOT/src/C0XWS.m missing" >&2; exit 1; }
[[ -f "$C0X_ROOT/ui/index.html" ]] || { echo "ERROR: C0X ui missing" >&2; exit 1; }

echo "== iris-native c0x: $HOST =="

stage="$(mktemp -d /tmp/c0x-native.XXXXXX)"
mkdir -p "$stage/src" "$stage/ui"
cp -f "$C0X_ROOT"/src/C0X*.m "$stage/src/"
cp -f "$C0X_ROOT/ui/index.html" "$C0X_ROOT/ui/app.js" "$C0X_ROOT/ui/styles.css" "$stage/ui/"
native_caddyfile "$HOSTNAME_ONLY" > "$stage/Caddyfile"
tar -C "$stage" -czf /tmp/c0x-native.tgz .
scp -q /tmp/c0x-native.tgz "$HOST:/tmp/c0x-native.tgz"
rm -rf "$stage"

ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
stage="$(mktemp -d /tmp/c0x-native-stage.XXXXXX)"
tar -C "$stage" -xzf /tmp/c0x-native.tgz
mkdir -p /var/www/rehmp/dist/c0x /opt/iris/www/filesystem/c0x
for f in index.html app.js styles.css; do
  cp -f "$stage/ui/$f" "/var/www/rehmp/dist/c0x/$f"
  cp -f "$stage/ui/$f" "/opt/iris/www/filesystem/c0x/$f"
done
chmod -R a+rX /var/www/rehmp/dist/c0x /opt/iris/www/filesystem/c0x
if id caddy >/dev/null 2>&1; then
  chown -R caddy:caddy /var/www/rehmp/dist/c0x
fi

if [[ -x /usr/local/bin/caddy && -f /etc/caddy/Caddyfile ]]; then
  cp -a /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak.c0x.$(date +%s)"
  install -m 0644 "$stage/Caddyfile" /etc/caddy/Caddyfile
  /usr/local/bin/caddy validate --config /etc/caddy/Caddyfile
  systemctl reload caddy || systemctl restart caddy
else
  echo "WARN: Caddy is not installed; run public.sh so /c0x/ is served" >&2
fi

mkdir -p /opt/iris/import/c0x-src /opt/iris/import/c0x-mac
rm -f /opt/iris/import/c0x-src/*.m /opt/iris/import/c0x-mac/*.mac
cp -f "$stage"/src/C0X*.m /opt/iris/import/c0x-src/
for f in /opt/iris/import/c0x-src/*.m; do
  b=$(basename "$f" .m)
  printf 'ROUTINE %s [Type=MAC]\n' "$b" | cat - "$f" > "/opt/iris/import/c0x-mac/${b}.mac"
done
chown -R irisusr:irisusr /opt/iris/import/c0x-src /opt/iris/import/c0x-mac
chmod -R a+rX /opt/iris/import/c0x-src /opt/iris/import/c0x-mac
echo "c0x mac: $(find /opt/iris/import/c0x-mac -name '*.mac' | wc -l)"
rm -rf "$stage"
REMOTE

native_m FOIA <<'M'
ZN "FOIA"
K err S sc=$SYSTEM.OBJ.ImportDir("/opt/iris/import/c0x-mac","*.mac","ck-d",.err,0)
W "C0X import: ",$SYSTEM.Status.GetOneStatusText(sc),!
N k,c S (k,c)="" S c=0 F  S k=$O(err(k)) Q:k=""  S c=c+1 W "  err ",k,"=",err(k),!
W "C0X import errors: ",c,!
W "C0XWS=",$T(+0^C0XWS),!
W "C0XIDX=",$T(+0^C0XIDX),!
I $T(REG^C0XWS)="" W "FAIL: REG^C0XWS missing",! H 1
D REG^C0XWS
W "REG^C0XWS done",!
I $G(^%webhome)="" S ^%webhome="/opt/iris/www/"
W "webhome=",^%webhome,!
W "route c0x=",$D(^%web(17.6001,"B","GET","c0x")),!
W "route presets=",$D(^%web(17.6001,"B","GET","c0x/presets")),!
H
M

echo "==> smoke https://${HOSTNAME_ONLY}"
fail=0
base="https://${HOSTNAME_ONLY}"
ui_code="$(curl -sS -o /tmp/c0x-native-ui.html -w '%{http_code}' --max-time 30 "$base/c0x/" || echo 000)"
echo "ui /c0x/ -> $ui_code"
if [[ "$ui_code" != "200" ]]; then
  echo "FAIL: C0X UI HTTP $ui_code" >&2
  fail=1
elif ! grep -qiE 'C0X|Measure|preset|SPARQL|cohort' /tmp/c0x-native-ui.html; then
  echo "FAIL: C0X UI body unexpected" >&2
  fail=1
fi

fs_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$base/filesystem/c0x/index.html" || echo 000)"
echo "redir /filesystem/c0x/index.html -> $fs_code (expect 308)"
[[ "$fs_code" == "308" ]] || { echo "FAIL: expected 308 from the filesystem URL" >&2; fail=1; }

presets="$(curl -sS --max-time 45 "$base/c0x/presets" || true)"
echo "presets head: $(printf '%s' "$presets" | head -c 180)"
if ! printf '%s' "$presets" | grep -qiE 'CMS|preset|measure|status'; then
  echo "FAIL: /c0x/presets unexpected" >&2
  fail=1
else
  echo "presets=ok"
fi

[[ "$fail" -eq 0 ]] || { echo "C0X smoke FAILED" >&2; exit 1; }
echo "iris-native c0x complete"
