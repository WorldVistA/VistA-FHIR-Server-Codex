#!/usr/bin/env bash
# Caddy/TLS and the rehmp CPRS demo on native Rocky. Counterpart of
# scripts/iris-public-setup.sh.
#
# The Cloudsmith dnf repo has no Rocky package. This installs the official
# Caddy binary and a systemd unit. The Caddyfile is the shared native one
# (CPRS demo, C0X static files, /filesystem/c0x 308, reverse_proxy to :9080),
# so a later c0x.sh run does not overwrite it with another host's name.
#
# Usage: scripts/iris-native/public.sh root@host
# Env:   REHMP_FROM=root@other  copy /var/www/rehmp from that host when the
#        local rehmp dist has not been built.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"

CADDY_VERSION="${CADDY_VERSION:-2.11.7}"
echo "== iris-native public: $HOST domain $HOSTNAME_ONLY =="

caddyfile="$(mktemp)"
native_caddyfile "$HOSTNAME_ONLY" > "$caddyfile"
scp -q "$caddyfile" "$HOST:/tmp/Caddyfile.iris-native"
rm -f "$caddyfile"

ssh "$HOST" "CADDY_VERSION='$CADDY_VERSION' bash -s" <<'REMOTE'
set -euo pipefail
if command -v firewall-cmd >/dev/null && systemctl is-active firewalld >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=http --add-service=https
  firewall-cmd --reload
  echo "firewalld: http and https open"
fi

need_caddy=1
if [[ -x /usr/local/bin/caddy ]] && /usr/local/bin/caddy version | grep -q "v${CADDY_VERSION}"; then
  need_caddy=0
fi
if [[ "$need_caddy" -eq 1 ]]; then
  curl -fsSL -o /usr/local/bin/caddy \
    "https://caddyserver.com/api/download?os=linux&arch=amd64&version=${CADDY_VERSION}"
  chmod 755 /usr/local/bin/caddy
fi
/usr/local/bin/caddy version

getent group caddy >/dev/null || groupadd --system caddy
id caddy >/dev/null 2>&1 || useradd --system --gid caddy --create-home \
  --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy
mkdir -p /etc/caddy /var/www/rehmp /var/log

if [[ -f /etc/caddy/Caddyfile ]]; then
  cp -a /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak.$(date +%s)"
fi
install -m 0644 /tmp/Caddyfile.iris-native /etc/caddy/Caddyfile

cat > /etc/systemd/system/caddy.service <<'UNIT'
[Unit]
Description=Caddy
After=network.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/var/lib/caddy /var/log

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
/usr/local/bin/caddy validate --config /etc/caddy/Caddyfile
systemctl enable caddy
systemctl restart caddy
sleep 2
systemctl is-active caddy
REMOTE

DIST="$(vista_stack)/rehmp/ehmp-ui/rehmp-cprs-demo/dist"
if [[ -f "$DIST/index.html" ]]; then
  tar -czf /tmp/rehmp-dist.tgz -C "$DIST" .
  scp -q /tmp/rehmp-dist.tgz "$HOST:/tmp/"
  ssh "$HOST" 'tar -C /var/www/rehmp -xzf /tmp/rehmp-dist.tgz && echo "rehmp UI published from local dist"'
elif [[ -n "${REHMP_FROM:-}" ]]; then
  echo "copying rehmp UI from $REHMP_FROM"
  command ssh -o BatchMode=yes -o ConnectTimeout=20 "$REHMP_FROM" 'tar -C /var/www/rehmp -czf - .' \
    | ssh "$HOST" 'mkdir -p /var/www/rehmp && tar -C /var/www/rehmp -xzf - && echo "rehmp UI copied"'
else
  echo "WARN: rehmp dist not built and REHMP_FROM unset; skipped UI publish" >&2
  echo "      build: cd rehmp/ehmp-ui/rehmp-cprs-demo && npm ci && npm run build" >&2
fi
ssh "$HOST" 'chown -R caddy:caddy /var/www/rehmp && chmod -R a+rX /var/www/rehmp'

sleep 3
curl -sS -m 30 -o /dev/null -w "https metadata -> HTTP %{http_code}\n" "https://${HOSTNAME_ONLY}/fhir/metadata" || true
curl -sS -m 20 -o /dev/null -w "rehmp UI      -> HTTP %{http_code}\n" "https://${HOSTNAME_ONLY}/demos/cprs/" || true
echo "iris-native public complete: https://${HOSTNAME_ONLY}/"
echo "next: c0x.sh"
