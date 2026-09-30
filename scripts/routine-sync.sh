#!/usr/bin/env bash
# Clone / pull FHIR routine repos and copy src/*.m to a destination (e.g. ~/p), then
# verify each deployed file matches the source byte-for-byte via SHA-256.
# The branch in routine-sync-repos.conf is the only branch used: clone checks it out,
# and every pull/sync checks out the same ref before pull --ff-only (no branch switching elsewhere).
#
# Config: copy routine-sync-repos.conf.example -> routine-sync-repos.conf (see example file).
# Env:
#   ROUTINE_SYNC_CONFIG   path to config (default: same dir as this script / routine-sync-repos.conf)
#   ROUTINE_SYNC_ROOT     parent for git clones (default: ~/vista-routine-src)
#   ROUTINE_SYNC_DEST     copy target (default: ~/p)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTINE_SYNC_CONFIG="${ROUTINE_SYNC_CONFIG:-$SCRIPT_DIR/routine-sync-repos.conf}"
ROUTINE_SYNC_ROOT="${ROUTINE_SYNC_ROOT:-$HOME/vista-routine-src}"
ROUTINE_SYNC_DEST="${ROUTINE_SYNC_DEST:-$HOME/p}"

usage() {
  sed -n '1,80p' "$0" | tail -n +2
  echo "Usage: $0 <command>"
  echo "  clone     — git clone each remote repo listed in config (skipped if dir exists)"
  echo "  pull      — git pull --ff-only on each repo (remote or local path)"
  echo "  sync      — pull, copy all src/*.m to DEST (later repos override same basename), verify checksums"
  echo "  verify    — checksum only: DEST must match sources (no git, no copy)"
  echo "  manifest  — print SHA256 lines for the merged view (basename only in comment) to stdout"
  echo ""
  echo "Config: $ROUTINE_SYNC_CONFIG"
  echo "Clone root: $ROUTINE_SYNC_ROOT  Dest: $ROUTINE_SYNC_DEST"
}

is_remote_url() {
  [[ "$1" == http://* || "$1" == https://* || "$1" == git@* ]]
}

expand_tilde() {
  local p="$1"
  case "$p" in
    "~") echo "$HOME" ;;
    "~/"*) echo "$HOME/${p#~/}" ;;
    *) echo "$p" ;;
  esac
}

repo_path_for() {
  local name="$1" url="$2"
  if is_remote_url "$url"; then
    echo "$ROUTINE_SYNC_ROOT/$name"
  else
    expand_tilde "$url"
  fi
}

sha256_of() {
  sha256sum -b "$1" | awk '{print $1}'
}

require_sha256sum() {
  command -v sha256sum >/dev/null 2>&1 || {
    echo "error: sha256sum not found (install coreutils)" >&2
    exit 1
  }
}

read_config_lines() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    echo "$line"
  done < "$ROUTINE_SYNC_CONFIG"
}

parse_line() {
  # Sets: _name _url _branch _srcdir
  IFS='|' read -r _name _url _branch _srcdir <<<"$1"
  _name="${_name//[[:space:]]/}"
  _url="${_url#"${_url%%[![:space:]]*}"}"
  _url="${_url%"${_url##*[![:space:]]}"}"
  _branch="${_branch#"${_branch%%[![:space:]]*}"}"
  _branch="${_branch%"${_branch##*[![:space:]]}"}"
  _srcdir="${_srcdir#"${_srcdir%%[![:space:]]*}"}"
  _srcdir="${_srcdir%"${_srcdir##*[![:space:]]}"}"
  if [[ -z "$_branch" ]]; then _branch="master"; fi
  if [[ -z "$_srcdir" ]]; then _srcdir="src"; fi
}

clone_one() {
  local name="$1" url="$2" branch="$3"
  local dest
  dest="$(repo_path_for "$name" "$url")"
  if ! is_remote_url "$url"; then
    if [[ ! -d "$dest/.git" ]]; then
      echo "error: local repo missing or not a git dir: $dest" >&2
      return 1
    fi
    echo "clone: skip local $dest"
    return 0
  fi
  mkdir -p "$ROUTINE_SYNC_ROOT"
  if [[ -d "$dest/.git" ]]; then
    echo "clone: exists $dest — checkout $branch (config is source of truth)"
    # Ensure ref exists even for older single-branch clones (may need rm -rf and re-clone if this fails)
    git -C "$dest" fetch origin "+refs/heads/$branch:refs/remotes/origin/$branch" 2>/dev/null \
      || git -C "$dest" fetch --tags --prune origin
    git -C "$dest" checkout "$branch" 2>/dev/null \
      || git -C "$dest" checkout -B "$branch" --track "origin/$branch" || {
      echo "error: cannot checkout branch '$branch' in $dest; fix the branch in $ROUTINE_SYNC_CONFIG or remove the clone" >&2
      return 1
    }
    return 0
  fi
  echo "clone: $url -> $dest (branch $branch)"
  git clone -b "$branch" --single-branch "$url" "$dest"
}

pull_one() {
  local name="$1" url="$2" branch="$3"
  local dest
  dest="$(repo_path_for "$name" "$url")"
  if [[ ! -d "$dest/.git" ]]; then
    echo "error: not a git repository: $dest" >&2
    return 1
  fi
  echo "pull: $dest (branch $branch)"
  git -C "$dest" fetch --tags --prune origin
  git -C "$dest" checkout "$branch"
  git -C "$dest" pull --ff-only origin "$branch"
}

cmd_clone() {
  local line
  while IFS= read -r line; do
    parse_line "$line"
    clone_one "$_name" "$_url" "$_branch"
  done < <(read_config_lines)
}

cmd_pull() {
  local line
  while IFS= read -r line; do
    parse_line "$line"
    pull_one "$_name" "$_url" "$_branch"
  done < <(read_config_lines)
}

cmd_sync() {
  require_sha256sum
  mkdir -p "$ROUTINE_SYNC_DEST"
  cmd_pull
  local line name url branch srcdir path srcdir_path f bn hs hd
  while IFS= read -r line; do
    parse_line "$line"
    name="$_name"
    url="$_url"
    branch="$_branch"
    srcdir="$_srcdir"
    path="$(repo_path_for "$name" "$url")"
    srcdir_path="$path/$srcdir"
    if [[ ! -d "$srcdir_path" ]]; then
      echo "error: missing src dir: $srcdir_path" >&2
      exit 1
    fi
    shopt -s nullglob
    for f in "$srcdir_path"/*.m; do
      bn="$(basename "$f")"
      cp -a "$f" "$ROUTINE_SYNC_DEST/$bn"
      hs="$(sha256_of "$f")"
      hd="$(sha256_of "$ROUTINE_SYNC_DEST/$bn")"
      if [[ "$hs" != "$hd" ]]; then
        echo "error: checksum mismatch after copy: $bn ($hs vs $hd)" >&2
        exit 1
      fi
      echo "ok $bn <= $f"
    done
    shopt -u nullglob
  done < <(read_config_lines)
}

cmd_verify() {
  require_sha256sum
  # Same basename precedence as sync: later config rows win.
  declare -A src_for
  local line name url branch srcdir path srcdir_path f bn
  while IFS= read -r line; do
    parse_line "$line"
    name="$_name"
    url="$_url"
    branch="$_branch"
    srcdir="$_srcdir"
    path="$(repo_path_for "$name" "$url")"
    srcdir_path="$path/$srcdir"
    if [[ ! -d "$srcdir_path" ]]; then
      echo "error: missing src dir: $srcdir_path" >&2
      exit 1
    fi
    shopt -s nullglob
    for f in "$srcdir_path"/*.m; do
      bn="$(basename "$f")"
      src_for[$bn]="$f"
    done
    shopt -u nullglob
  done < <(read_config_lines)

  local errors=0 hs hd
  for bn in "${!src_for[@]}"; do
    f="${src_for[$bn]}"
    if [[ ! -f "$ROUTINE_SYNC_DEST/$bn" ]]; then
      echo "missing in DEST: $bn (expected from $f)" >&2
      errors=1
      continue
    fi
    hs="$(sha256_of "$f")"
    hd="$(sha256_of "$ROUTINE_SYNC_DEST/$bn")"
    if [[ "$hs" != "$hd" ]]; then
      echo "mismatch: $bn  src=$hs  dest=$hd  ($f)" >&2
      errors=1
    else
      echo "ok $bn"
    fi
  done
  [[ "$errors" -eq 0 ]] || exit 1
}

cmd_manifest() {
  require_sha256sum
  # Last repo in config wins for duplicate basenames (same rule as sync).
  declare -A last_hash
  declare -A last_path
  local line name url branch srcdir path srcdir_path f bn h
  while IFS= read -r line; do
    parse_line "$line"
    name="$_name"
    url="$_url"
    branch="$_branch"
    srcdir="$_srcdir"
    path="$(repo_path_for "$name" "$url")"
    srcdir_path="$path/$srcdir"
    if [[ ! -d "$srcdir_path" ]]; then
      echo "error: missing src dir: $srcdir_path" >&2
      exit 1
    fi
    shopt -s nullglob
    for f in "$srcdir_path"/*.m; do
      bn="$(basename "$f")"
      h="$(sha256_of "$f")"
      last_hash[$bn]="$h"
      last_path[$bn]="$f"
    done
    shopt -u nullglob
  done < <(read_config_lines)
  local k
  for k in "${!last_hash[@]}"; do
    printf '%s  %s\n' "${last_hash[$k]}" "$k"
  done | sort -k2
}

main() {
  local cmd="${1:-}"
  if [[ -z "$cmd" || "$cmd" == -h || "$cmd" == --help ]]; then
    usage
    exit 2
  fi
  if [[ ! -f "$ROUTINE_SYNC_CONFIG" ]]; then
    echo "error: config not found: $ROUTINE_SYNC_CONFIG" >&2
    echo "  cp \"$SCRIPT_DIR/routine-sync-repos.conf.example\" \"$ROUTINE_SYNC_CONFIG\" and edit." >&2
    exit 1
  fi
  case "$cmd" in
    clone) cmd_clone ;;
    pull) cmd_pull ;;
    sync) cmd_sync ;;
    verify) cmd_verify ;;
    manifest) cmd_manifest ;;
    *) echo "unknown command: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
