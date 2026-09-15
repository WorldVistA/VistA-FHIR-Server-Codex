#!/usr/bin/env bash
# iris-public-setup.sh — put Caddy/TLS in front of the irisfhir M-Web-Server
# and publish the rehmp CPRS demo UI. Mirrors rehmp/deploy/fhirdev bootstrap.
#
# Result:
#   https://irisfhir.vistaplex.org/...            -> M-Web-Server on 127.0.0.1:9080
#   https://irisfhir.vistaplex.org/demos/cprs/    -> /var/www/rehmp (static UI)
#
# The reverse_proxy timeouts are deliberately generous: per-measure quality
# dashboards build a FHIR bundle per curated POP DFN on this single-threaded,
# 2-vCPU box (~12s/patient), so a cold dashboard render can take tens of
# seconds. Keep each measure's POP curated (IPP members only) to stay fast.
#
# Prereq: DNS A record irisfhir.vistaplex.org -> this droplet; 80/443 reachable.
# Usage:  scripts/iris-public-setup.sh [ssh-host]   (default root@irisfhir.vistaplex.org)
set -euo pipefail
HOST="${1:-root@irisfhir.vistaplex.org}"
HOSTNAME_ONLY="${HOST#*@}"

# Multiplex ssh/scp over one connection (droplet runs `ufw limit 22/tcp`).
SSHCTL="/tmp/ssh-irispub-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=20 -o ConnectionAttempts=15 \
        -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=180)
ssh() { command ssh "${SSHMUX[@]}" "$@"; }
scp() { command scp "${SSHMUX[@]}" "$@"; }
trap 'command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true' EXIT

echo "== iris-public-setup: $HOST =="

ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" "bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
DOMAIN="irisfhir.vistaplex.org"

# UFW is active on this droplet; open the web ports.
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp  >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
fi

# Caddy from the official repo (idempotent).
if ! command -v caddy >/dev/null; then
  # A freshly restored/booted droplet runs unattended-upgrades, which holds the
  # dpkg lock for several minutes. Wait it out rather than failing silently.
  for i in $(seq 1 60); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    [ "$i" = 1 ] && echo "waiting for unattended-upgrades to release dpkg lock..."
    sleep 10
  done
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl gnupg >/dev/null 2>&1
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq caddy >/dev/null 2>&1
fi
caddy version

mkdir -p /var/www/rehmp
cat > /etc/caddy/Caddyfile <<CADDY
${DOMAIN} {
	encode gzip
	handle_path /demos/cprs/* {
		root * /var/www/rehmp
		try_files {path} /index.html
		file_server
	}
	reverse_proxy 127.0.0.1:9080 {
		transport http {
			dial_timeout 30s
			response_header_timeout 300s
			read_timeout 300s
			write_timeout 300s
		}
	}
}
CADDY

caddy validate --config /etc/caddy/Caddyfile
systemctl enable --now caddy
systemctl restart caddy
sleep 3
systemctl is-active caddy
REMOTE

echo "-- publish rehmp UI (build dist first: cd rehmp/ehmp-ui/rehmp-cprs-demo && npm ci && npm run build) --"
DIST="$(cd "$(dirname "$0")/../../rehmp/ehmp-ui/rehmp-cprs-demo/dist" 2>/dev/null && pwd || true)"
if [[ -n "$DIST" && -f "$DIST/index.html" ]]; then
  tar -czf /tmp/rehmp-dist.tgz -C "$DIST" .
  scp -q /tmp/rehmp-dist.tgz "$HOST:/tmp/"
  ssh "$HOST" 'tar -C /var/www/rehmp -xzf /tmp/rehmp-dist.tgz && echo "rehmp UI published"'
else
  echo "WARN: rehmp dist not found; skipped UI publish" >&2
fi

sleep 5
curl -sS -m 20 -o /dev/null -w "https metadata -> HTTP %{http_code}\n" "https://$HOSTNAME_ONLY/fhir/metadata"
curl -sS -m 20 -o /dev/null -w "rehmp UI      -> HTTP %{http_code}\n" "https://$HOSTNAME_ONLY/demos/cprs/"
echo "iris-public-setup complete: https://$HOSTNAME_ONLY/"
