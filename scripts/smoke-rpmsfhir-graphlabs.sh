#!/usr/bin/env bash
# Smoke EXPERIMENT graph-labs on rpmsfhir.vistaplex.org
# Seeds tobacco + PHQ Observations into fhir-intake for a DFN, then checks /fhir labs.
set -euo pipefail

BASE="${1:-https://rpmsfhir.vistaplex.org}"
DFN="${2:-8}"

echo "==> graph-labs smoke $BASE dfn=$DFN"

# Seed Patient + Encounter + tobacco + PHQ Observations via updatepatient
BUNDLE="$(mktemp)"
cleanup() { rm -f "$BUNDLE"; }
trap cleanup EXIT

python3 - "$BUNDLE" "$DFN" <<'PY'
import json,sys,datetime
dfn=sys.argv[2]
now=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+"Z"
bundle={
  "resourceType":"Bundle","type":"transaction","entry":[
    {"fullUrl":f"urn:uuid:{dfn}-gl-patient","resource":{"resourceType":"Patient","id":dfn},"request":{"method":"POST","url":"Patient"}},
    {"fullUrl":f"urn:uuid:{dfn}-gl-enc","resource":{
      "resourceType":"Encounter","id":f"{dfn}-gl-enc","status":"finished","class":{"code":"AMB"},
      "subject":{"reference":f"urn:uuid:{dfn}-gl-patient"},"period":{"start":now}
    },"request":{"method":"POST","url":"Encounter"}},
    {"fullUrl":f"urn:uuid:{dfn}-gl-tob","resource":{
      "resourceType":"Observation","id":f"{dfn}-gl-tobacco","status":"final",
      "category":[{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/observation-category","code":"social-history"}]}],
      "code":{"coding":[{"system":"http://loinc.org","code":"72166-2","display":"Tobacco smoking status"}],
              "text":"Tobacco smoking status"},
      "subject":{"reference":f"urn:uuid:{dfn}-gl-patient"},
      "encounter":{"reference":f"urn:uuid:{dfn}-gl-enc"},
      "effectiveDateTime":now,
      "valueCodeableConcept":{"coding":[{"system":"http://snomed.info/sct","code":"266919005","display":"Never smoked tobacco"}]}
    },"request":{"method":"POST","url":"Observation"}},
    {"fullUrl":f"urn:uuid:{dfn}-gl-phq","resource":{
      "resourceType":"Observation","id":f"{dfn}-gl-phq","status":"final",
      "category":[{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/observation-category","code":"survey"}]}],
      "code":{"coding":[{"system":"http://loinc.org","code":"44249-1","display":"PHQ-9 quick depression assessment panel"}],
              "text":"PHQ-9 quick depression assessment panel"},
      "subject":{"reference":f"urn:uuid:{dfn}-gl-patient"},
      "encounter":{"reference":f"urn:uuid:{dfn}-gl-enc"},
      "effectiveDateTime":now,
      "valueQuantity":{"value":9,"unit":"score","system":"http://unitsofmeasure.org","code":"{score}"}
    },"request":{"method":"POST","url":"Observation"}}
  ]
}
json.dump(bundle, open(sys.argv[1],"w"))
print("seeded synthetic tobacco+PHQ bundle")
PY

HTTP=$(curl -sS -o /tmp/gl-upd.json -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' --data-binary @"$BUNDLE" \
  "$BASE/updatepatient?dfn=${DFN}&load=1&returngraph=1")
echo "POST /updatepatient HTTP $HTTP"
python3 - <<'PY'
import json
o=json.load(open("/tmp/gl-upd.json"))
print("status=", o.get("status"), "loadStatus=", o.get("loadStatus"))
print("domains=", list((o.get("domains") or {}).keys()))
PY

curl -sS "$BASE/fhir?dfn=${DFN}&domains=labs&refresh=1&_count=200" -o /tmp/gl-labs.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/gl-labs.json"))
obs=[e.get("resource") for e in d.get("entry") or [] if e.get("resource",{}).get("resourceType")=="Observation"]
drs=[e.get("resource") for e in d.get("entry") or [] if e.get("resource",{}).get("resourceType")=="DiagnosticReport"]
print("Observation count=", len(obs))
print("DiagnosticReport count=", len(drs))
codes=set()
for r in obs:
  for c in (r.get("code") or {}).get("coding") or []:
    if c.get("code"): codes.add(c["code"])
need={"72166-2","44249-1"}
missing=need-codes
if missing:
  raise SystemExit(f"FAIL missing LOINCs in labs domain: {sorted(missing)}")
panels=[r for r in drs if ((r.get("category") or [{}])[0].get("coding") or [{}])[0].get("code")=="LAB" and r.get("result")]
print("LAB DiagnosticReports with result[]=", len(panels))
for r in panels[:8]:
  refs=[x.get("reference") for x in (r.get("result") or [])]
  print(" ", r.get("id"), "code=", [c.get("code") for c in (r.get("code") or {}).get("coding") or []], "nResults=", len(refs), "sample=", refs[:3])
if not panels:
  raise SystemExit("FAIL no lab panel DiagnosticReports with result[] from graph")
# result refs should resolve to Observations present in bundle
obs_ids={r.get("id") for r in obs}
dangling=0
urn_left=0
for r in panels:
  for x in r.get("result") or []:
    ref=x.get("reference") or ""
    if ref.startswith("urn:uuid:"):
      urn_left+=1
      continue
    if ref.startswith("Observation/"):
      oid=ref.split("/",1)[1]
      if oid not in obs_ids:
        dangling+=1
gobs=[r.get("id") for r in obs if (r.get("id") or "").startswith("GOBS-")]
gdr=[r.get("id") for r in panels if (r.get("id") or "").startswith("GDR-")]
# fullUrl must be urn:uuid:{id} so browser/panel links match graph identity
fu_bad=0
by_id={r.get("id"):None for r in obs}
for e in d.get("entry") or []:
  r=e.get("resource") or {}
  if r.get("resourceType")!="Observation": continue
  rid=r.get("id") or ""
  fu=e.get("fullUrl") or ""
  if rid and fu!="urn:uuid:"+rid:
    fu_bad+=1
    if fu_bad<=3: print(" fullUrl mismatch", rid, fu)
print("dangling result refs=", dangling, "urn:uuid left=", urn_left, "fullUrl mismatches=", fu_bad)
if urn_left:
  raise SystemExit("FAIL panel result[] still uses urn:uuid refs; expected Observation/{graph-id}")
if dangling:
  raise SystemExit(f"FAIL {dangling} panel result refs do not resolve to bundle Observations")
if fu_bad:
  raise SystemExit("FAIL Observation fullUrl must be urn:uuid:{id}")
if gobs or gdr:
  raise SystemExit(f"FAIL prefixed ids still present gobs={gobs[:3]} gdr={gdr[:3]}")
print("PASS graph-labs tobacco+PHQ + panel DiagnosticReports (ids/fullUrl match)")
PY
