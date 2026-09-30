#!/usr/bin/env bash
# showfhir-setup.sh — bootstrap showfhir.vistaplex.org like local Show + fhirdev UI gateway.
#
# Idempotent. Run from a workstation with SSH to root@showfhir.vistaplex.org.
#
# Steps:
#   1. Docker Engine + UFW 80/443
#   2. worldvista/vehu:latest as container Show (9080/9430 published)
#   3. Codex + C0RG + SYN* sync, EN^SYNWEBRG, c0rgenc plugin, %webreq w/ XC env
#   4. Caddy TLS + /demos/cprs UI (fhirdev Caddyfile shape)
#   5. Optional: SHOWFHIR_LOAD=1 to populate 180 Synthea + JOHN-SALT + cohort
#
# Env:
#   SHOWFHIR_SSH     default root@showfhir.vistaplex.org
#   SHOWFHIR_NAME    default Show
#   SHOWFHIR_IMAGE   default worldvista/vehu:latest
#   SHOWFHIR_LOAD=1  run patient loads after smoke
#   SHOWFHIR_SKIP_PULL=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REHMP_ROOT="${REHMP_ROOT:-$ROOT/../rehmp}"
LOADER_ROOT="${LOADER_ROOT:-$ROOT/../VistA-FHIR-Data-Loader}"
QT_ROOT="${QT_ROOT:-$ROOT/../HL7-FHIR-quality-testing}"
JOHN="${JOHN_SALT_BUNDLE:-$ROOT/../WVEHR-on-FHIR/bundles/JOHN-SALT.json}"

HOST="${SHOWFHIR_SSH:-root@showfhir.vistaplex.org}"
NAME="${SHOWFHIR_NAME:-Show}"
IMAGE="${SHOWFHIR_IMAGE:-worldvista/vehu:latest}"
DOMAIN="${SHOWFHIR_DOMAIN:-showfhir.vistaplex.org}"
HTTP_PUBLIC="https://$DOMAIN"

SSHCTL="/tmp/ssh-showfhir-setup-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=25 -o ConnectionAttempts=15 \
  -o StrictHostKeyChecking=accept-new \
  -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=300)
ssh() { command ssh "${SSHMUX[@]}" "$@"; }
scp() { command scp "${SSHMUX[@]}" "$@"; }
cleanup() { command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true; }
trap cleanup EXIT

echo "== showfhir-setup: $HOST container=$NAME image=$IMAGE =="
ssh "$HOST" 'echo OK; hostname; uptime'

# --- 1. Docker + UFW ---------------------------------------------------------
echo "==> 1. Docker Engine + UFW"
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
fi
if ! command -v docker >/dev/null 2>&1; then
  for i in $(seq 1 60); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    [ "$i" = 1 ] && echo "waiting for dpkg lock..."
    sleep 10
  done
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
docker version --format '{{.Server.Version}}'
REMOTE

# --- 2. VEHU container -------------------------------------------------------
echo "==> 2. Container $NAME ($IMAGE)"
ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
NAME='$NAME'
IMAGE='$IMAGE'
if [[ "\${SHOWFHIR_SKIP_PULL:-0}" != "1" ]]; then
  docker pull "\$IMAGE"
fi
if docker ps -a --format '{{.Names}}' | grep -qx "\$NAME"; then
  echo "container \$NAME exists"
  docker start "\$NAME" >/dev/null || true
else
  docker run -d --name "\$NAME" --restart unless-stopped \
    -p 9080:9080 -p 9430:9430 -p 2222:22 \
    -p 8001:8001 -p 5001:5001 \
    "\$IMAGE"
fi
# wait for listener-ish readiness inside guest
for i in \$(seq 1 60); do
  if docker exec "\$NAME" bash -lc 'test -x /home/vehu/lib/gtm/mumps'; then
    echo "mumps ready"
    break
  fi
  sleep 5
done
docker ps --filter name="^/\${NAME}\$" --format '{{.Names}} {{.Status}} {{.Ports}}'
REMOTE

# --- 3. Sync routines + plugin + webreq --------------------------------------
echo "==> 3. Sync Codex / C0RG / SYN + plugin"
STAGE=$(ssh "$HOST" 'mktemp -d /tmp/showfhir-sync.XXXXXX')
echo "remote stage $STAGE"

# Build a clean tar of all .m / assets we need
STAGE_LOCAL=$(mktemp -d /tmp/showfhir-local.XXXXXX)
cp -f "$ROOT"/src/*.m "$STAGE_LOCAL/"
cp -f "$REHMP_ROOT"/C0RG/*.m "$STAGE_LOCAL/" 2>/dev/null || true
[[ -f "$ROOT/SYNWEBUT.m" ]] && cp -f "$ROOT/SYNWEBUT.m" "$STAGE_LOCAL/"
if [[ -d "$LOADER_ROOT/src" ]]; then
  # SYN* needed for addpatient / WEBRG on a stock VEHU image
  cp -f "$LOADER_ROOT"/src/SYN*.m "$STAGE_LOCAL/" 2>/dev/null || true
fi
# tjson web for /filesystem
if [[ -d "$ROOT/vendor/tjson/web" ]]; then
  mkdir -p "$STAGE_LOCAL/tjson-web"
  cp -a "$ROOT/vendor/tjson/web/." "$STAGE_LOCAL/tjson-web/"
fi
# plugin sources
mkdir -p "$STAGE_LOCAL/c0rgenc"
cp -f "$REHMP_ROOT"/plugin/c0rgenc/*.{c,h,xc} "$STAGE_LOCAL/c0rgenc/" 2>/dev/null || true

# Stock worldvista/vehu does not ship _webreq.m in p/; local Show (or a prior
# lane) does. Prefer local Show container, else skip (caller must supply).
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx Show; then
  mkdir -p "$STAGE_LOCAL/web"
  while IFS= read -r f; do
    bn=$(basename "$f")
    docker cp "Show:$f" "$STAGE_LOCAL/web/$bn" 2>/dev/null || true
  done < <(docker exec Show bash -lc 'ls /home/vehu/p/_web*.m 2>/dev/null')
fi

tar -czf /tmp/showfhir-payload.tgz -C "$STAGE_LOCAL" .
scp -q /tmp/showfhir-payload.tgz "$HOST:$STAGE/payload.tgz"
rm -rf "$STAGE_LOCAL"

ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
NAME='$NAME'
STAGE='$STAGE'
cd "\$STAGE"
tar -xzf payload.tgz
# routines
docker exec "\$NAME" mkdir -p /home/vehu/p /home/vehu/www/filesystem/tjson/web /home/vehu/lib/c0rgenc /tmp/c0rgenc
# copy .m (exclude dirs)
for f in "\$STAGE"/*.m; do
  [ -f "\$f" ] || continue
  docker cp "\$f" "\$NAME:/home/vehu/p/"
done
if [ -d "\$STAGE/web" ]; then
  for f in "\$STAGE"/web/_web*.m; do
    [ -f "\$f" ] || continue
    docker cp "\$f" "\$NAME:/home/vehu/p/\$(basename "\$f")"
  done
fi
docker exec "\$NAME" bash -lc 'chown -R vehu:vehu /home/vehu/p'
# tjson: FILESYS^%webapi uses ^%webhome + path incl. "filesystem/…"
# so files live at www/filesystem/tjson/web/ (same as local Show / fhirdev)
if [ -d "\$STAGE/tjson-web" ]; then
  docker cp "\$STAGE/tjson-web/." "\$NAME:/home/vehu/www/filesystem/tjson/web/"
  docker exec "\$NAME" chown -R vehu:vehu /home/vehu/www/filesystem
fi
# Required for /filesystem/* (stock VEHU has ^%webhome empty → looks under /tmp)
docker exec -u vehu -w /tmp "\$NAME" bash -lc 'set -a; . /home/vehu/etc/env; set +a
printf "%s\n" "S ^%webhome=\"/home/vehu/www/\"" "W ^%webhome,!" "H" | mumps -direct
'
# SCT→OS5 map + file 81 seed (stock VEHU has empty ^SYN sct2os5 → Procedure ~0%)
docker exec -u vehu -w /tmp "\$NAME" bash -lc 'set -a; . /home/vehu/etc/env; set +a
printf "%s\n" \
  "D LOADOS5^SYNOS5LD" \
  "W \"OS5COUNT=\",\$\$COUNT^SYNOS5LD,!" \
  "D EN^SYNOS5PT" \
  "I \$\$COUNT^SYNOS5LD<1 W \"ERROR: sct2os5 map empty after LOADOS5\",! H 1" \
  "H" | mumps -direct
'
# build plugin inside guest
if [ -d "\$STAGE/c0rgenc" ]; then
  docker cp "\$STAGE/c0rgenc/." "\$NAME:/tmp/c0rgenc/"
  docker exec "\$NAME" bash -lc '
    set -euo pipefail
    . /home/vehu/etc/env
    if ! command -v gcc >/dev/null; then
      apt-get update -qq && apt-get install -y -qq gcc >/dev/null
    fi
    cd /tmp/c0rgenc
    gcc -O2 -fPIC -shared -Wall -I"\$gtm_dist" -o libc0rgenc.so \
      c0rgenc.c c0rgenc_mem.c c0rgenc_flat.c c0rgenc_zw.c c0rgenc_ydb.c
    cp -f libc0rgenc.so /home/vehu/lib/c0rgenc/libc0rgenc.so
    { echo /home/vehu/lib/c0rgenc/libc0rgenc.so; tail -n +2 /tmp/c0rgenc/c0rgenc.xc; } \
      > /home/vehu/lib/c0rgenc/c0rgenc.xc
    grep -q GTMXC_c0rgenc /home/vehu/etc/env || {
      echo "export GTMXC_c0rgenc=/home/vehu/lib/c0rgenc/c0rgenc.xc" >> /home/vehu/etc/env
      echo "export ydb_xc_c0rgenc=/home/vehu/lib/c0rgenc/c0rgenc.xc" >> /home/vehu/etc/env
    }
    chown -R vehu:vehu /home/vehu/lib/c0rgenc
    ls -l /home/vehu/lib/c0rgenc
  '
fi
# Wait for vista entrypoint journal recover / listeners
sleep 15
# register routes + restart webreq with XC env
docker exec -u vehu -w /tmp "\$NAME" bash -lc '
  set -a
  . /home/vehu/etc/env
  set +a
  printf "%s\n" "D EN^SYNWEBRG" "H" | mumps -direct || true
  printf "%s\n" "D stop^%webreq" "H" | mumps -direct || true
  sleep 11  # listener polls the stop flag every 10s; go sooner and it overwrites the flag
  printf "%s\n" "D go^%webreq" "H" | mumps -direct || true
  sleep 3
  printf "%s\n" "W \$G(^%webhttp(0,\"listener\")),!" "H" | mumps -direct || true
'
# local smoke inside host (do not abort on curl transport errors)
for i in \$(seq 1 30); do
  code=\$(curl -sS -m 5 -o /dev/null -w "%{http_code}" http://127.0.0.1:9080/ping || echo 000)
  [ "\$code" = "200" ] && break
  sleep 2
done
curl -sS -m 15 -o /tmp/sf-meta.json -w "local_meta=%{http_code}/%{size_download}\n" http://127.0.0.1:9080/fhir/metadata || true
head -c 120 /tmp/sf-meta.json 2>/dev/null; echo
REMOTE

# --- 4. Caddy + UI -----------------------------------------------------------
echo "==> 4. Caddy UI gateway (fhirdev-shaped)"
# Ensure CPRS dist built
if [[ ! -f "$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo/dist/index.html" ]]; then
  (cd "$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo" && npm ci --silent && npm run build)
fi
tar -czf /tmp/showfhir-cprs.tgz -C "$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo/dist" .
scp -q /tmp/showfhir-cprs.tgz "$HOST:/tmp/showfhir-cprs.tgz"

ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
DOMAIN='$DOMAIN'
if ! command -v caddy >/dev/null 2>&1; then
  for i in \$(seq 1 60); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    sleep 10
  done
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq
  apt-get install -y -qq caddy
fi
mkdir -p /var/www/rehmp/dist/demos/cprs
tar -C /var/www/rehmp/dist/demos/cprs -xzf /tmp/showfhir-cprs.tgz
# minimal landing so / is not empty
if [[ ! -f /var/www/rehmp/dist/index.html ]]; then
  cat > /var/www/rehmp/dist/index.html <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>showfhir</title></head>
<body><h1>showfhir</h1>
<p><a href="/fhir">/fhir</a> · <a href="/demos/cprs/">CPRS demo</a> · <a href="/fhir/metadata">metadata</a></p>
</body></html>
HTML
fi
chmod -R a+rX /var/www/rehmp
cat > /etc/caddy/Caddyfile <<CADDY
${DOMAIN} {
	encode zstd gzip

	# C0X static UI (Caddy). Exact paths only — API stays on @m_api → M.
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
systemctl enable --now caddy
systemctl restart caddy
sleep 3
systemctl is-active caddy
REMOTE

echo "==> public smoke"
sleep 5
curl -sS -m 30 -o /tmp/sf-pub-meta.json -w "pub_meta=%{http_code}/%{size_download}\n" "$HTTP_PUBLIC/fhir/metadata" || true
head -c 160 /tmp/sf-pub-meta.json; echo
curl -sS -m 20 -o /dev/null -w "pub_cprs=%{http_code}/%{size_download}\n" "$HTTP_PUBLIC/demos/cprs/" || true
curl -sS -m 15 -o /dev/null -w "pub_ping=%{http_code}\n" "$HTTP_PUBLIC/ping" || true

# plugin / ZYENCODE compare inside guest
echo "==> COMPARE^C0RGFENCT"
ssh "$HOST" "docker exec -u vehu -w /tmp $NAME bash -lc '
  set -a; . /home/vehu/etc/env; set +a
  printf \"%s\\n\" \"D COMPARE^C0RGFENCT\" \"H\" | mumps -direct
'" || true

if [[ "${SHOWFHIR_LOAD:-0}" == "1" ]]; then
  echo "==> 5. Population loads (180 → JOHN-SALT → cohort)"
  OUTDIR=/tmp/showfhir-loads
  mkdir -p "$OUTDIR"
  MAN180="$OUTDIR/synthea-180-manifest.tsv"
  printf 'bundle_path\tpatient_id\tname\tbirthDate\tgender\n' > "$MAN180"
  SYN="$QT_ROOT/2026/patients/raw/synthea-1000-20260901-20260101/fhir"
  i=0
  for f in "$SYN"/*.json; do
    i=$((i+1))
    [ "$i" -le 180 ] || break
    printf '%s\t\t\t\t\n' "$f" >> "$MAN180"
  done
  MANCOH="$OUTDIR/common-cohort-manifest.tsv"
  printf 'bundle_path\tpatient_id\tname\tbirthDate\tgender\n' > "$MANCOH"
  while IFS= read -r bp; do
    [ -n "$bp" ] || continue
    printf '%s\t\t\t\t\n' "$bp" >> "$MANCOH"
  done < <(tail -n +2 "$QT_ROOT/2026/patients/overnight-load1-manifest.tsv")

  BASE_URL="$HTTP_PUBLIC" LOAD=1 OUT="$OUTDIR/synthea-180-ingest.tsv" \
    bash "$QT_ROOT/scripts/load-cohort.sh" "$MAN180" | tee "$OUTDIR/synthea-180.log" | tail -20
  code=$(curl -sS -m 300 -o "$OUTDIR/john-salt.json" -w '%{http_code}' \
    -H 'Expect:' -H 'Content-Type: application/json' \
    --data-binary @"$JOHN" "$HTTP_PUBLIC/addpatient?load=1")
  echo "JOHN-SALT HTTP $code"
  python3 -c "import json;d=json.load(open('$OUTDIR/john-salt.json'));print('dfn',d.get('dfn'),'status',d.get('status'),'loadStatus',d.get('loadStatus'))"
  BASE_URL="$HTTP_PUBLIC" LOAD=1 OUT="$OUTDIR/common-cohort-ingest.tsv" \
    bash "$QT_ROOT/scripts/load-cohort.sh" "$MANCOH" | tee "$OUTDIR/common-cohort.log"
  echo "loads done; manifests in $OUTDIR"
fi

echo "== showfhir-setup complete: $HTTP_PUBLIC =="
echo "CPRS: $HTTP_PUBLIC/demos/cprs/"
echo "FHIR: $HTTP_PUBLIC/fhir"
