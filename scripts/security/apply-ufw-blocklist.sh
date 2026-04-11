#!/usr/bin/env bash
# Apply a flat IP blocklist to UFW, locally or on a remote host over SSH.
#
# Examples:
#   sudo ./scripts/security/apply-ufw-blocklist.sh \
#     --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt
#
#   ./scripts/security/apply-ufw-blocklist.sh \
#     --host root@example.org \
#     --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt
#
#   sudo ./scripts/security/apply-ufw-blocklist.sh \
#     --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt \
#     --port 22
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  apply-ufw-blocklist.sh --list FILE [--port PORT] [--position N]
  apply-ufw-blocklist.sh --host USER@HOST --list FILE [--port PORT] [--position N]

Options:
  --list FILE     IP blocklist file. Blank lines and '#' comments are ignored.
  --host HOST     Optional remote SSH target. The script copies the list and
                  re-runs itself on the remote host.
  --port PORT     If set, deny only this destination TCP port.
                  Default: deny all traffic from each IP.
  --position N    UFW insert position. Default: 1
  -h, --help      Show this help text.

Notes:
  - Local mode must run as root.
  - Remote mode expects passwordless SSH to a root-capable account.
EOF
}

LIST_FILE=""
REMOTE_HOST=""
PORT=""
POSITION="1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      LIST_FILE="${2:-}"
      shift 2
      ;;
    --host)
      REMOTE_HOST="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --position)
      POSITION="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$LIST_FILE" ]]; then
  echo "error: --list is required" >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$LIST_FILE" ]]; then
  echo "error: list file not found: $LIST_FILE" >&2
  exit 2
fi

if [[ -n "$REMOTE_HOST" ]]; then
  remote_list="/tmp/$(basename "$LIST_FILE").$$"
  scp "$LIST_FILE" "${REMOTE_HOST}:${remote_list}"
  ssh "$REMOTE_HOST" "bash -s -- --list '$remote_list'${PORT:+ --port '$PORT'} --position '$POSITION'" < "$0"
  ssh "$REMOTE_HOST" "rm -f '$remote_list'"
  exit 0
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "error: local mode must run as root (or use --host root@server)" >&2
  exit 2
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "error: ufw is not installed on this host" >&2
  exit 2
fi

added=0
skipped=0

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  ip="$(printf '%s' "$line" | xargs)"
  [[ -n "$ip" ]] || continue

  if ufw status | grep -Eq "(^|[[:space:]])${ip}([[:space:]]|$)"; then
    echo "skip $ip (already present)"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -n "$PORT" ]]; then
    echo "add  $ip -> port $PORT"
    ufw insert "$POSITION" deny in proto tcp from "$ip" to any port "$PORT"
  else
    echo "add  $ip -> all ports"
    ufw insert "$POSITION" deny from "$ip" to any
  fi
  added=$((added + 1))
done < "$LIST_FILE"

echo
echo "Added:   $added"
echo "Skipped: $skipped"
echo
ufw status numbered
