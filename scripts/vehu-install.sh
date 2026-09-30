#!/usr/bin/env bash
# vehu-install.sh — install the FHIR server stack into a worldvista/vehu container.
#
# The one container-side install path, shared by the CI lane
# (ci-vehu-roundtrip.sh) and showfhir-setup.sh. Idempotent. For a remote host
# use Docker's own transport:  DOCKER_HOST=ssh://root@host scripts/vehu-install.sh Show
#
# Steps (each prints "STEP <name> OK|FAIL <detail>"; exit 1 on first FAIL):
#   web      vendored classic M-Web-Server (vendor/m-web-server) + ^%webhome
#   code     SYN* (VistA-FHIR-Data-Loader), %WC (vendor/m-wc), Codex src +
#            SYNWEBUT.m, C0RG, C0T, C0X (fhir-triple-store) —
#            later copies win, so Codex overrides the loader on name overlap.
#            Every copied .m is touched: docker cp keeps repo mtimes, and an
#            older source than the image's .o makes YDB keep the stale object.
#   link     ZLINK all copied routines, EN^C0RGSE, REG^C0XWS, EN^SYNWEBRG;
#            stale-object sweep
#   plugin   build the c0rgenc C plugin, export GTMXC_c0rgenc in ~/etc/env
#   config   LOADOS5 + EN^SYNOS5PT, GRAPHLABS=1, C0RG ENCODER=<--encoder>
#   www      vendor/tjson/web, the C0X UI and the CPRS demo dist (if built)
#   boot     check the image init restarts %webreq on container start
#   listener stop, wait 11s (listener polls its stop flag every 10s), go
#
# Usage: scripts/vehu-install.sh <container> [--encoder PLUGIN|JSNE] [--only step,step]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REHMP_ROOT="${REHMP_ROOT:-$ROOT/../rehmp}"
LOADER_ROOT="${LOADER_ROOT:-$ROOT/../VistA-FHIR-Data-Loader}"
C0T_SRC="${C0T_ROUTINES_DIR:-$ROOT/../C0T-terminology-gateway/routines}"
C0X_ROOT="${C0X_ROOT:-$ROOT/../fhir-triple-store}"
MUSER="${VEHU_M_USER:-vehu}"
P="/home/$MUSER/p"
WWW="/home/$MUSER/www"

C="${1:-}"; shift || true
ENCODER=PLUGIN
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --encoder) ENCODER="$2"; shift ;;
    --only) ONLY=",$2,"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ -n "$C" ]] || { echo "usage: $0 <container> [--encoder PLUGIN|JSNE] [--only step,...]" >&2; exit 2; }

want() { [[ -z "$ONLY" || "$ONLY" == *",$1,"* ]]; }
ok()   { echo "STEP $1 OK $2"; }
fail() { echo "STEP $1 FAIL $2"; exit 1; }
# Feed M lines to one login-env (su -) direct-mode session; prints its output.
mrun() { docker exec -i "$C" su - "$MUSER" -c 'cd /tmp && mumps -dir' 2>&1; }
rev()  { echo "$(git -C "$1" branch --show-current)@$(git -C "$1" rev-parse --short HEAD)$(git -C "$1" diff --quiet -- . || echo +dirty)"; }

# Routines this install owns, in copy order (later wins on name overlap).
routine_files() {
  ls "$LOADER_ROOT"/src/SYN*.m
  ls "$ROOT"/vendor/m-web-server/src/*.m "$ROOT"/vendor/m-wc/src/*.m "$ROOT"/src/*.m
  [[ -f "$ROOT/SYNWEBUT.m" ]] && echo "$ROOT/SYNWEBUT.m"
  ls "$REHMP_ROOT"/C0RG/*.m
  ls "$C0T_SRC"/C0TAPI.m "$C0T_SRC"/C0TLEX.m "$C0T_SRC"/C0TBSTS.m 2>/dev/null
  ls "$C0X_ROOT"/src/C0X*.m
}
routine_names() { routine_files | xargs -n1 basename | sed 's/\.m$//' | sort -u; }

echo "== vehu-install: container=$C encoder=$ENCODER docker=${DOCKER_HOST:-local} =="
echo "sources: codex=$(rev "$ROOT") loader=$(rev "$LOADER_ROOT") rehmp=$(rev "$REHMP_ROOT") c0x=$(rev "$C0X_ROOT")"
docker exec "$C" true 2>/dev/null || fail preflight "container $C not running"

if want web || want code; then
  n=0
  while IFS= read -r f; do
    # vendored web routines are named _web*.m on disk = %web* in M
    docker cp "$f" "$C:$P/" >/dev/null || fail code "docker cp $f"
    n=$((n+1))
  done < <(routine_files)
  docker exec "$C" bash -c "cd $P && touch *.m && chown $MUSER:$MUSER *.m" || fail code "touch/chown"
  printf '%s\n' "S ^%webhome=\"$WWW/\"" 'W "HOME=",^%webhome,!' H | mrun | grep -q "HOME=$WWW/" \
    || fail web "could not set ^%webhome"
  ok web "vendored M-Web-Server $(grep -o '`0\.[0-9.]*`' "$ROOT/vendor/m-web-server/README.md" | head -1 | tr -d '`'), ^%webhome=$WWW/"
  ok code "$n routine files copied+touched"
fi

if want link || want code; then
  # ZLINK takes the file name (_webreq), not the routine name (%webreq). Compile
  # errors are attributed per file; the vendored M-Web-Server has Cache-only
  # branches that YDB flags at compile time but never executes, so _web* is exempt.
  out="$( { routine_names | while read -r r; do printf 'W "@@%s",!\nZLINK "%s"\n' "$r" "$r"; done
            printf '%s\n' 'W "@@setup",!' 'D EN^C0RGSE' 'D REG^C0XWS' 'D EN^SYNWEBRG' 'H'; } | mrun )"
  zerr="$(awk '/@@/{sub(/.*@@/,""); cur=$0; next} /%YDB-E-/{print cur": "$0}' <<<"$out" | grep -v '^_web' | sort -u | head -3)"
  [[ -z "$zerr" ]] || fail link "$zerr"
  # stale sweep: $T(+1^R)="" means no source matches the linked object
  stale="$( { routine_names | sed 's/^_/%/' | while read -r r; do
               printf 'S X="+1^%s" I $T(@X)="" W "STALE:%s",!\n' "$r" "$r"; done; echo H; } \
           | mrun | grep -o 'STALE:[%A-Za-z0-9]*' | tr '\n' ' ')"
  [[ -z "$stale" ]] || fail link "stale objects: $stale"
  routes="$(printf '%s\n' 'N I,N S (I,N)=0 F  S I=$O(^%web(17.6001,I)) Q:+I=0  S N=N+1' 'W "ROUTES=",N,!' H | mrun | grep -o 'ROUTES=[0-9]*' | cut -d= -f2)"
  [[ "${routes:-0}" -gt 0 ]] || fail link "no routes in ^%web(17.6001)"
  ok link "$(routine_names | wc -l) routines linked, 0 stale, $routes routes"
fi

if want plugin; then
  FHIR_CONTAINER="$C" C0RGENC_DEST="/home/$MUSER/lib/c0rgenc" \
    "$REHMP_ROOT/plugin/c0rgenc/install-vehu10.sh" >/tmp/vehu-install-plugin.$$ 2>&1 \
    || fail plugin "$(tail -2 /tmp/vehu-install-plugin.$$ | tr '\n' ' ')"
  docker exec "$C" chown -R "$MUSER:$MUSER" "/home/$MUSER/lib/c0rgenc"
  rm -f /tmp/vehu-install-plugin.$$
  printf '%s\n' 'W "PING=",$&c0rgenc.ping,!' H | mrun | grep -q 'PING=1' || fail plugin "\$&c0rgenc.ping failed"
  ok plugin "\$&c0rgenc.ping=1"
fi

if want config; then
  out="$(printf '%s\n' 'D LOADOS5^SYNOS5LD' 'D EN^SYNOS5PT' \
          'S ^C0FHIR("EXPERIMENT","GRAPHLABS")=1' \
          "D SET^C0RGPAR(\"ENCODER\",\"$ENCODER\")" \
          'W "OS5=",$$COUNT^SYNOS5LD,!' 'W "GRAPHLABS=",$$ON^C0FHIRLG(),!' \
          'W "ENCODER=",$$GETPAR^C0RGPAR("ENCODER"),!' H | mrun)"
  os5="$(grep -o 'OS5=[0-9]*' <<<"$out" | cut -d= -f2)"
  [[ "${os5:-0}" -gt 0 ]] || fail config "sct2os5 empty after LOADOS5"
  grep -q 'GRAPHLABS=1' <<<"$out" || fail config "GRAPHLABS not on"
  grep -q "ENCODER=$ENCODER" <<<"$out" || fail config "ENCODER not $ENCODER"
  ok config "OS5=$os5 GRAPHLABS=1 ENCODER=$ENCODER"
fi

if want www; then
  v="$ROOT/vendor/tjson/web"
  docker exec "$C" mkdir -p "$WWW/filesystem/tjson/web" "$WWW/filesystem/c0x" "$WWW/demos/cprs"
  docker cp "$v/." "$C:$WWW/filesystem/tjson/web/" >/dev/null || fail www "tjson copy"
  for u in index.html app.js styles.css; do
    docker cp "$C0X_ROOT/ui/$u" "$C:$WWW/filesystem/c0x/$u" >/dev/null || fail www "c0x ui $u"
  done
  cprs="$REHMP_ROOT/ehmp-ui/rehmp-cprs-demo/dist"
  if [[ -f "$cprs/index.html" ]]; then
    docker cp "$cprs/." "$C:$WWW/demos/cprs/" >/dev/null || fail www "cprs copy"
    note="cprs dist copied"
  else
    note="cprs dist not built (skipped)"
  fi
  docker exec "$C" chown -R "$MUSER:$MUSER" "$WWW"
  ok www "tjson web; c0x ui; $note"
fi

if want boot; then
  # The image's /etc/init.d/vehuvista already runs job^%webreq(9080) on start
  # whenever _webreq.m is in p/ or r/ (sourcing ~/etc/env, so GTMXC_c0rgenc is
  # inherited). Adding a second start races it (flag stuck at "starting").
  docker exec "$C" grep -q 'job^%webreq' /etc/init.d/vehuvista || fail boot "init script does not start %webreq"
  docker exec "$C" test -f "$P/_webreq.m" || fail boot "$P/_webreq.m missing"
  ok boot "image init starts %webreq on container start (_webreq.m in p/)"
fi

if want listener; then
  printf '%s\n' 'D stop^%webreq' H | mrun >/dev/null
  sleep 11
  printf '%s\n' 'D go^%webreq' H | mrun >/dev/null
  state=""
  for _ in $(seq 1 15); do
    sleep 1
    state="$(printf '%s\n' 'W "L=",$G(^%webhttp(0,"listener")),!' H | mrun | grep -o 'L=[a-z]*' | cut -d= -f2)"
    [[ "$state" == running ]] && break
  done
  [[ "$state" == running ]] || fail listener "listener state '$state'"
  ok listener "running"
fi
echo "== vehu-install: done =="
