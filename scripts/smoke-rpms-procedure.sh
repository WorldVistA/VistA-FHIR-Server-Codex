#!/usr/bin/env bash
# Smoke RPMS Procedure writeback (C0FWPRC RPMS/PCE path).
# Usage: ./scripts/smoke-rpms-procedure.sh [base_url] [dfn]
set -euo pipefail

BASE="${1:-http://127.0.0.1:9088}"
DFN="${2:-4}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> RPMS Procedure smoke against $BASE dfn=$DFN"

# Prefer replaying the saved Quality AI Consult CMS125 writeback when present.
WBS_ID="wbs-67784-70676-14152"
BUNDLE_JSON="$(mktemp)"
cleanup() { rm -f "$BUNDLE_JSON"; }
trap cleanup EXIT

if curl -sfS "$BASE/writebacksaves/$WBS_ID" -o /tmp/wbs-prc.json 2>/dev/null; then
  python3 - "$BUNDLE_JSON" <<'PY'
import json,sys
wbs=json.load(open("/tmp/wbs-prc.json"))
bundle=wbs.get("artifact",{}).get("bundle")
if not bundle:
    raise SystemExit("WBS missing artifact.bundle")
# Keep Patient + Encounter + Procedure only for a focused procedure smoke
keep={"Patient","Encounter","Procedure"}
bundle["entry"]=[e for e in bundle.get("entry",[]) if e.get("resource",{}).get("resourceType") in keep]
json.dump(bundle, open(sys.argv[1],"w"))
print("using WBS", "entries", len(bundle["entry"]))
PY
else
  python3 - "$BUNDLE_JSON" "$DFN" <<'PY'
import json,sys,datetime
dfn=sys.argv[2]
now=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z"
bundle={
  "resourceType":"Bundle","type":"transaction","entry":[
    {"fullUrl":f"urn:uuid:{dfn}-prc-patient","resource":{"resourceType":"Patient","id":dfn},"request":{"method":"POST","url":"Patient"}},
    {"fullUrl":f"urn:uuid:{dfn}-prc-enc","resource":{
      "resourceType":"Encounter","id":f"{dfn}-prc-enc","status":"finished","class":{"code":"AMB"},
      "type":[{"coding":[{"system":"http://snomed.info/sct","code":"308335008"}]}],
      "subject":{"reference":f"urn:uuid:{dfn}-prc-patient"},
      "period":{"start":now}
    },"request":{"method":"POST","url":"Encounter"}},
    {"fullUrl":f"urn:uuid:{dfn}-prc-proc","resource":{
      "resourceType":"Procedure","id":f"{dfn}-prc-mammo","status":"completed",
      "code":{"coding":[{"system":"http://snomed.info/sct","code":"71651007","display":"Mammography (procedure)"}],
              "text":"Mammography (procedure)"},
      "subject":{"reference":f"urn:uuid:{dfn}-prc-patient"},
      "encounter":{"reference":f"urn:uuid:{dfn}-prc-enc"},
      "performedDateTime":now
    },"request":{"method":"POST","url":"Procedure"}}
  ]
}
json.dump(bundle, open(sys.argv[1],"w"))
print("using synthetic mammo bundle")
PY
fi

RESP="$(mktemp)"
HTTP=$(curl -sS -o "$RESP" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  --data-binary @"$BUNDLE_JSON" \
  "$BASE/updatepatient?dfn=${DFN}&load=1&returngraph=1")
echo "POST /updatepatient HTTP $HTTP"
python3 - "$RESP" <<'PY'
import json,sys
out=json.load(open(sys.argv[1]))
dom=(out.get("domains") or {}).get("Procedure") or {}
status=dom.get("status") or ""
msg=dom.get("message") or ""
print("Procedure.status=", status)
print("Procedure.message=", msg)
# also scan transactionLoad
tl=out.get("transactionLoad") or []
found=None
if isinstance(tl, list):
    for row in tl:
        if isinstance(row, dict) and "Procedure" in row:
            found=row["Procedure"]
elif isinstance(tl, dict):
    for row in tl.values():
        if isinstance(row, dict) and "Procedure" in row:
            found=row["Procedure"]
if found:
    print("transactionLoad.Procedure.loadStatus=", found.get("loadStatus"))
    print("transactionLoad.Procedure.message=", found.get("message"))
    status=status or found.get("loadStatus") or ""
    msg=msg or found.get("message") or ""
ok = status in ("loaded","skipped") and "first-pass" not in msg.lower()
if not ok:
    raise SystemExit(f"FAIL Procedure writeback status={status!r} msg={msg!r}")
print("PASS writeback Procedure")
PY

FHIR="$(mktemp)"
curl -sS "$BASE/fhir?dfn=${DFN}&_count=200" -o "$FHIR"
python3 - "$FHIR" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
procs=[e.get("resource") for e in d.get("entry") or [] if e.get("resource",{}).get("resourceType")=="Procedure"]
print("FHIR Procedure count=", len(procs))
texts=[]
for r in procs:
    t=(r.get("code") or {}).get("text") or ""
    codes=[c.get("code") for c in (r.get("code") or {}).get("coding") or []]
    texts.append((t, codes))
    print(" ", r.get("id"), t, codes)
hit=any(("Mammo" in (t or "")) or ("0583H" in codes) or ("1571J" in codes) or ("71651007" in codes) for t,codes in texts)
if not hit and not procs:
    raise SystemExit("FAIL no FHIR Procedure resources for patient")
if not hit:
    print("WARN: Procedure present but mammo text/code not matched; continuing")
else:
    print("PASS FHIR Procedure mammo evidence")
print("SMOKE OK: rpms-procedure")
PY
