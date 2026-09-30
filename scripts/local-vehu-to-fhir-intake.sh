#!/usr/bin/env bash
# Pull a patient Bundle from VEHU (?dfn= is ONLY the source chart id) and POST it to the
# local fhir container. Print graph ien + local VistA dfn/icn from addpatient — never assume
# VEHU DFN equals DFN on fhir.
#
# Follow-up merges: updatepatient?ien=GRAPH_IEN&load=1
#                   updatepatient?icn=FULL_ICN&load=1
#                   updatepatient?dfn=LOCAL_DFN&load=1   (local ^DPT DFN from this output)
#
# Env: VEHU_FHIR   (default http://127.0.0.1:9085/fhir)
#      FHIR_BASE   (default http://127.0.0.1:9081)
set -euo pipefail

VEHU_FHIR="${VEHU_FHIR:-http://127.0.0.1:9085/fhir}"
FHIR_BASE="${FHIR_BASE:-http://127.0.0.1:9081}"

usage() {
  echo "Usage: $0 VEHU_SOURCE_DFN"
  echo "  Fetches \$VEHU_FHIR?dfn=SOURCE_DFN (VEHU chart id), POSTs to \$FHIR_BASE/addpatient, prints local ien/dfn/icn."
  echo "  Do not use the VEHU source DFN as updatepatient?dfn= on fhir unless it matches the printed local DFN."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ -z "${1:-}" ]]; then usage >&2; exit 2; fi
SRC_DFN="$1"

TMP="$(mktemp)"
RESP="$(mktemp)"
trap 'rm -f "$TMP" "$RESP"' EXIT

echo "GET $VEHU_FHIR?dfn=$SRC_DFN"
curl -sS -o "$TMP" "$VEHU_FHIR?dfn=$SRC_DFN"
if [[ ! -s "$TMP" ]]; then
  echo "error: empty bundle" >&2
  exit 1
fi

echo "POST $FHIR_BASE/addpatient (Expect disabled)"
HTTP_CODE="$(curl -sS -o "$RESP" -w '%{http_code}' -H 'Expect:' -H 'Content-Type: application/json' \
  --data-binary @"$TMP" \
  "$FHIR_BASE/addpatient")"
echo "HTTP $HTTP_CODE"
if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
  echo "error: addpatient failed" >&2
  cat "$RESP" >&2 || true
  exit 1
fi

python3 <<PY
import json, urllib.parse
with open("$RESP") as f:
    d = json.load(f)
ien, dfn, icn = d.get("ien"), d.get("dfn"), d.get("icn")
print("addpatient status:", d.get("status"), "loadStatus:", d.get("loadStatus"))
print("graph ien (preferred for updatepatient):", ien)
print("local VistA dfn (fhir container):", dfn)
print("icn:", icn)
PY

IEN="$(python3 -c "import json;print(json.load(open('$RESP')).get('ien') or '')")"
DFN="$(python3 -c "import json;print(json.load(open('$RESP')).get('dfn') or '')")"
ICN="$(python3 -c "import json;print(json.load(open('$RESP')).get('icn') or '')")"

echo ""
echo "Follow-up merge (reuse a bundle file path as BUNDLE.json):"
if [[ -n "$IEN" ]]; then
  echo "  curl -sS -H 'Expect:' -H 'Content-Type: application/json' --data-binary @BUNDLE.json \\"
  echo "    '${FHIR_BASE}/updatepatient?ien=${IEN}&load=1'"
fi
if [[ -n "$ICN" ]]; then
  enc_icn="$(python3 -c "import json,urllib.parse; icn=json.load(open('$RESP')).get('icn') or ''; print(urllib.parse.quote(icn, safe=''))")"
  echo "  curl -sS -H 'Expect:' -H 'Content-Type: application/json' --data-binary @BUNDLE.json \\"
  echo "    '${FHIR_BASE}/updatepatient?icn=${enc_icn}&load=1'"
fi
if [[ -n "$DFN" ]]; then
  echo "  curl -sS -H 'Expect:' -H 'Content-Type: application/json' --data-binary @BUNDLE.json \\"
  echo "    '${FHIR_BASE}/updatepatient?dfn=${DFN}&load=1'   # local DFN only, not VEHU source id"
fi
