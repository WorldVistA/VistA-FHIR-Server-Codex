#!/usr/bin/env bash
# Install native IRIS Health on Rocky Linux and load a license key.
#
# This is the native counterpart of scripts/iris-host-setup.sh. That script
# pulls the community Docker image. This one runs the RHEL 9 kit
# (IRISHealth-*-lnxrh9x64.tar.gz) under systemd.
#
# The key file and the generated SuperUser password stay on the host:
#   /root/iris-install/iris.key            mode 600, root
#   /usr/irissys/mgr/iris.key              mode 640, irisusr
#   /root/iris-install/superuser.pass      mode 600, root
# Neither is printed. Do not commit them.
#
# Usage:
#   scripts/iris-native/install.sh root@host --kit /path/to/kit.tar.gz --key /path/to/file.key
#
# Re-running when IRIS is already installed skips the kit and re-applies the
# license if --key is given. Rocky is not RHEL, so the installer is forced
# onto the lnxrh9x64 platform (ISC_PACKAGE_PLATFORM). Apache is not configured
# (ISC_PACKAGE_WEB_CONFIGURE=N); Caddy is installed later by public.sh.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"

KIT=""
KEY=""
HOST_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kit) KIT="${2:?}"; shift 2 ;;
    --key) KEY="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$HOST_ARG" ]]; then HOST_ARG="$1"; shift; else echo "unknown arg: $1" >&2; exit 2; fi
      ;;
  esac
done
[[ -n "$HOST_ARG" ]] || { echo "usage: install.sh root@host --kit TAR --key KEY" >&2; exit 2; }
native_begin "$HOST_ARG"

if [[ -n "$KEY" ]]; then
  [[ -f "$KEY" ]] || { echo "ERROR: key file not found: $KEY" >&2; exit 1; }
  [[ "$(stat -c %s "$KEY")" -lt 8192 ]] || { echo "ERROR: key file is unexpectedly large" >&2; exit 1; }
  grep -q 'AuthorizationKey' "$KEY" || { echo "ERROR: key file has no AuthorizationKey marker" >&2; exit 1; }
fi

echo "== iris-native install: $HOST =="

if [[ -n "$KIT" ]]; then
  [[ -f "$KIT" ]] || { echo "ERROR: kit not found: $KIT" >&2; exit 1; }
  kit_base="$(basename "$KIT")"
  remote_kit="/root/iris-install/$kit_base"
  local_size="$(stat -c %s "$KIT")"
  remote_size="$(ssh "$HOST" "stat -c %s '$remote_kit' 2>/dev/null || echo 0")"
  if [[ "$remote_size" == "$local_size" ]]; then
    echo "kit already on host ($local_size bytes)"
  else
    echo "uploading kit ($local_size bytes)"
    ssh "$HOST" 'mkdir -p /root/iris-install && chmod 700 /root/iris-install'
    scp -q "$KIT" "$HOST:$remote_kit"
  fi
fi

if [[ -n "$KEY" ]]; then
  ssh "$HOST" 'mkdir -p /root/iris-install && chmod 700 /root/iris-install'
  scp -q "$KEY" "$HOST:/root/iris-install/iris.key.upload"
  ssh "$HOST" 'mv /root/iris-install/iris.key.upload /root/iris-install/iris.key && chown root:root /root/iris-install/iris.key && chmod 600 /root/iris-install/iris.key'
  echo "license key installed on host (mode 600, not printed)"
fi

# The remote half creates the password file, runs the kit once, installs
# systemd, and loads the key. It must not echo the password or the key.
kit_base=""
[[ -n "$KIT" ]] && kit_base="$(basename "$KIT")"
ssh "$HOST" "IRIS_PLATFORM='${IRIS_PLATFORM:-lnxrh9x64}' IRIS_KIT_BASENAME='${kit_base}' bash -s" <<'REMOTE'
set -euo pipefail
PLATFORM="${IRIS_PLATFORM:-lnxrh9x64}"
install_dir=/usr/irissys
stage=/root/iris-install

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  echo "os: ${ID:-unknown} ${VERSION_ID:-}"
  if [[ "${ID:-}" != "rocky" ]]; then
    echo "WARN: this script targets Rocky Linux; cplatname will not see ID=rocky" >&2
  fi
fi

mkdir -p "$stage"
chmod 700 "$stage"
if [[ ! -s "$stage/superuser.pass" ]]; then
  umask 077
  openssl rand -base64 24 | tr -d '\n' > "$stage/superuser.pass"
  echo >> "$stage/superuser.pass"
  chmod 600 "$stage/superuser.pass"
  chown root:root "$stage/superuser.pass"
  echo "generated SuperUser password file (mode 600, not printed)"
else
  echo "SuperUser password file already present"
fi

missing=()
command -v tar >/dev/null || missing+=(tar)
command -v openssl >/dev/null || missing+=(openssl)
command -v ss >/dev/null || missing+=(iproute)
if [[ ${#missing[@]} -gt 0 ]]; then
  dnf install -y "${missing[@]}"
fi

already=0
if [[ -x "$install_dir/bin/iris" ]] && "$install_dir/bin/iris" list 2>/dev/null | grep -q "Configuration 'IRIS'"; then
  already=1
  echo "IRIS already installed; skipping kit"
fi

if [[ "$already" -eq 0 ]]; then
  kit=""
  if [[ -n "${IRIS_KIT_BASENAME:-}" && -f "$stage/$IRIS_KIT_BASENAME" ]]; then
    kit="$stage/$IRIS_KIT_BASENAME"
  else
    shopt -s nullglob
    kits=("$stage"/IRISHealth-*-lnxrh9x64.tar.gz)
    shopt -u nullglob
    if [[ ${#kits[@]} -eq 0 ]]; then
      echo "ERROR: no kit tarball in $stage; pass --kit" >&2
      exit 1
    fi
    kit="${kits[0]}"
  fi
  if ! find "$stage" -maxdepth 3 -type f -name irisinstall_silent | grep -q .; then
    echo "extracting $(basename "$kit")"
    tar -C "$stage" -xzf "$kit"
  fi
  silent="$(find "$stage" -maxdepth 3 -type f -name irisinstall_silent | head -1)"
  [[ -n "$silent" ]] || { echo "ERROR: irisinstall_silent not in kit" >&2; exit 1; }
  pass="$(cat "$stage/superuser.pass")"
  echo "running unattended install (platform $PLATFORM, no Apache)"
  # ISC_PACKAGE_IRISUSER is left unset so the installer creates irisusr.
  # The password is passed only through the environment; the install log on
  # the first Rocky host did not record it.
  (
    export ISC_PACKAGE_MODE=unattended
    export ISC_PACKAGE_PLATFORM="$PLATFORM"
    export ISC_PACKAGE_INSTANCENAME=IRIS
    export ISC_PACKAGE_INSTALLDIR="$install_dir"
    export ISC_PACKAGE_UNICODE=Y
    export ISC_PACKAGE_INITIAL_SECURITY=Normal
    export ISC_PACKAGE_USER_PASSWORD="$pass"
    export ISC_PACKAGE_WEB_CONFIGURE=N
    "$silent" > "$stage/install.log" 2>&1
  ) || {
    echo "ERROR: installer failed; last lines of $stage/install.log:" >&2
    tail -30 "$stage/install.log" >&2 || true
    exit 1
  }
  unset pass
  echo "installer exit 0"
fi

ln -sfn "$install_dir/bin/iris" /usr/local/bin/iris

cat > /usr/local/sbin/iris-instance.sh <<'SH'
#!/bin/bash
# Idempotent start/stop for the native IRIS instance. iris start exits
# non-zero when the instance is already up, which would fail the systemd unit.
set -euo pipefail
cmd="${1:-start}"
IRIS=/usr/irissys/bin/iris
case "$cmd" in
  start)
    if "$IRIS" list 2>/dev/null | grep -q 'status:.*running'; then
      exit 0
    fi
    exec "$IRIS" start IRIS
    ;;
  stop)
    exec "$IRIS" stop IRIS quietly
    ;;
  *)
    echo "usage: iris-instance.sh start|stop" >&2
    exit 2
    ;;
esac
SH
chmod 700 /usr/local/sbin/iris-instance.sh

cat > /usr/local/sbin/iris-session.sh <<'SH'
#!/bin/bash
# iris-session.sh NAMESPACE < commands.m
# Logs in as SuperUser using /root/iris-install/superuser.pass.
# Does not print the password.
set -euo pipefail
NS="${1:?namespace}"
PASSFILE="${IRIS_SUPERUSER_PASS_FILE:-/root/iris-install/superuser.pass}"
[[ -r "$PASSFILE" ]] || { echo "missing $PASSFILE" >&2; exit 1; }
PASS="$(cat "$PASSFILE")"
{
  printf 'SuperUser\n%s\n' "$PASS"
  cat
} | /usr/irissys/bin/iris session IRIS -U "$NS"
SH
chmod 700 /usr/local/sbin/iris-session.sh

cat > /etc/systemd/system/iris.service <<'UNIT'
[Unit]
Description=InterSystems IRIS Health
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/iris-instance.sh start
ExecStop=/usr/local/sbin/iris-instance.sh stop
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable iris.service
systemctl start iris.service

if [[ -f "$stage/iris.key" ]]; then
  cp -f "$stage/iris.key" "$install_dir/mgr/iris.key"
  chown irisusr:irisusr "$install_dir/mgr/iris.key"
  chmod 640 "$install_dir/mgr/iris.key"
  /usr/local/sbin/iris-session.sh '%SYS' <<'M'
W "upgrade=",$SYSTEM.License.Upgrade(),!
W "customer=",$SYSTEM.License.KeyCustomerName(),!
W "order=",$SYSTEM.License.KeyOrderNumber(),!
W "product=",$SYSTEM.License.KeyProduct(),!
W "users=",$SYSTEM.License.GetUserLimit(),!
H
M
  /usr/local/sbin/iris-instance.sh stop || true
  /usr/local/sbin/iris-instance.sh start
else
  echo "WARN: no $stage/iris.key; IRIS is unlicensed until --key is applied" >&2
fi

echo "-- iris list --"
iris list
if iris list | grep -q 'state:.*ok'; then
  echo "license state ok"
elif [[ ! -f "$stage/iris.key" ]]; then
  echo "IRIS is running unlicensed. Stop here until a key is moved onto this host."
else
  echo "ERROR: key was installed but IRIS state is not ok. See $install_dir/mgr/messages.log" >&2
  iris list >&2 || true
  exit 1
fi
REMOTE

echo "iris-native install complete: $HOST"
if [[ -n "$KEY" ]]; then
  echo "next: foia-copy.sh or foia.sh, then cprs.sh web.sh public.sh c0x.sh smoke.sh"
else
  echo "stopped before license activation"
fi
