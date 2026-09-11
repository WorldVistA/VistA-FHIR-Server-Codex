#!/usr/bin/env bash
# ci-roundtrip-local.sh — the mechanical-correctness lane (sprint Day 2).
#
# One script, disposable container, full round trip:
#   A. docker run a fresh glilly/fhir-dev-server container (nothing shared)
#   B. wait for the M web listener
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
REPORT_DIR="$ROOT/docs/ci-reports"
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
  row "D2 addpatient" PASS "HTTP $HTTP dfn=$DFN loadStatus=$(python3 -c "import json;print(json.load(open('$WORK/add.json')).get('loadStatus',''))" 2>/dev/null)"
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
