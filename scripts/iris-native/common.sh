# Shared helpers for a native IRIS Health install on Rocky Linux.
# Source this; do not execute it.
# The license key and the SuperUser password never belong in this file.

iris_native_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

codex_root() {
  cd "$(iris_native_dir)/../.." && pwd
}

vista_stack() {
  cd "$(iris_native_dir)/../../.." && pwd
}

# native_begin root@host
# Overrides ssh/scp in the caller to multiplex one connection.
native_begin() {
  HOST="${1:?root@host}"
  HOSTNAME_ONLY="${HOST#*@}"
  SSHCTL="/tmp/ssh-irisnative-$$"
  SSHMUX=(
    -o BatchMode=yes
    -o ConnectTimeout=20
    -o ConnectionAttempts=15
    -o ServerAliveInterval=30
    -o ServerAliveCountMax=240
    -o ControlMaster=auto
    -o "ControlPath=$SSHCTL"
    -o ControlPersist=600
    -o StrictHostKeyChecking=accept-new
  )
  ssh() { command ssh "${SSHMUX[@]}" "$@"; }
  scp() { command scp "${SSHMUX[@]}" "$@"; }
  trap 'command ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true' EXIT
}

# Pipe an M program to the host helper. The helper inserts the SuperUser
# login from /root/iris-install/superuser.pass and does not print it.
native_m() {
  local ns="${1:?namespace}"
  ssh "$HOST" "/usr/local/sbin/iris-session.sh ${ns}"
}

require_session_helper() {
  ssh "$HOST" 'test -x /usr/local/sbin/iris-session.sh' \
    || { echo "ERROR: /usr/local/sbin/iris-session.sh missing on $HOST; run install.sh first" >&2; exit 1; }
}

# Full public Caddyfile. public.sh and c0x.sh both write this so neither
# clobbers the other with a hardcoded domain.
native_caddyfile() {
  local domain="${1:?domain}"
  cat <<CADDY
${domain} {
	encode gzip

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
}
