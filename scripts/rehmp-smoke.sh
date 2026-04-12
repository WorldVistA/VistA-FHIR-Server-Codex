#!/usr/bin/env bash
set -euo pipefail

FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9085}"
DFN="${1:-}"
if [[ -z "$DFN" ]]; then
  echo "Usage: $0 DFN" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required for JSON assertions" >&2
  exit 2
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

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

post_json() {
  local name="$1"
  local body="$2"
  local expect_http="$3"
  local expect_status="${4:-}"
  local expect_request_id="${5:-}"
  local outfile="$TMPDIR/${name}.json"
  local code
  code="$(curl -sS -o "$outfile" -w '%{http_code}' -H 'Expect:' -H 'Content-Type: application/json' --data-binary "$body" "$FHIR_HTTP_BASE/rehmp")"
  echo "==> POST /rehmp [$name] -> HTTP $code"
  cat "$outfile"
  echo
  if [[ ",$expect_http," != *",$code,"* ]]; then
    echo "error: expected HTTP $expect_http for $name, got $code" >&2
    exit 1
  fi
  if [[ -n "$expect_status" ]]; then
    assert_json "$outfile" "$expect_status" "$expect_request_id" envelope
  fi
}

REQ_ID_BASE="rehmp-smoke-$(date +%s)"

post_json "health" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-health","operation":"health","payload":{}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-health"

post_json "bundle-basic" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-bundle","operation":"patient.fhir.bundle","payload":{"dfn":"${DFN}"}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-bundle"

post_json "bundle-domain-filter" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-domains","operation":"patient.fhir.bundle","payload":{"dfn":"${DFN}","fhirQuery":{"domain":"lab,meds","max":"25"}}}
EOF
)" "200,201" "ok" "${REQ_ID_BASE}-domains"

post_json "missing-operation" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-missingop","payload":{"dfn":"${DFN}"}}
EOF
)" "400"

post_json "bad-version" "$(cat <<EOF
{"apiVersion":"9.9","requestId":"${REQ_ID_BASE}-badver","operation":"health","payload":{}}
EOF
)" "400"

post_json "missing-dfn" "$(cat <<EOF
{"apiVersion":"1.0","requestId":"${REQ_ID_BASE}-missingdfn","operation":"patient.fhir.bundle","payload":{}}
EOF
)" "400"

echo "==> GET $FHIR_HTTP_BASE/fhir?dfn=$DFN"
fhir_code="$(curl -sS -o "$TMPDIR/fhir.json" -w '%{http_code}' "$FHIR_HTTP_BASE/fhir?dfn=$DFN")"
echo "HTTP $fhir_code"
if [[ "$fhir_code" != "200" ]]; then
  echo "error: expected HTTP 200 for /fhir?dfn=$DFN, got $fhir_code" >&2
  exit 1
fi
assert_json "$TMPDIR/fhir.json" "_" "_" bundle
head -c 400 "$TMPDIR/fhir.json"
echo

echo "rehmp smoke complete"
