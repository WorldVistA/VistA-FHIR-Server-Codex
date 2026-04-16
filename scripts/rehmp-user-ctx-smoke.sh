#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [DFN]

Run a focused USER.CTX save/read-back smoke test against /rehmp.

This harness intentionally exercises the mutating user context path:
1. GET the current user context and save a normalized backup
2. SET a synthetic rehmpRpcDemo + eHMPUIContext payload
3. GET and verify the saved context round-trips
4. Restore the original context
5. GET again and verify the original context was restored

Because it writes and then restores USER.CTX, prefer an isolated test listener.
Listeners that do not establish a DUZ context will fail the SET steps with
AUTH/401 responses.

Options:
  --base-url URL         Base URL for the rehmp listener.
                         Default: http://127.0.0.1:9085
  --artifacts-dir DIR    Keep requests, responses, and a manifest in DIR.
  --keep-artifacts       Keep artifacts in a temporary directory and print its path.
  -h, --help             Show this help.

Examples:
  ./scripts/rehmp-user-ctx-smoke.sh
  ./scripts/rehmp-user-ctx-smoke.sh 101075
  ./scripts/rehmp-user-ctx-smoke.sh --keep-artifacts --base-url http://127.0.0.1:9085 101075
EOF
}

REHMP_HTTP_BASE="${REHMP_HTTP_BASE:-http://127.0.0.1:9085}"
REHMP_HTTP_BASE="${REHMP_HTTP_BASE%/}"
DFN_DEFAULT="${REHMP_USER_CTX_DFN:-101075}"
ARTIFACT_DIR=""
ARTIFACT_MODE="ephemeral"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -ge 2 ]] || { echo "error: --base-url requires a value" >&2; exit 2; }
      REHMP_HTTP_BASE="$2"
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

DFN="${1:-$DFN_DEFAULT}"
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
  ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rehmp-user-ctx.XXXXXX")"
else
  ARTIFACT_DIR="$(mktemp -d)"
fi

ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd)"
RESULTS_FILE="$ARTIFACT_DIR/results.tsv"
SUMMARY_FILE="$ARTIFACT_DIR/summary.txt"
REQ_ID_BASE="rehmp-user-ctx-$(date +%s)"
SMOKE_MARKER="rehmp-user-ctx-smoke-$(date +%s)-$$"
RESTORE_REQUIRED=0
RESTORE_COMPLETED=0
RESTORE_REQUEST_FILE="$ARTIFACT_DIR/user-ctx-restore.request.json"
LAST_HTTP_CODE=""
LAST_REQUEST_FILE=""
LAST_RESPONSE_FILE=""
TOTAL_STEPS=5
CURRENT_STEP=0

printf "name\tmethod\tpath\thttp\trequest\tresponse\n" > "$RESULTS_FILE"
cat > "$SUMMARY_FILE" <<EOF
run_started=$(date -Iseconds)
base_url=$REHMP_HTTP_BASE
dfn=$DFN
smoke_marker=$SMOKE_MARKER
artifacts_dir=$ARTIFACT_DIR
artifact_mode=$ARTIFACT_MODE
EOF

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
    python3 - "$file" <<'PY'
import pathlib
import sys
sys.stdout.write(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
PY
    echo
    return
  fi
  python3 - "$file" "$limit" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
limit = int(sys.argv[2])
text = path.read_text(encoding="utf-8")
sys.stdout.write(text[:limit])
PY
  echo
  echo "... [truncated; full response saved to $file]"
}

step() {
  local label="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf "\n[%d/%d] %s\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$label"
}

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

expected_statuses = [item for item in expect_status.split(",") if item and item != "_"]

def assert_envelope(obj):
    if obj.get("apiVersion") != "1.0":
        raise SystemExit(f"apiVersion mismatch in {path}: {obj.get('apiVersion')!r}")
    if expect_request_id != "_" and obj.get("requestId") != expect_request_id:
        raise SystemExit(f"requestId mismatch in {path}: {obj.get('requestId')!r}")
    if expected_statuses and obj.get("status") not in expected_statuses:
        raise SystemExit(f"status mismatch in {path}: {obj.get('status')!r}")

if mode == "envelope":
    assert_envelope(payload)
elif mode == "user-ctx-get":
    assert_envelope(payload)
    data = payload.get("data")
    if not isinstance(data, dict):
        raise SystemExit(f"data is not an object in {path}")
    ehmp = data.get("eHMPUIContext", "")
    if ehmp != "" and not isinstance(ehmp, list):
        raise SystemExit(f"eHMPUIContext is neither [] nor '' in {path}: {ehmp!r}")
    prefs = data.get("preferences")
    if prefs is not None and not isinstance(prefs, dict):
        raise SystemExit(f"preferences is not an object in {path}: {prefs!r}")
elif mode == "user-ctx-set":
    assert_envelope(payload)
    data = payload.get("data")
    if not isinstance(data, dict):
        raise SystemExit(f"data is not an object in {path}")
    if data.get("saved") not in (True, 1):
        raise SystemExit(f"saved is not truthy in {path}: {data.get('saved')!r}")
else:
    raise SystemExit(f"unknown assertion mode: {mode}")
PY
}

write_get_request() {
  local out_file="$1"
  local request_id="$2"
  cat > "$out_file" <<EOF
{"apiVersion":"1.0","requestId":"${request_id}","operation":"user.ctx.get","payload":{}}
EOF
}

write_request_from_payload() {
  local out_file="$1"
  local request_id="$2"
  local payload_file="$3"
  python3 - "$request_id" "$payload_file" > "$out_file" <<'PY'
import json
import pathlib
import sys

request_id = sys.argv[1]
payload = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
body = {
    "apiVersion": "1.0",
    "requestId": request_id,
    "operation": "user.ctx.set",
    "payload": payload,
}
json.dump(body, sys.stdout, separators=(",", ":"))
sys.stdout.write("\n")
PY
}

write_smoke_payload() {
  local out_file="$1"
  local dfn="$2"
  local marker="$3"
  local base_url="$4"
  python3 - "$dfn" "$marker" "$base_url" > "$out_file" <<'PY'
import json
import sys
from datetime import datetime, timezone

dfn, marker, base_url = sys.argv[1:4]
saved_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
payload = {
    "eHMPUIContext": [
        {
            "dfn": dfn,
            "displayName": f"USER CTX smoke {marker}",
            "birthDate": "1935-04-07",
            "genderCode": "M",
            "localId": f"SMOKE/{dfn}",
            "icn": f"SMOKE-{dfn}",
            "sensitive": False,
        }
    ],
    "preferences": {
        "rehmpRpcDemo": {
            "version": 1,
            "savedAt": saved_at,
            "smokeMarker": marker,
            "controls": {
                "mode": "live-bundle",
                "samplePath": "examples/response.patient.search.ok.json",
                "rehmpBase": f"{base_url}/rehmp",
                "dfn": dfn,
                "searchType": "full-name",
                "searchString": f"USER CTX smoke {marker}",
                "domains": "lab,meds",
                "max": "25",
                "includeFhirPing": False,
            },
            "selectedPatientDfn": dfn,
            "bundleContext": {
                "dfn": dfn,
                "domain": "lab,meds",
                "max": "25",
            },
            "chartFocus": {
                "type": "resource-type",
                "resourceType": "Observation",
            },
            "bundleSource": "live",
        }
    },
    "merge": False,
}
json.dump(payload, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
}

normalize_get_response() {
  local response_file="$1"
  local out_file="$2"
  python3 - "$response_file" > "$out_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

data = payload.get("data")
if not isinstance(data, dict):
    raise SystemExit(f"data is not an object in {sys.argv[1]}")

normalized = {}
ehmp = data.get("eHMPUIContext")
if isinstance(ehmp, list):
    normalized["eHMPUIContext"] = ehmp
else:
    normalized["eHMPUIContext"] = []
prefs = data.get("preferences")
if isinstance(prefs, dict):
    normalized["preferences"] = prefs
else:
    normalized["preferences"] = {}
json.dump(normalized, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
}

prepare_restore_payload() {
  local response_file="$1"
  local payload_out="$2"
  python3 - "$response_file" > "$payload_out" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

data = payload.get("data")
if not isinstance(data, dict):
    raise SystemExit(f"data is not an object in {sys.argv[1]}")

restore_payload = {"merge": False}
ehmp = data.get("eHMPUIContext")
if isinstance(ehmp, list):
    restore_payload["eHMPUIContext"] = ehmp
prefs = data.get("preferences")
if isinstance(prefs, dict):
    restore_payload["preferences"] = prefs

json.dump(restore_payload, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
}

assert_roundtrip_matches() {
  local response_file="$1"
  local payload_file="$2"
  python3 - "$response_file" "$payload_file" <<'PY'
import json
import sys

response_path, payload_path = sys.argv[1:3]
with open(response_path, "r", encoding="utf-8") as fh:
    response = json.load(fh)
with open(payload_path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

data = response.get("data")
if not isinstance(data, dict):
    raise SystemExit(f"data is not an object in {response_path}")

expected = {
    "eHMPUIContext": payload.get("eHMPUIContext", []),
    "preferences": payload.get("preferences", {}),
}
actual = {
    "eHMPUIContext": data.get("eHMPUIContext") if isinstance(data.get("eHMPUIContext"), list) else [],
    "preferences": data.get("preferences") if isinstance(data.get("preferences"), dict) else {},
}
if actual != expected:
    raise SystemExit(
        "round-trip mismatch:\nexpected="
        + json.dumps(expected, indent=2, sort_keys=True)
        + "\nactual="
        + json.dumps(actual, indent=2, sort_keys=True)
    )
PY
}

assert_normalized_context_match() {
  local response_file="$1"
  local normalized_expected_file="$2"
  python3 - "$response_file" "$normalized_expected_file" <<'PY'
import json
import sys

response_path, expected_path = sys.argv[1:3]
with open(response_path, "r", encoding="utf-8") as fh:
    response = json.load(fh)
with open(expected_path, "r", encoding="utf-8") as fh:
    expected = json.load(fh)

data = response.get("data")
if not isinstance(data, dict):
    raise SystemExit(f"data is not an object in {response_path}")

actual = {
    "eHMPUIContext": data.get("eHMPUIContext") if isinstance(data.get("eHMPUIContext"), list) else [],
    "preferences": data.get("preferences") if isinstance(data.get("preferences"), dict) else {},
}
if actual != expected:
    raise SystemExit(
        "restored context mismatch:\nexpected="
        + json.dumps(expected, indent=2, sort_keys=True)
        + "\nactual="
        + json.dumps(actual, indent=2, sort_keys=True)
    )
PY
}

post_request_file() {
  local name="$1"
  local request_file="$2"
  local expect_http="$3"
  local response_file="$ARTIFACT_DIR/${name}.response.json"
  local code

  code="$(curl -sS -o "$response_file" -w '%{http_code}' -H 'Expect:' -H 'Content-Type: application/json' --data-binary @"$request_file" "$REHMP_HTTP_BASE/rehmp")"

  echo "POST /rehmp -> HTTP $code"
  echo "request:  $request_file"
  echo "response: $response_file"
  print_preview "$response_file" 800

  if [[ ",$expect_http," != *",$code,"* ]]; then
    echo "error: expected HTTP $expect_http for $name, got $code" >&2
    exit 1
  fi

  record_result "$name" "POST" "/rehmp" "$code" "$request_file" "$response_file"
  LAST_HTTP_CODE="$code"
  LAST_REQUEST_FILE="$request_file"
  LAST_RESPONSE_FILE="$response_file"
}

attempt_restore_on_exit() {
  if [[ "$RESTORE_REQUIRED" != "1" || "$RESTORE_COMPLETED" == "1" || ! -f "$RESTORE_REQUEST_FILE" ]]; then
    return
  fi
  local response_file="$ARTIFACT_DIR/user-ctx-restore-on-exit.response.json"
  local code
  set +e
  code="$(curl -sS -o "$response_file" -w '%{http_code}' -H 'Expect:' -H 'Content-Type: application/json' --data-binary @"$RESTORE_REQUEST_FILE" "$REHMP_HTTP_BASE/rehmp")"
  set -e
  echo "automatic restore attempt -> HTTP ${code:-unknown}" >&2
  if [[ -f "$response_file" ]]; then
    print_preview "$response_file" 400 >&2 || true
    record_result "user-ctx-restore-on-exit" "POST" "/rehmp" "${code:-?}" "$RESTORE_REQUEST_FILE" "$response_file"
  fi
}

on_exit() {
  local exit_code=$?
  attempt_restore_on_exit
  {
    printf "run_finished=%s\n" "$(date -Iseconds)"
    printf "exit_code=%s\n" "$exit_code"
    printf "restore_required=%s\n" "$RESTORE_REQUIRED"
    printf "restore_completed=%s\n" "$RESTORE_COMPLETED"
  } >> "$SUMMARY_FILE"
  if [[ "$ARTIFACT_MODE" == "ephemeral" ]]; then
    rm -rf "$ARTIFACT_DIR"
  fi
}
trap on_exit EXIT

echo "rehmp USER.CTX smoke"
echo "base url:    $REHMP_HTTP_BASE"
echo "dfn:         $DFN"
echo "marker:      $SMOKE_MARKER"
if [[ "$ARTIFACT_MODE" == "persistent" ]]; then
  echo "artifacts:   $ARTIFACT_DIR"
else
  echo "artifacts:   temporary only"
fi

BACKUP_REQUEST_FILE="$ARTIFACT_DIR/user-ctx-get-before.request.json"
BACKUP_NORMALIZED_FILE="$ARTIFACT_DIR/user-ctx-before.normalized.json"
RESTORE_PAYLOAD_FILE="$ARTIFACT_DIR/user-ctx-restore.payload.json"
SMOKE_PAYLOAD_FILE="$ARTIFACT_DIR/user-ctx-smoke.payload.json"
SET_REQUEST_FILE="$ARTIFACT_DIR/user-ctx-set-smoke.request.json"
VERIFY_REQUEST_FILE="$ARTIFACT_DIR/user-ctx-get-verify.request.json"
FINAL_REQUEST_FILE="$ARTIFACT_DIR/user-ctx-get-after-restore.request.json"

step "Backup current user context"
write_get_request "$BACKUP_REQUEST_FILE" "${REQ_ID_BASE}-get-before"
post_request_file "user-ctx-get-before" "$BACKUP_REQUEST_FILE" "200,201"
assert_json "$LAST_RESPONSE_FILE" "ok" "${REQ_ID_BASE}-get-before" "user-ctx-get"
normalize_get_response "$LAST_RESPONSE_FILE" "$BACKUP_NORMALIZED_FILE"
prepare_restore_payload "$LAST_RESPONSE_FILE" "$RESTORE_PAYLOAD_FILE"
write_request_from_payload "$RESTORE_REQUEST_FILE" "${REQ_ID_BASE}-set-restore" "$RESTORE_PAYLOAD_FILE"
echo "assertions: pass"

step "Write synthetic rehmpRpcDemo context"
write_smoke_payload "$SMOKE_PAYLOAD_FILE" "$DFN" "$SMOKE_MARKER" "$REHMP_HTTP_BASE"
write_request_from_payload "$SET_REQUEST_FILE" "${REQ_ID_BASE}-set-smoke" "$SMOKE_PAYLOAD_FILE"
post_request_file "user-ctx-set-smoke" "$SET_REQUEST_FILE" "200,201"
assert_json "$LAST_RESPONSE_FILE" "ok" "${REQ_ID_BASE}-set-smoke" "user-ctx-set"
RESTORE_REQUIRED=1
echo "assertions: pass"

step "Read back and verify the saved context"
write_get_request "$VERIFY_REQUEST_FILE" "${REQ_ID_BASE}-get-verify"
post_request_file "user-ctx-get-verify" "$VERIFY_REQUEST_FILE" "200,201"
assert_json "$LAST_RESPONSE_FILE" "ok" "${REQ_ID_BASE}-get-verify" "user-ctx-get"
assert_roundtrip_matches "$LAST_RESPONSE_FILE" "$SMOKE_PAYLOAD_FILE"
echo "assertions: pass"

step "Restore the original user context"
post_request_file "user-ctx-set-restore" "$RESTORE_REQUEST_FILE" "200,201"
assert_json "$LAST_RESPONSE_FILE" "ok" "${REQ_ID_BASE}-set-restore" "user-ctx-set"
echo "assertions: pass"

step "Verify the original context was restored"
write_get_request "$FINAL_REQUEST_FILE" "${REQ_ID_BASE}-get-final"
post_request_file "user-ctx-get-after-restore" "$FINAL_REQUEST_FILE" "200,201"
assert_json "$LAST_RESPONSE_FILE" "ok" "${REQ_ID_BASE}-get-final" "user-ctx-get"
assert_normalized_context_match "$LAST_RESPONSE_FILE" "$BACKUP_NORMALIZED_FILE"
RESTORE_COMPLETED=1
echo "assertions: pass"

echo
echo "rehmp USER.CTX smoke complete"
if [[ "$ARTIFACT_MODE" == "persistent" ]]; then
  echo "artifacts kept in: $ARTIFACT_DIR"
  echo "results manifest:  $RESULTS_FILE"
fi
