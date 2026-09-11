#!/usr/bin/env bash
# Assert RPMS /fhir emits recent V MEASUREMENT BPs (newest-first GETRMSR).
# Usage: ./scripts/smoke-rpms-vitals-readback.sh <http_base> <dfn> [systolic] [diastolic]
set -euo pipefail

BASE="${1:?http_base required}"
BASE="${BASE%/}"
DFN="${2:?dfn required}"
SYS="${3:-130}"
DIA="${4:-77}"

echo "==> RPMS vitals readback smoke: $BASE dfn=$DFN expect BP $SYS/$DIA"

code=$(curl -sS -o /tmp/rpms-vitals-fhir.json -w "%{http_code}" --max-time 120 \
  "$BASE/fhir?dfn=$DFN&refresh=1" || echo 000)
if [[ "$code" != "200" ]]; then
  echo "FAIL  /fhir?dfn=$DFN HTTP $code" >&2
  exit 1
fi

python3 - "$SYS" "$DIA" <<'PY'
import json, sys
sys_e, dia_e = sys.argv[1], sys.argv[2]
b = json.load(open("/tmp/rpms-vitals-fhir.json"))
hits = []
for e in b.get("entry") or []:
    r = e.get("resource") or {}
    if r.get("resourceType") != "Observation":
        continue
    comps = {}
    for c in r.get("component") or []:
        code = ((c.get("code") or {}).get("coding") or [{}])[0].get("code")
        val = (c.get("valueQuantity") or {}).get("value")
        if code:
            comps[str(code)] = val
    if str(comps.get("8480-6")) == sys_e and str(comps.get("8462-4")) == dia_e:
        hits.append((r.get("id"), r.get("effectiveDateTime"), comps))
if not hits:
    print(f"FAIL  no Observation with BP {sys_e}/{dia_e} (8480-6/8462-4)", file=sys.stderr)
    sys.exit(1)
print(f"PASS  BP {sys_e}/{dia_e} in /fhir as {hits[0][0]} @ {hits[0][1]}")
PY

echo "SMOKE OK: rpms vitals readback"
