#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] DFN

Run rehmp regression smoke tests against /rehmp and /fhir.

Options:
  --base-url URL         Base URL for the FHIR server.
                         Default: http://127.0.0.1:9085
  --artifacts-dir DIR    Keep requests, responses, and a results manifest in DIR.
  --keep-artifacts       Keep artifacts in a temporary directory and print its path.
  -h, --help             Show this help.

Examples:
  ./scripts/rehmp-smoke.sh 101075
  ./scripts/rehmp-smoke.sh --keep-artifacts 101075
  ./scripts/rehmp-smoke.sh --artifacts-dir /tmp/rehmp-demo 101075
EOF
}

FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9085}"
ARTIFACT_DIR=""
ARTIFACT_MODE="ephemeral"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -ge 2 ]] || { echo "error: --base-url requires a value" >&2; exit 2; }
      FHIR_HTTP_BASE="$2"
      shift 2
      ;;
    --artifacts-dir)
      [[ $# -ge 2 ]] || { echo "error: --artifacts-dir requires a value" >&2; exit 2; }
      ARTIFACT_DIR="$2"
      ARTIFACT_MODE="persistent"
      shift 2
      ;;
    --keep-artifacts)
      ARTIFACT_MODE="persistent"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

DFN="${1:-}"
if [[ -z "$DFN" ]]; then
  usage >&2
  exit 2
fi
shift || true
if [[ $# -gt 0 ]]; then
  echo "error: unexpected argument: $1" >&2
  usage >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required for JSON assertions" >&2
  exit 2
fi

if [[ -n "$ARTIFACT_DIR" ]]; then
  mkdir -p "$ARTIFACT_DIR"
elif [[ "$ARTIFACT_MODE" == "persistent" ]]; then
  ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rehmp-smoke.XXXXXX")"
else
  ARTIFACT_DIR="$(mktemp -d)"
fi

ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd)"
RESULTS_FILE="$ARTIFACT_DIR/results.tsv"
SUMMARY_FILE="$ARTIFACT_DIR/summary.txt"

printf "name\tmethod\tpath\thttp\trequest\tresponse\n" > "$RESULTS_FILE"
cat > "$SUMMARY_FILE" <<EOF
run_started=$(date -Iseconds)
base_url=$FHIR_HTTP_BASE
dfn=$DFN
artifacts_dir=$ARTIFACT_DIR
artifact_mode=$ARTIFACT_MODE
EOF

on_exit() {
  local exit_code=$?
  {
    printf "run_finished=%s\n" "$(date -Iseconds)"
    printf "exit_code=%s\n" "$exit_code"
  } >> "$SUMMARY_FILE"
  if [[ "$ARTIFACT_MODE" == "ephemeral" ]]; then
    rm -rf "$ARTIFACT_DIR"
  fi
}
trap on_exit EXIT

assert_json() {
  local file="$1"
  local expect_status="$2"
  local expect_request_id="$3"
  local mode="${4:-envelope}"
  python3 - "$file" "$expect_status" "$expect_request_id" "$mode" <<'PY'
import json
import sys

path, expect_status, expect_request_id, mode = sys.argv[1:5]
with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

if mode == "envelope":
    if payload.get("apiVersion") != "1.0":
        raise SystemExit(f"apiVersion mismatch in {path}: {payload.get('apiVersion')!r}")
    if payload.get("requestId") != expect_request_id:
        raise SystemExit(f"requestId mismatch in {path}: {payload.get('requestId')!r}")
    if payload.get("status") != expect_status:
        raise SystemExit(f"status mismatch in {path}: {payload.get('status')!r}")
elif mode == "bundle":
    if payload.get("resourceType") != "Bundle":
        raise SystemExit(f"resourceType mismatch in {path}: {payload.get('resourceType')!r}")
    if not isinstance(payload.get("entry"), list):
        raise SystemExit(f"entry is not a list in {path}")
else:
    raise SystemExit(f"unknown assertion mode: {mode}")
PY
}

print_preview() {
  local file="$1"
  local limit="${2:-600}"
  local size
  size="$(wc -c < "$file")"
  if (( size == 0 )); then
    echo "(empty body)"
    return
  fi
  if (( size <= limit )); then
    cat "$file"
    echo
    return
  fi
  head -c "$limit" "$file"
  echo
  echo "... [truncated; full response saved to $file]"
}

record_result() {
  local name="$1"
  local method="$2"
  local path="$3"
  local http_code="$4"
  local request_file="$5"
  local response_file="$6"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$name" "$method" "$path" "$http_code" "$request_file" "$response_file" >> "$RESULTS_FILE"
}

TOTAL_STEPS=7
CURRENT_STEP=0

step() {
  local label="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf "\n[%d/%d] %s\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$label"
}

post_json() {
  local name="$1"
  local body="$2"
  local expect_http="$3"
  local expect_status="${4:-}"
  local expect_request_id="${5:-}"
  local request_file="$ARTIFACT_DIR/${name}.request.json"
  local response_file="$ARTIFACT_DIR/${name}.response.json"
  local code

  printf "%s\n" "$body" > "$request_file"
  code="$(curl -sS -o "$response_file" -w '%{http_code}' -H 'Expect:' -H 'Content-Type: application/json' --data-binary "$body" "$FHIR_HTTP_BASE/rehmp")"

  echo "POST /rehmp -> HTTP $code"
  echo "request:  $request_file"
  echo "response: $response_file"
  print_preview "$response_file" 800

  if [[ ",$expect_http," != *",$code,"* ]]; then
    echo "error: expected HTTP $expect_http for $name, got $code" >&2
    exit 1
  fi
  if [[ -n "$expect_status" ]]; then
    assert_json "$response_file" "$expect_status" "$expect_request_id" envelope
  fi

  record_result "$name" "POST" "/rehmp" "$code" "$request_file" "$response_file"
  echo "assertions: pass"
}

get_fhir() {
  local response_file="$ARTIFACT_DIR/fhir.response.json"
  local code

  code="$(curl -sS -o "$response_file" -w '%{http_code}' "$FHIR_HTTP_BASE/fhir?dfn=$DFN")"
  echo "GET /fhir?dfn=$DFN -> HTTP $code"
  echo "response: $response_file"
  if [[ "$code" != "200" ]]; then
    echo "error: expected HTTP 200 for /fhir?dfn=$DFN, got $code" >&2
    exit 1
  fi
  assert_json "$response_file" "_" "_" bundle
  print_preview "$response_file" 400
  record_result "fhir-compatibility" "GET" "/fhir?dfn=$DFN" "$code" "-" "$response_file"
  echo "assertions: pass"
}

REQ_ID_BASE="rehmp-smoke-$(date +%s)"

echo "rehmp smoke demo"
echo "base url:    $FHIR_HTTP_BASE"
echo "dfn:         $DFN"
if [[ "$ARTIFACT_MODE" == "persistent" ]]; then
  echo "artifacts:   $ARTIFACT_DIR"
else
  echo "artifacts:   temporary only"
fi

step "Health check envelope"
post_json "health" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-health","operation":"health","payload":{}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-health"

step "Bundle request for one patient"
post_json "bundle-basic" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-bundle","operation":"patient.fhir.bundle","payload":{"dfn":"${DFN}"}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-bundle"

step "Domain-filtered bundle request"
post_json "bundle-domain-filter" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-domains","operation":"patient.fhir.bundle","payload":{"dfn":"${DFN}","fhirQuery":{"domain":"lab,meds","max":"25"}}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-domains"

step "Validation error for missing operation"
post_json "missing-operation" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-missingop","payload":{"dfn":"${DFN}"}}
EOF
)" "400"

step "Validation error for bad apiVersion"
post_json "bad-version" "$(cat <<EOF
{"apiVersion":"9.9","requestId":"${REQ_ID_BASE}-badver","operation":"health","payload":{}}
EOF
)" "400"

step "Validation error for missing dfn"
post_json "missing-dfn" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-missingdfn","operation":"patient.fhir.bundle","payload":{}}
EOF
)" "400"

step "Compatibility check for GET /fhir"
get_fhir

echo
echo "rehmp smoke complete"
if [[ "$ARTIFACT_MODE" == "persistent" ]]; then
  echo "artifacts kept in: $ARTIFACT_DIR"
  echo "results manifest:  $RESULTS_FILE"
fi
