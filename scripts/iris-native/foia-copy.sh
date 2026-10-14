#!/usr/bin/env bash
# Copy a consistent FOIA IRIS.DAT from an existing IRIS host onto a native one.
#
# The destination path matches the Docker lane's host path:
#   /opt/iris/data/foia/IRIS.DAT
# The source is frozen with Backup.General.ExternalFreeze for the copy and
# thawed afterwards, including on failure. The source may be the community
# container (docker exec iris) or another native host (iris-session.sh).
#
# Usage:
#   scripts/iris-native/foia-copy.sh root@dest root@source
#
# A one-shot ed25519 key on the destination pulls the file directly. The
# public key is removed from the source authorized_keys when the script exits.
set -euo pipefail

DEST="${1:?root@dest}"
SRC="${2:?root@source}"
COMMENT="iris-native-foia-copy"
FROZEN=0
MODE=""

ssh_to() {
  local host="$1"
  shift
  command ssh -o BatchMode=yes -o ConnectTimeout=25 -o ConnectionAttempts=10 \
    -o ServerAliveInterval=30 -o ServerAliveCountMax=240 \
    -o StrictHostKeyChecking=accept-new "$host" "$@"
}

source_m() {
  if [[ "$MODE" == "docker" ]]; then
    ssh_to "$SRC" 'docker exec -i iris iris session IRIS -U %SYS'
  else
    ssh_to "$SRC" '/usr/local/sbin/iris-session.sh %SYS'
  fi
}

thaw() {
  [[ "$FROZEN" == 1 ]] || return 0
  echo "thawing $SRC"
  source_m <<'M' || true
W "thaw=",##class(Backup.General).ExternalThaw(),!
H
M
  FROZEN=0
}

remove_key() {
  ssh_to "$DEST" 'rm -f /root/.ssh/iris-copy /root/.ssh/iris-copy.pub' || true
  ssh_to "$SRC" "bash -s" <<EOF || true
set -euo pipefail
f="\$HOME/.ssh/authorized_keys"
[[ -f "\$f" ]] || exit 0
grep -v '$COMMENT' "\$f" > "\$f.tmp" || true
mv "\$f.tmp" "\$f"
chmod 600 "\$f"
EOF
}

cleanup() {
  local status=$?
  thaw
  remove_key
  exit "$status"
}
trap cleanup EXIT

echo "== foia-copy: $SRC -> $DEST =="
if ssh_to "$SRC" 'docker inspect iris >/dev/null 2>&1'; then
  MODE=docker
elif ssh_to "$SRC" 'test -x /usr/local/sbin/iris-session.sh'; then
  MODE=native
else
  echo "ERROR: $SRC has neither a docker container named iris nor iris-session.sh" >&2
  exit 1
fi
echo "source session: $MODE"

ssh_to "$SRC" 'test -f /opt/iris/data/foia/IRIS.DAT' \
  || { echo "ERROR: source has no /opt/iris/data/foia/IRIS.DAT" >&2; exit 1; }

echo "freezing $SRC"
freeze_out="$(source_m <<'M'
W "freeze=",##class(Backup.General).ExternalFreeze(),!
H
M
)"
printf '%s\n' "$freeze_out" | grep -q 'freeze=1' || {
  echo "ERROR: ExternalFreeze did not return 1" >&2
  printf '%s\n' "$freeze_out" >&2
  exit 1
}
FROZEN=1

echo "installing one-shot copy key"
ssh_to "$DEST" "bash -s" <<EOF
set -euo pipefail
mkdir -p /root/.ssh
chmod 700 /root/.ssh
rm -f /root/.ssh/iris-copy /root/.ssh/iris-copy.pub
ssh-keygen -q -t ed25519 -f /root/.ssh/iris-copy -N '' -C '$COMMENT'
EOF
pub="$(ssh_to "$DEST" 'cat /root/.ssh/iris-copy.pub')"
ssh_to "$SRC" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -q '$COMMENT' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys"

src_host="${SRC#*@}"
src_user="${SRC%%@*}"
echo "rsync $src_host:/opt/iris/data/foia/IRIS.DAT"
ssh_to "$DEST" "bash -s" <<EOF
set -euo pipefail
mkdir -p /opt/iris/data/foia
rsync -a --partial \
  -e 'ssh -i /root/.ssh/iris-copy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' \
  '${src_user}@${src_host}:/opt/iris/data/foia/IRIS.DAT' \
  /opt/iris/data/foia/IRIS.DAT
EOF

src_size="$(ssh_to "$SRC" 'stat -c %s /opt/iris/data/foia/IRIS.DAT')"
dst_size="$(ssh_to "$DEST" 'stat -c %s /opt/iris/data/foia/IRIS.DAT')"
[[ "$src_size" == "$dst_size" ]] || {
  echo "ERROR: size mismatch source=$src_size dest=$dst_size" >&2
  exit 1
}
echo "copied $dst_size bytes"
echo "foia-copy complete. next: foia.sh $DEST"
