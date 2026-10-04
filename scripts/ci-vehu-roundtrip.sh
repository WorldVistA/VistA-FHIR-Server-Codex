#!/usr/bin/env bash
# ci-vehu-roundtrip.sh — leveled round trip on a fresh worldvista/vehu:latest.
#
# Plan + level definitions: docs/showfhir/VEHU_ROUNDTRIP_PLAN.md. Every level
# adds capability and a gate; --level N stops after level N.
#   L0 boot      fresh container, boot marker, $ZYRELEASE, image digest
#   L1 web       vehu-install web/boot/listener; /ping 200; survives docker restart
#   L2 code      vehu-install code/link; /fhir/metadata 200; XINDEX (no new F)
#   L3 encoder   c0rgenc plugin; SMOKE^C0RGFENCT PATH=PLUGIN + oracle
#   L4 maps      LOADOS5/SYNOS5PT/GRAPHLABS; fixed SCT->OS5 probe list
#   L5 patient   JOHN-SALT + fixed + random Synthea: per-domain error rates,
#                per-type readback, strict JSON, CFH-WRITE-001
#   L6 cohort    first N of the synthea-1000 pool (CI_VEHU_COHORT_N, default 20);
#                honest per-domain ok% vs scripts/vehu-l6-baseline.json
#   L7 UI        CPRS demo dist, TJSON browser, C0X UI, /fhir index; rehmp-smoke
#   L8 C0X       reindex, populationIndexed, SPARQL IPP x6, smoke-quality-host
#   L9 quality   ENCODER=JSNE; C0X IPP -> SETPOP -> cds1 official CQL x6;
#                nesting + golden table (once frozen); DEQM summary gate
#   L10 resil.   docker restart + full reinstall keep service and data
#
# Evidence: docs/ci-reports/VEHU_ROUNDTRIP_<UTC>.md (+ exit code for cron).
# Usage: scripts/ci-vehu-roundtrip.sh [--level N (default 10)] [--keep] [--port 19091]
#                                     [--encoder PLUGIN|JSNE]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WS="$(cd "$ROOT/.." && pwd)"
IMAGE="${CI_VEHU_IMAGE:-worldvista/vehu:latest}"
PORT="${CI_VEHU_PORT:-19091}"
CPRS_HARNESS="${CPRS_HARNESS:-$WS/CPRS-on-FHIR/harness/CFH-WRITE-001/harness.py}"
JOHN="${JOHN_SALT_BUNDLE:-$WS/WVEHR-on-FHIR/bundles/JOHN-SALT.json}"
FIXED_SEED="${CI_VEHU_FIXED_SEED:-4244}"
LEVEL=10
KEEP=0
ENCODER=PLUGIN
while [[ $# -gt 0 ]]; do
  case "$1" in
    --level) LEVEL="$2"; shift ;;
    --keep) KEEP=1 ;;
    --port) PORT="$2"; shift ;;
    --encoder) ENCODER="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="ci-vehu-$TS"
BASE="http://127.0.0.1:$PORT"
REPORT_DIR="${CI_REPORT_DIR:-$ROOT/docs/ci-reports}"
REPORT="$REPORT_DIR/VEHU_ROUNDTRIP_$TS.md"
WORK="$(mktemp -d)"
mkdir -p "$REPORT_DIR"

declare -a ROWS PROV
FAILED=0
row() { # row <stage> <PASS|FAIL|INFO> <detail>
  ROWS+=("| $1 | $2 | $3 |")
  echo "  [$2] $1 — $3"
  [[ "$2" == "FAIL" ]] && FAILED=1
  return 0
}
rev() { echo "$(git -C "$1" branch --show-current)@$(git -C "$1" rev-parse --short HEAD)$(git -C "$1" diff --quiet -- . || echo +dirty)"; }
mrun() { docker exec -i "$NAME" su - vehu -c 'cd /tmp && mumps -dir' 2>&1; }
http() { curl -sS -o /dev/null -w '%{http_code}' --max-time "${2:-30}" "$BASE$1" 2>/dev/null || echo 000; }

finish() {
  {
    echo "# VEHU round trip — $TS"
    echo
    echo "Image \`$IMAGE\`, container \`$NAME\`, base \`$BASE\`, levels 0–$LEVEL, encoder \`$ENCODER\`."
    echo
    printf -- '- %s\n' "${PROV[@]}"
    echo
    echo "| Stage | Result | Detail |"
    echo "|---|---|---|"
    printf '%s\n' "${ROWS[@]}"
    echo
    if [[ -n "${L9TABLE:-}" ]]; then echo "## L9 measures (cds1 official CQL over the C0X IPP cohort)"; echo; echo "$L9TABLE"; echo; fi
    if [[ $FAILED -eq 0 ]]; then echo "**VEHU ROUNDTRIP OK (L0–L$LEVEL)**"; else echo "**VEHU ROUNDTRIP FAILED**"; fi
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
done_level() { [[ "$LEVEL" -le "$1" ]] && finish; return 0; }
# install <step,...> — run vehu-install steps; returns the STEP lines, fails the row on FAIL
install() {
  "$ROOT/scripts/vehu-install.sh" "$NAME" --encoder "$ENCODER" --only "$1" >"$WORK/install-$1.log" 2>&1
  local rc=$?
  grep '^STEP' "$WORK/install-$1.log"
  return $rc
}

echo "== ci-vehu-roundtrip: $NAME on $BASE (L0–L$LEVEL, encoder=$ENCODER) =="
PROV+=("sources: codex \`$(rev "$ROOT")\`, loader \`$(rev "$WS/VistA-FHIR-Data-Loader")\`, rehmp \`$(rev "$WS/rehmp")\`, CPRS-on-FHIR \`$(rev "$WS/CPRS-on-FHIR")\`")

# ---- L0 boot -------------------------------------------------------------
# A failed run keeps its container for inspection; it lives until the next run,
# which clears it so a kept container can never hold the port and block the
# night after (2026-10-03). CI_VEHU_KEEP_OLD=1 skips the cleanup.
if [[ "${CI_VEHU_KEEP_OLD:-0}" != "1" ]]; then
  OLD="$(docker ps -a --format '{{.Names}}' | grep '^ci-vehu-' | tr '\n' ' ')"
  if [[ -n "$OLD" ]]; then
    docker rm -f $OLD >/dev/null 2>&1
    row "L0 cleanup" INFO "removed previous lane container(s): $OLD"
  fi
fi
DIGEST="$(docker image inspect --format '{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null | sed 's/.*@//' | cut -c1-19)"
if docker run -d --name "$NAME" -p "127.0.0.1:$PORT:9080" "$IMAGE" >/dev/null 2>&1; then
  BOOTED=0
  for _ in $(seq 1 60); do
    sleep 5
    docker logs "$NAME" 2>&1 | grep -q "Starting Rocto" && { BOOTED=1; break; }
  done
  sleep 5
  ZV="$(printf '%s\n' 'W "ZV=",$ZYRELEASE,!' H | mrun | grep -o 'ZV=.*' | cut -d= -f2)"
  if [[ $BOOTED -eq 1 && -n "$ZV" ]]; then
    row "L0 boot" PASS "$ZV, image $DIGEST"
    PROV+=("image \`$IMAGE\` digest \`$DIGEST\`, \`$ZV\`")
  else
    row "L0 boot" FAIL "booted=$BOOTED zv='$ZV'"; KEEP=1; finish
  fi
else
  row "L0 boot" FAIL "docker run failed (port $PORT in use?)"; KEEP=1; finish
fi
done_level 0

# ---- L1 web listener ------------------------------------------------------
# code must be present for %webreq; L1 installs everything but only gates web.
if out="$(install web,code,link,boot,listener)"; then
  p="$(http /ping)"
  if [[ "$p" == 200 ]]; then row "L1 web listener" PASS "$(grep -E 'STEP (web|boot|listener)' <<<"$out" | cut -d' ' -f4- | tr '\n' ';') /ping 200"
  else row "L1 web listener" FAIL "/ping $p"; KEEP=1; finish; fi
else
  row "L1 web listener" FAIL "$(grep FAIL <<<"$out" || tail -1 "$WORK"/install-*.log)"; KEEP=1; finish
fi
docker restart "$NAME" >/dev/null 2>&1
UP=0
for _ in $(seq 1 40); do sleep 5; [[ "$(http /fhir/metadata 10)" == 200 ]] && { UP=1; break; }; done
LST="$(printf '%s\n' 'W "L=",$G(^%webhttp(0,"listener")),!' H | mrun | grep -o 'L=[a-z]*' | cut -d= -f2)"
if [[ $UP -eq 1 && "$LST" == running ]]; then row "L1 restart" PASS "docker restart -> listener running, /fhir/metadata 200 (image init)"
else row "L1 restart" FAIL "up=$UP listener='$LST'"; KEEP=1; finish; fi
done_level 1

# ---- L2 code + XINDEX -------------------------------------------------------
m="$(http /fhir/metadata)"
if [[ "$m" == 200 ]]; then row "L2 code install" PASS "$(grep -E 'STEP (code|link)' "$WORK"/install-*.log | cut -d' ' -f4- | tr '\n' ';') /fhir/metadata 200"
else row "L2 code install" FAIL "/fhir/metadata $m"; KEEP=1; finish; fi
{ printf '%s\n' 'S DUZ=.5,DUZ(0)="@",U="^",DT=$$DT^XLFDT' 'D ^XINDEX'
  { ls "$WS"/VistA-FHIR-Data-Loader/src/SYN*.m "$ROOT"/src/*.m "$WS"/rehmp/C0RG/*.m "$ROOT"/SYNWEBUT.m; } | xargs -n1 basename | sed 's/\.m$//' | sort -u
  printf '%s\n' '' '' '' 'NO' 'NO' 'NO' 'NO' '' '' '' '' 'H'; } | mrun > "$WORK/xindex.log"
if XR="$(python3 "$ROOT/scripts/xindex-gate.py" "$WORK/xindex.log")"; then row "L2 XINDEX" PASS "$(head -1 <<<"$XR")"
else row "L2 XINDEX" FAIL "$(tr '\n' ' ' <<<"$XR" | cut -c1-400)"; cp "$WORK/xindex.log" "$REPORT_DIR/VEHU_XINDEX_$TS.log"; fi
done_level 2

# ---- L3 encoder -----------------------------------------------------------
if out="$(install plugin)"; then
  SM="$(docker exec "$NAME" su - vehu -c 'mumps -run SMOKE^C0RGFENCT' 2>&1)"
  if grep -q 'PATH=PLUGIN' <<<"$SM" && grep -q 'ORACLE OK' <<<"$SM"; then
    row "L3 encoder" PASS "$(cut -d' ' -f4- <<<"$out"); SMOKE^C0RGFENCT $(grep -o 'PATH=[A-Z]*' <<<"$SM" | head -1), ORACLE OK"
  else row "L3 encoder" FAIL "SMOKE: $(tr '\n' ' ' <<<"$SM" | cut -c1-200)"; fi
else row "L3 encoder" FAIL "$(grep FAIL <<<"$out")"; KEEP=1; finish; fi
# listener must be restarted to inherit GTMXC_c0rgenc (11s stop/go rule)
install listener >/dev/null || { row "L3 listener restart" FAIL "listener did not return"; KEEP=1; finish; }
done_level 3

# ---- L4 maps + flags --------------------------------------------------------
if out="$(install config)"; then
  PROBES="171207006=3048M 710824005=6366O 710841007=1952O 428211000124100=6120M 713106006=8937L 430193006=2578H 34043003=0155H 866148006=1831I 763302001=4519L 73761001=1698M"
  got="$( { for p in $PROBES; do printf 'W "%s=",$P($$MAP^SYNDHPMP("sct2os5prc",%s),U,2),!\n' "${p%%=*}" "${p%%=*}"; done; echo H; } | mrun | grep -oE '^[0-9]+=[0-9A-Z]*')"
  bad=""; for p in $PROBES; do grep -qx "$p" <<<"$got" || bad+="${p%%=*} "; done
  if [[ -z "$bad" ]]; then row "L4 maps + flags" PASS "$(cut -d' ' -f4- <<<"$out"); $(wc -w <<<"$PROBES") SCT->OS5 probes match"
  else row "L4 maps + flags" FAIL "probe mismatch: $bad"; fi
else row "L4 maps + flags" FAIL "$(grep FAIL <<<"$out")"; KEEP=1; finish; fi
done_level 4

# ---- L5 one-patient round trips ----------------------------------------------
# load <label> <bundle> — POST, then gate per-domain error rates, readback, JSON
load() {
  local label="$1" bundle="$2" code dfn
  shift 2  # remaining args: Domain=maxErr overrides for ci-vehu-l5-check.py
  code="$(curl -sS -o "$WORK/$label.add.json" -w '%{http_code}' --max-time 900 -H 'Expect:' \
    -H 'Content-Type: application/json' --data-binary "@$bundle" "$BASE/addpatient?load=1" || echo 000)"
  dfn="$(python3 -c "import json;print(json.load(open('$WORK/$label.add.json')).get('dfn',''))" 2>/dev/null)"
  if [[ ( "$code" == 200 || "$code" == 201 ) && -n "$dfn" ]]; then :; else
    row "L5 $label addpatient" FAIL "HTTP $code dfn='$dfn'"; return 1; fi
  curl -sS --max-time 900 "$BASE/fhir?dfn=$dfn" -o "$WORK/$label.rb.json"
  python3 "$ROOT/scripts/ci-vehu-l5-check.py" "$bundle" "$WORK/$label.add.json" "$WORK/$label.rb.json" "$@" > "$WORK/$label.check" 2>&1
  local rc=$?
  if [[ $rc -eq 0 ]]; then row "L5 $label" PASS "dfn=$dfn $(tr '\n' ' ' < "$WORK/$label.check")"
  else row "L5 $label" FAIL "dfn=$dfn $(tr '\n' ' ' < "$WORK/$label.check")"; fi
  eval "DFN_$label=$dfn"
}
syn() { # syn <seed> -> prints bundle path
  "$ROOT/scripts/synthea-one-patient.sh" -o "$WORK/syn-$1" -s "$1" >"$WORK/synthea-$1.log" 2>&1
  ls -1t "$WORK/syn-$1"/fhir/*.json 2>/dev/null | grep -v -e hospitalInformation -e practitionerInformation | head -1
}
# JOHN-SALT on stock VEHU: INR (#60 5110) has no #60.03 collection samples and
# ISI rejects one GLUCOSE RESULT_DT -> 3/22 Lab errors are a known data gap.
if [[ -f "$JOHN" ]]; then load john "$JOHN" Lab=0.14; else row "L5 john" FAIL "golden bundle missing: $JOHN"; fi
B="$(syn "$FIXED_SEED")"
if [[ -n "$B" ]]; then load fixed "$B"; else row "L5 fixed" FAIL "synthea seed $FIXED_SEED produced no bundle"; fi
RSEED=$(( $(date +%s) % 100000 ))
B="$(syn "$RSEED")"
if [[ -n "$B" ]]; then row "L5 random seed" INFO "seed=$RSEED $(basename "$B")"; load random "$B"
else row "L5 random" FAIL "synthea seed $RSEED produced no bundle"; fi
if [[ -n "${DFN_fixed:-}" ]]; then
  if python3 "$CPRS_HARNESS" --base "$BASE" --dfn "$DFN_fixed" >"$WORK/harness.log" 2>&1; then
    row "L5 CFH-WRITE-001" PASS "13 assertions green (dfn=$DFN_fixed)"
  else row "L5 CFH-WRITE-001" FAIL "$(grep FAIL "$WORK/harness.log" | head -3 | tr '\n' ';')"; fi
fi
done_level 5

# ---- L6 cohort load ---------------------------------------------------------
# Fixed slice of the synthea-1000 pool (sorted names), so the golden cohort and
# the measure table are reproducible. CI_VEHU_COHORT_N: 20 nightly, 180 weekly.
COHORT_DIR="${CI_VEHU_COHORT_DIR:-$WS/HL7-FHIR-quality-testing/2026/patients/raw/synthea-1000-20260804-20260804/fhir}"
COHORT_N="${CI_VEHU_COHORT_N:-20}"
mkdir -p "$WORK/cohort"
T0=$(date +%s); n=0; bad=0
while IFS= read -r b; do
  n=$((n+1))
  c="$(curl -sS -o "$WORK/cohort/$(printf %03d $n).json" -w '%{http_code}' --max-time 900 -H 'Expect:' \
    -H 'Content-Type: application/json' --data-binary "@$b" "$BASE/addpatient?load=1" || echo 000)"
  [[ "$c" == 200 || "$c" == 201 ]] || { bad=$((bad+1)); echo "cohort $n HTTP $c $(basename "$b")" >> "$WORK/cohort.err"; }
done < <(ls "$COHORT_DIR"/*.json | grep -v -e hospitalInformation -e practitionerInformation | sort | head -"$COHORT_N")
SECS=$(( $(date +%s) - T0 ))
if [[ -f "$ROOT/scripts/vehu-l6-baseline.json" ]]; then
  RATES="$(python3 "$ROOT/scripts/ci-vehu-l6-rates.py" "$WORK/cohort")"; RC=$?
elif [[ $bad -eq 0 ]]; then  # first clean load records the honest baseline (commit it)
  RATES="$(python3 "$ROOT/scripts/ci-vehu-l6-rates.py" "$WORK/cohort" --update)"; RC=$?
else
  RATES="$(python3 "$ROOT/scripts/ci-vehu-l6-rates.py" "$WORK/cohort")"; RC=1
fi
if [[ $bad -eq 0 && $RC -eq 0 ]]; then row "L6 cohort load" PASS "$n patients in ${SECS}s; $(tr '\n' ' ' <<<"$RATES")"
else row "L6 cohort load" FAIL "$n patients, $bad HTTP failures, ${SECS}s; $(tr '\n' ' ' <<<"$RATES")"; fi
done_level 6

# ---- L7 UI ------------------------------------------------------------------
install www >/dev/null || row "L7 www install" FAIL "$(grep FAIL "$WORK/install-www.log")"
declare -A UI=( [/demos/cprs/index.html]=200 [/demos/cprs/version.json]=200 [/filesystem/tjson/web/index.js]=200
                [/filesystem/c0x/index.html]=200 [/fhir]=200 )
uibad=""; for u in "${!UI[@]}"; do c="$(http "$u")"; [[ "$c" == "${UI[$u]}" ]] || uibad+="$u=$c "; done
SERVED="$(curl -sS --max-time 20 "$BASE/demos/cprs/version.json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("commit",""))' 2>/dev/null)"
LOCALV="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("commit",""))' "$WS/rehmp/ehmp-ui/rehmp-cprs-demo/dist/version.json" 2>/dev/null)"
if [[ -z "$uibad" && "$SERVED" == "$LOCALV" ]]; then row "L7 UI" PASS "${#UI[@]} UI paths 200; CPRS demo serves $SERVED (= local dist)"
else row "L7 UI" FAIL "bad: ${uibad:-none}; served '$SERVED' vs local dist '$LOCALV'"; fi
HEADV="$(git -C "$WS/rehmp" log -1 --format=%h -- ehmp-ui/rehmp-cprs-demo)"
[[ "${LOCALV%-dirty}" == "$HEADV" ]] || row "L7 CPRS dist age" INFO "local dist built from $LOCALV; rehmp demo HEAD is $HEADV (rebuild: cd rehmp/ehmp-ui/rehmp-cprs-demo && npm run build)"
if [[ -n "${DFN_fixed:-}" ]]; then
  if FHIR_HTTP_BASE="$BASE" "$ROOT/scripts/rehmp-smoke.sh" "$DFN_fixed" >"$WORK/rehmp-smoke.log" 2>&1; then
    row "L7 rehmp-smoke" PASS "$(tail -1 "$WORK/rehmp-smoke.log" | cut -c1-160)"
  else row "L7 rehmp-smoke" FAIL "$(grep -iE 'fail|error' "$WORK/rehmp-smoke.log" | head -2 | tr '\n' ' ' | cut -c1-240)"; fi
fi
done_level 7

# ---- L8 population layer (C0X) ------------------------------------------------
MEASURES=(CMS165v14 CMS122v14 CMS130v14 CMS125v14 CMS138v14 CMS2v15)
curl -sS -X POST --max-time 900 "$BASE/c0x/index/reindex?max=1000&start=0" -o "$WORK/reindex.json" >/dev/null 2>&1
curl -sS --max-time 60 "$BASE/c0x/index/stat" -o "$WORK/idxstat.json"
POPN="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("populationIndexed",d.get("patients","")))' "$WORK/idxstat.json" 2>/dev/null)"
IPPS=""; ippbad=""
for m in "${MEASURES[@]}"; do
  curl -sS --max-time 300 "$BASE/c0x/cohort?measure=$m" -o "$WORK/cohort-$m.json"
  k="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("ippCount",len(d.get("patients") or [])))' "$WORK/cohort-$m.json" 2>/dev/null)"
  [[ -n "$k" ]] || ippbad+="$m "
  IPPS+="$m=$k "
done
if [[ -n "$POPN" && -z "$ippbad" ]]; then row "L8 population (C0X)" PASS "populationIndexed=$POPN; SPARQL IPP: $IPPS"
else row "L8 population (C0X)" FAIL "populationIndexed='$POPN' bad presets: ${ippbad:-none}; $IPPS"; fi
if "$ROOT/scripts/smoke-quality-host.sh" ci-vehu "$BASE" "${DFN_fixed:-}" >"$WORK/qsmoke.log" 2>&1; then
  row "L8 smoke-quality-host" PASS "$(grep -c PASS "$WORK/qsmoke.log") checks"
else row "L8 smoke-quality-host" FAIL "$(grep FAIL "$WORK/qsmoke.log" | head -3 | tr '\n' ';' | cut -c1-300)"; fi
done_level 8

# ---- L9 quality: C0X IPP -> SETPOP -> cds1 official CQL, under ENCODER=JSNE -------
"$ROOT/scripts/vehu-install.sh" "$NAME" --encoder JSNE --only config,listener >"$WORK/install-jsne.log" 2>&1 \
  || row "L9 encoder JSNE" FAIL "$(grep FAIL "$WORK/install-jsne.log")"
printf '%s\n' 'D SEED^C0FQUAL' 'K ^C0FQUAL("POP"),^C0FQUAL("SUM"),^C0FQUAL("REEVAL")' H | mrun >/dev/null
declare -a L9ROWS
for m in "${MEASURES[@]}"; do
  # /c0x/cohort returns patients as an object: {"0":count,"1":{dfn,...},...}
  dfns="$(python3 -c 'import json,sys;p=json.load(open(sys.argv[1])).get("patients") or {};v=p.values() if isinstance(p,dict) else p;print(",".join(str(x["dfn"]) for x in v if isinstance(x,dict) and x.get("dfn")))' "$WORK/cohort-$m.json" 2>/dev/null)"
  ippc="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("ippCount",0))' "$WORK/cohort-$m.json" 2>/dev/null)"
  if [[ -z "$dfns" && "${ippc:-0}" -gt 0 ]]; then L9ROWS+=("$m|$ippc|-|-|-|-|could not read DFNs from /c0x/cohort"); continue; fi
  if [[ -z "$dfns" ]]; then L9ROWS+=("$m|0|-|-|-|-|empty C0X IPP"); continue; fi
  curl -sS --max-time 120 -X POST -H 'Content-Type: application/json' -d "{\"measure\":\"$m\",\"dfns\":\"$dfns\"}" "$BASE/c0x/cohort/use" -o "$WORK/use-$m.json"
  code="$(curl -sS -o "$WORK/reeval-$m.json" -w '%{http_code}' --max-time 60 -X POST -H 'Content-Type: application/json' -d '{}' "$BASE/fhir-quality-reeval?measure=$m" || echo 000)"
  st=""
  for _ in $(seq 1 80); do
    sleep 9
    st="$(curl -sS --max-time 30 "$BASE/fhir-quality-dashboards/$m" 2>/dev/null | grep -oE 'id="reevalStatus"[^>]*>[^<]+' | head -1 | sed 's/.*>//')"
    case "$st" in done*|Done*|error*|Error*) break ;; esac
  done
  sum="$( { printf 'W "SUM=",$G(^C0FQUAL("SUM","%s")),!\n' "$m"; echo H; } | mrun | grep -o 'SUM=.*' | cut -d= -f2-)"
  L9ROWS+=("$m|$(tr ',' '\n' <<<"$dfns" | wc -l)|$(cut -d^ -f2 <<<"$sum")|$(cut -d^ -f3 <<<"$sum")|$(cut -d^ -f4 <<<"$sum")|$(cut -d^ -f5 <<<"$sum")|accept=$code status=${st:-none}")
done
python3 "$ROOT/scripts/ci-vehu-l9-table.py" "${L9ROWS[@]}" > "$WORK/l9.txt"; RC=$?
if [[ $RC -eq 0 ]]; then row "L9 quality (cds1 CQL, JSNE)" PASS "$(head -1 "$WORK/l9.txt")"
else row "L9 quality (cds1 CQL, JSNE)" FAIL "$(head -3 "$WORK/l9.txt" | tr '\n' ' ')"; fi
L9TABLE="$(tail -n +2 "$WORK/l9.txt")"
QT="$WS/HL7-FHIR-quality-testing"; dq=0; dqbad=""
for r in "${L9ROWS[@]}"; do
  IFS='|' read -r m n ipp den numer denex _ <<<"$r"
  [[ "$ipp" =~ ^[0-9]+$ ]] || continue
  python3 "$QT/scripts/build-deqm-summary.py" --cms "$m" --ipp "$ipp" --denom "$den" --numer "$numer" --denex "$denex" \
    --cohort-size "$n" --out-dir "$WORK/deqm" >/dev/null 2>&1 \
    && python3 "$QT/scripts/check-deqm-summary.py" "$WORK/deqm/$m-summary-deqm.json" >"$WORK/deqm-$m.log" 2>&1 \
    && dq=$((dq+1)) || dqbad+="$m "
done
if [[ -z "$dqbad" ]]; then row "L9 DEQM summary" PASS "$dq DEQM Summary MeasureReports built from L9 counts pass check-deqm-summary.py"
else row "L9 DEQM summary" FAIL "failed: $dqbad"; fi
done_level 9

# ---- L10 resilience -------------------------------------------------------------
docker restart "$NAME" >/dev/null 2>&1
UP=0; for _ in $(seq 1 40); do sleep 5; [[ "$(http /fhir/metadata 10)" == 200 ]] && { UP=1; break; }; done
RB=""; [[ -n "${DFN_fixed:-}" ]] && RB="$(curl -sS --max-time 600 "$BASE/fhir?dfn=$DFN_fixed" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read());print(len(d.get("entry",[])))' 2>/dev/null)"
if [[ $UP -eq 1 && -n "$RB" ]]; then row "L10 restart" PASS "back after docker restart; fixed dfn=$DFN_fixed reads back $RB entries (strict JSON)"
else row "L10 restart" FAIL "up=$UP readback='$RB'"; fi
R1="$(grep -o '[0-9]* routes' "$WORK/install-web,code,link,boot,listener.log")"
if "$ROOT/scripts/vehu-install.sh" "$NAME" --encoder JSNE >"$WORK/reinstall.log" 2>&1; then
  R2="$(grep -o '[0-9]* routes' "$WORK/reinstall.log")"
  POPN2="$(curl -sS --max-time 60 "$BASE/c0x/index/stat" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("populationIndexed",d.get("patients","")))' 2>/dev/null)"
  if [[ -n "$R1" && "$R1" == "$R2" && "$POPN2" == "$POPN" ]]; then row "L10 reinstall" PASS "full reinstall OK, $R2 (unchanged), populationIndexed $POPN2 kept"
  else row "L10 reinstall" FAIL "routes '$R1' -> '$R2', populationIndexed $POPN -> $POPN2"; fi
else row "L10 reinstall" FAIL "$(grep FAIL "$WORK/reinstall.log")"; fi
done_level 10
finish
