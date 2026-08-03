#!/usr/bin/env bash
# Smoke RPMS ServiceRequest / radiology order writeback (C0FWSR / ORDER^RAMAG02).
# Usage: ./scripts/smoke-rpms-servicerequest.sh [base_url] [dfn] [container]
set -euo pipefail

BASE="${1:-http://127.0.0.1:9088}"
DFN="${2:-4}"
CONTAINER="${3:-rpms-rebuild-candidate}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> RPMS ServiceRequest smoke against $BASE dfn=$DFN container=$CONTAINER"

# Bootstrap sparse RA site params (mammo #71 type, #79.1, clinic) when needed.
if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker cp "$ROOT/src/C0FRABOOT.m" "$CONTAINER:/home/rpms/r/C0FRABOOT.m"
  docker cp "$ROOT/src/C0FWSR.m" "$CONTAINER:/home/rpms/r/C0FWSR.m"
  docker cp "$ROOT/src/C0FWPOL.m" "$CONTAINER:/home/rpms/r/C0FWPOL.m"
  docker exec -u rpms -i "$CONTAINER" bash -lc 'cd /home/rpms/r && /home/rpms/lib/gtm/mumps -dir' <<'M'
ZL "C0FRABOOT"
ZL "C0FWSR"
ZL "C0FWPOL"
W "BOOT=",$$EN^C0FRABOOT,!
D stop^%webreq H 1 D go^%webreq
W "ok",!
H
M
else
  echo "WARN: container $CONTAINER not running; skipping in-container bootstrap/ZLINK"
fi

BUNDLE_JSON="$(mktemp)"
cleanup() { rm -f "$BUNDLE_JSON"; }
trap cleanup EXIT

python3 - "$BUNDLE_JSON" "$DFN" <<'PY'
import json,sys,datetime
dfn=sys.argv[2]
now=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z"
bundle={
  "resourceType":"Bundle","type":"transaction","entry":[
    {"fullUrl":f"urn:uuid:{dfn}-sr-patient","resource":{"resourceType":"Patient","id":dfn},"request":{"method":"POST","url":"Patient"}},
    {"fullUrl":f"urn:uuid:{dfn}-sr-enc","resource":{
      "resourceType":"Encounter","id":f"{dfn}-sr-enc","status":"finished","class":{"code":"AMB"},
      "type":[{"coding":[{"system":"http://snomed.info/sct","code":"308335008"}]}],
      "subject":{"reference":f"urn:uuid:{dfn}-sr-patient"},
      "period":{"start":now}
    },"request":{"method":"POST","url":"Encounter"}},
    {"fullUrl":f"urn:uuid:{dfn}-sr-req","resource":{
      "resourceType":"ServiceRequest","id":f"{dfn}-sr-mammo","status":"active","intent":"order",
      "category":[{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/service-category","code":"imaging"}]}],
      "code":{"coding":[{"system":"http://snomed.info/sct","code":"71651007","display":"Mammography (procedure)"}],
              "text":"Mammography (procedure)"},
      "subject":{"reference":f"urn:uuid:{dfn}-sr-patient"},
      "encounter":{"reference":f"urn:uuid:{dfn}-sr-enc"},
      "authoredOn":now,
      "note":[{"text":"smoke-rpms-servicerequest mammo order"}]
    },"request":{"method":"POST","url":"ServiceRequest"}}
  ]
}
json.dump(bundle, open(sys.argv[1],"w"))
print("using synthetic mammo ServiceRequest bundle")
PY

RESP="$(mktemp)"
HTTP=$(curl -sS -o "$RESP" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  --data-binary @"$BUNDLE_JSON" \
  "$BASE/updatepatient?dfn=${DFN}&load=1&returngraph=1")
echo "POST /updatepatient HTTP $HTTP"
python3 - "$RESP" <<'PY'
import json,sys
out=json.load(open(sys.argv[1]))
dom=(out.get("domains") or {}).get("ServiceRequest") or {}
status=dom.get("status") or ""
msg=dom.get("message") or ""
print("ServiceRequest.status=", status)
print("ServiceRequest.message=", msg)
print("ServiceRequest.raoIfn=", dom.get("raoIfn"))
tl=out.get("transactionLoad") or []
found=None
if isinstance(tl, list):
    for row in tl:
        if isinstance(row, dict) and "ServiceRequest" in row:
            found=row["ServiceRequest"]
elif isinstance(tl, dict):
    for row in tl.values():
        if isinstance(row, dict) and "ServiceRequest" in row:
            found=row["ServiceRequest"]
if found:
    print("transactionLoad.ServiceRequest.loadStatus=", found.get("loadStatus"))
    print("transactionLoad.ServiceRequest.message=", found.get("message"))
    status=status or found.get("loadStatus") or ""
    msg=msg or found.get("message") or ""
ok = status in ("loaded","skipped") and "first-pass" not in msg.lower() and "deferred" not in msg.lower()
if not ok:
    raise SystemExit(f"FAIL ServiceRequest writeback status={status!r} msg={msg!r}")
print("PASS writeback ServiceRequest")
PY

FHIR="$(mktemp)"
curl -sS "$BASE/fhir?dfn=${DFN}&refresh=1&_count=200" -o "$FHIR"
python3 - "$FHIR" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
srs=[e.get("resource") for e in d.get("entry") or [] if e.get("resource",{}).get("resourceType")=="ServiceRequest"]
print("FHIR ServiceRequest count=", len(srs))
hit=False
for r in srs:
    t=(r.get("code") or {}).get("text") or ""
    codes=[c.get("code") for c in (r.get("code") or {}).get("coding") or []]
    print(" ", r.get("id"), t, codes)
    if ("MAMM" in (t or "").upper()) or ("71651007" in codes) or ("76091" in codes) or ("77056" in codes):
        hit=True
if not srs:
    raise SystemExit("FAIL no FHIR ServiceRequest resources for patient")
if not hit:
    raise SystemExit("FAIL ServiceRequest present but mammo text/code not matched")
print("PASS FHIR ServiceRequest mammo order")
print("SMOKE OK: rpms-servicerequest")
PY
