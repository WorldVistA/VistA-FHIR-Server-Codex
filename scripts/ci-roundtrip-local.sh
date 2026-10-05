#!/usr/bin/env bash
# ci-roundtrip-local.sh — the mechanical-correctness lane (sprint Day 2).
#
# One script, disposable container, full round trip:
#   A. docker run a fresh glilly/fhir-dev-server container (nothing shared)
#   B. wait for the M web listener
#   B3. build the c0rgenc encoder plugin (C0RG envelopes fail loud without it)
#   C. sync the working-tree routines into it (local-fhir-container-sync.sh)
#   D. generate one Synthea patient -> POST /addpatient?load=1 -> capture DFN
#   E. readback parity: source bundle resourceType counts vs GET /fhir?dfn=
#   F. CFH-WRITE-001 clinical write harness against the new patient
#   G. teardown (kept when --keep or when a stage fails)
#
# Evidence: docs/ci-reports/ROUNDTRIP_<UTC>.md (+ exit code for cron).
# Usage: scripts/ci-roundtrip-local.sh [--keep] [--port 19080]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPRS_HARNESS="${CPRS_HARNESS:-$ROOT/../CPRS-on-FHIR/harness/CFH-WRITE-001/harness.py}"
C0RGENC_INSTALL="${C0RGENC_INSTALL:-$ROOT/../rehmp/plugin/c0rgenc/install-vehu10.sh}"
SYN_SRC="${SYN_SRC:-$ROOT/../VistA-FHIR-Data-Loader/src}"
IMAGE="${CI_FHIR_IMAGE:-glilly/fhir-dev-server:latest}"
PORT="${CI_FHIR_PORT:-19080}"
KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --port) PORT="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="ci-roundtrip-$TS"
BASE="http://127.0.0.1:$PORT"
REPORT_DIR="${CI_REPORT_DIR:-$ROOT/docs/ci-reports}"
REPORT="$REPORT_DIR/ROUNDTRIP_$TS.md"
WORK="$(mktemp -d)"
mkdir -p "$REPORT_DIR"

declare -a ROWS
FAILED=0
row() { # row <stage> <PASS|FAIL> <detail>
  ROWS+=("| $1 | $2 | $3 |")
  echo "  [$2] $1 — $3"
  if [[ "$2" == "FAIL" ]]; then FAILED=1; fi
  return 0
}

finish() {
  {
    echo "# Round-trip CI — $TS"
    echo
    echo "Image \`$IMAGE\`, container \`$NAME\`, base \`$BASE\`."
    echo
    echo "| Stage | Result | Detail |"
    echo "|---|---|---|"
    printf '%s\n' "${ROWS[@]}"
    echo
    if [[ $FAILED -eq 0 ]]; then echo "**ROUNDTRIP OK**"; else echo "**ROUNDTRIP FAILED**"; fi
  } > "$REPORT"
  echo "report: $REPORT"
  if [[ $KEEP -eq 0 && $FAILED -eq 0 ]]; then
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  else
    echo "container kept for inspection: $NAME (port $PORT)"
  fi
  rm -rf "$WORK" 2>/dev/null || true
  exit $FAILED
}

echo "== ci-roundtrip: $NAME on $BASE =="

# A0. a failed run keeps its container for inspection; clear any previous
#     ci-roundtrip container on THIS port so it cannot block the next night
#     (other kept containers on other ports are left alone).
OLD="$(docker ps -a --format '{{.Names}} {{.Ports}}' | awk -v p="127.0.0.1:$PORT->" '$1 ~ /^ci-roundtrip-/ && index($0, p) {print $1}' | tr '\n' ' ')"
if [[ -n "$OLD" ]]; then docker rm -f $OLD >/dev/null 2>&1; row "A0 cleanup" INFO "removed previous container(s) on port $PORT: $OLD"; fi

# A. fresh container
if docker run -d --name "$NAME" -p "127.0.0.1:$PORT:9080" "$IMAGE" >/dev/null 2>&1; then
  row "A container up" PASS "$IMAGE"
else
  row "A container up" FAIL "docker run failed"; finish
fi

# B. VistA boot wait (the image's start.sh boots TaskMan/Rocto but does NOT
#    start the M web listener — the routine sync in stage C does that)
BOOTED=0
for _ in $(seq 1 60); do
  sleep 5
  if docker logs "$NAME" 2>&1 | grep -q "Starting Rocto"; then BOOTED=1; break; fi
done
if [[ $BOOTED -eq 1 ]]; then row "B vista boot" PASS "TaskMan/Rocto started"; else row "B vista boot" FAIL "no boot marker within 300s"; KEEP=1; finish; fi
sleep 10

# B2. the raw image ships without the M-Web-Server (%web*) routines; vendor
#     them from the always-restored vehu10 container's lib copy
if docker cp vehu10:/home/vehu/lib/M-Web-Server/src "$WORK/mws" >/dev/null 2>&1 \
   && docker cp "$WORK/mws/." "$NAME:/home/vehu/p/" >/dev/null 2>&1 \
   && docker exec "$NAME" bash -lc 'chown vehu:vehu /home/vehu/p/_web*.m /home/vehu/p/%web*.m 2>/dev/null; true'; then
  row "B2 web server routines" PASS "M-Web-Server src vendored from vehu10"
else
  row "B2 web server routines" FAIL "could not vendor %web* routines (is vehu10 up?)"; KEEP=1; finish
fi

# B3. C0RG envelopes fail loud (ENCODE^C0RGFENC) without the c0rgenc C plugin,
#     and the raw image lacks it. Build it before stage C starts the listener
#     so HTTP workers inherit GTMXC_c0rgenc.
if FHIR_CONTAINER="$NAME" "$C0RGENC_INSTALL" >"$WORK/c0rgenc.log" 2>&1 \
   && docker exec "$NAME" su - vehu -c 'mumps -run %XCMD "W \"ping=\",\$&c0rgenc.ping,!"' 2>&1 | grep -q 'ping=1'; then
  row "B3 c0rgenc plugin" PASS "built in container, \$&c0rgenc.ping=1"
else
  row "B3 c0rgenc plugin" FAIL "see c0rgenc.log: $(tail -1 "$WORK/c0rgenc.log" 2>/dev/null)"; KEEP=1; finish
fi

# B4. SYN loader routines + SCT->OS5 maps (same as showfhir-setup.sh). The
#     image's SYN*.m are older and its ^SYN sct2os5 has no prc/enc role maps,
#     so ~80% of Synthea Procedures fail "Code ... not mapped". docker cp keeps
#     repo mtimes, which are older than the image's compiled .o, so YDB would
#     keep the stale objects ($T returns "" -> "SYNDHP65 is not installed");
#     touch forces recompile on next link.
for f in "$SYN_SRC"/SYN*.m; do docker cp "$f" "$NAME:/home/vehu/p/" >/dev/null 2>&1; done
docker exec "$NAME" bash -c 'touch /home/vehu/p/SYN*.m; chown vehu:vehu /home/vehu/p/SYN*.m'
# One retry: 2026-10-04 failed once with OS5COUNT empty and replayed fine in
# the kept container; on a second failure the log tail goes into the report.
for try in 1 2; do
  printf '%s\n' 'D LOADOS5^SYNOS5LD' 'D EN^SYNOS5PT' \
    'W "OS5COUNT=",$$COUNT^SYNOS5LD,!' \
    'W "PRCADD=",$L($T(PRCADD^SYNDHP65))>0,!' 'H' \
    | docker exec -i "$NAME" su - vehu -c 'cd /tmp && mumps -dir' >"$WORK/os5.log" 2>&1
  echo "docker-exec-rc=$?" >>"$WORK/os5.log"
  OS5N="$(grep -o 'OS5COUNT=[0-9]*' "$WORK/os5.log" | cut -d= -f2)"
  [[ "${OS5N:-0}" -gt 0 ]] && break
  [[ $try -eq 1 ]] && { cp "$WORK/os5.log" "$WORK/os5-try1.log"; sleep 15; }
done
[[ -f "$WORK/os5-try1.log" ]] && row "B4 retry" INFO "first OS5 load attempt failed: $(grep -v -E '^\s*$|DBFILEXT' "$WORK/os5-try1.log" | tail -3 | tr '\n' ' ' | cut -c1-300)"
# SYN_SRC is the loader working tree: whatever branch is checked out, not master.
SYNREV="$(git -C "$SYN_SRC" branch --show-current)@$(git -C "$SYN_SRC" rev-parse --short HEAD)$(git -C "$SYN_SRC" diff --quiet -- . || echo +dirty)"
if [[ "${OS5N:-0}" -gt 0 ]] && grep -q 'PRCADD=1' "$WORK/os5.log"; then
  row "B4 SYN + OS5 maps" PASS "$(ls "$SYN_SRC"/SYN*.m | wc -l) SYN routines from $SYNREV, sct2os5 count=$OS5N, PRCADD^SYNDHP65 linked"
else
  row "B4 SYN + OS5 maps" FAIL "OS5COUNT='${OS5N:-}' os5.log tail: $(grep -v -E '^\s*$|DBFILEXT' "$WORK/os5.log" | tail -4 | tr '\n' ' ' | cut -c1-400)"; KEEP=1; finish
fi

# C. routine sync (zlinks src/*.m, registers routes, starts the listener)
if FHIR_CONTAINER="$NAME" FHIR_HTTP_BASE="$BASE" FHIR_REMOTE_P=/home/vehu/p \
   FHIR_REMOTE_WWW=/home/vehu/www/filesystem FHIR_M_USER=vehu \
   FHIR_MUMPS=/home/vehu/lib/gtm/mumps \
   FHIR_SKIP_RPC_DEMO=1 FHIR_SKIP_CPRS_DEMO=1 FHIR_SKIP_WRITE_DEMO=1 \
   "$ROOT/scripts/local-fhir-container-sync.sh" >"$WORK/sync.log" 2>&1; then
  row "C routine sync" PASS "working-tree src/*.m zlinked, listener up"
else
  row "C routine sync" FAIL "see sync.log tail: $(tail -1 "$WORK/sync.log" 2>/dev/null)"; KEEP=1; finish
fi
UP=0
for _ in $(seq 1 24); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/fhir" 2>/dev/null || echo 000)"
  [[ "$code" == "200" ]] && { UP=1; break; }
  sleep 5
done
if [[ $UP -eq 1 ]]; then row "C2 listener" PASS "GET /fhir 200"; else row "C2 listener" FAIL "no HTTP 200 within 120s of sync"; KEEP=1; finish; fi

# D. Synthea patient -> addpatient
SEED=$(( $(date +%s) % 100000 ))
if "$ROOT/scripts/synthea-one-patient.sh" -o "$WORK/syn" -s "$SEED" >"$WORK/synthea.log" 2>&1; then
  BUNDLE="$(ls -1t "$WORK"/syn/fhir/*.json 2>/dev/null | grep -v hospitalInformation | grep -v practitionerInformation | head -1)"
  if [[ -n "$BUNDLE" ]]; then
    row "D1 synthea generate" PASS "seed=$SEED $(basename "$BUNDLE")"
  else
    row "D1 synthea generate" FAIL "no patient bundle in output"; KEEP=1; finish
  fi
else
  row "D1 synthea generate" FAIL "see synthea.log: $(tail -1 "$WORK/synthea.log" 2>/dev/null)"; KEEP=1; finish
fi
HTTP="$(curl -sS -o "$WORK/add.json" -w '%{http_code}' --max-time 600 -H 'Expect:' \
  -H 'Content-Type: application/json' --data-binary "@$BUNDLE" "$BASE/addpatient?load=1" || echo 000)"
DFN="$(python3 -c "import json;print(json.load(open('$WORK/add.json')).get('dfn',''))" 2>/dev/null || true)"
if [[ ( "$HTTP" == "200" || "$HTTP" == "201" ) && -n "$DFN" ]]; then
  row "D2 addpatient" PASS "HTTP $HTTP dfn=$DFN $(python3 -c "
import json,collections;d=json.load(open('$WORK/add.json'))
e=collections.Counter(((d.get('domains') or {}).get('Procedure') or {}).get('entries') or [])
print(f\"loadStatus={d.get('loadStatus','')} Procedure={dict(e)}\")" 2>/dev/null)"
else
  row "D2 addpatient" FAIL "HTTP $HTTP dfn='$DFN' body: $(head -c 200 "$WORK/add.json" 2>/dev/null)"; KEEP=1; finish
fi

# E. readback parity
curl -sS --max-time 600 "$BASE/fhir?dfn=$DFN" -o "$WORK/readback.json" || true
PARITY="$(python3 - "$BUNDLE" "$WORK/readback.json" <<'PYEOF'
import json, sys, collections
src = json.load(open(sys.argv[1])); rb = json.load(open(sys.argv[2]))
def counts(b):
    c = collections.Counter()
    for e in b.get("entry", []):
        rt = (e.get("resource") or {}).get("resourceType")
        if rt: c[rt] += 1
    return c
s, r = counts(src), counts(rb)
missing = [t for t in s if t not in r]
print(f"src={sum(s.values())} readback={sum(r.values())} srcTypes={len(s)} rbTypes={len(r)} missingTypes={','.join(missing) or 'none'}")
ok = r.get("Patient", 0) >= 1 and sum(r.values()) >= 1
sys.exit(0 if ok else 1)
PYEOF
)"
if [[ $? -eq 0 ]]; then row "E readback parity" PASS "$PARITY"; else row "E readback parity" FAIL "$PARITY"; fi

# F. clinical write harness (frozen contract CFH-WRITE-001)
if python3 "$CPRS_HARNESS" --base "$BASE" --dfn "$DFN" >"$WORK/harness.log" 2>&1; then
  row "F write harness" PASS "13 assertions green (dfn=$DFN)"
else
  row "F write harness" FAIL "$(grep FAIL "$WORK/harness.log" | head -3 | tr '\n' ';')"; KEEP=1
fi

finish
