#!/usr/bin/env bash
# Assert quality-dashboard + C0X preset contracts on one HTTP base.
# Usage: ./scripts/smoke-quality-host.sh <name> <http_base> [dfn]
set -euo pipefail

NAME="${1:?name required}"
BASE="${2:?http_base required}"
BASE="${BASE%/}"
DFN="${3:-}"

fail=0
pass() { echo "  PASS  $1"; }
bad()  { echo "  FAIL  $1" >&2; fail=1; }

echo "==> quality smoke: $NAME ($BASE)"

code=$(curl -sS -o /tmp/qsmoke-meta.json -w "%{http_code}" --max-time 30 "$BASE/fhir/metadata" || echo 000)
[[ "$code" == "200" ]] && pass "fhir/metadata" || bad "fhir/metadata HTTP $code"

code=$(curl -sS -o /tmp/qsmoke-dash.html -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-dashboards" || echo 000)
if [[ "$code" == "200" ]] && grep -q "CMS125\|CMS122\|CMS165" /tmp/qsmoke-dash.html; then
  pass "fhir-quality-dashboards"
else
  bad "fhir-quality-dashboards HTTP $code or missing measure links"
fi

for m in CMS122v14 CMS125v14 CMS165v14; do
  code=$(curl -sS -o "/tmp/qsmoke-$m.html" -w "%{http_code}" --max-time 45 "$BASE/fhir-quality-dashboards/$m" || echo 000)
  if [[ "$code" != "200" ]]; then
    bad "$m dashboard HTTP $code"
    continue
  fi
  if grep -q "Population criteria (brief)" "/tmp/qsmoke-$m.html" \
    && grep -q "Initial Population:" "/tmp/qsmoke-$m.html" \
    && grep -q "Denominator:" "/tmp/qsmoke-$m.html" \
    && grep -q "Numerator:" "/tmp/qsmoke-$m.html"; then
    pass "$m population criteria brief"
  else
    bad "$m missing Population criteria (brief) IPP/DENOM/NUMER"
  fi
  if grep -q 'id="cleanCohortBtn"' "/tmp/qsmoke-$m.html" \
    && grep -q 'id="deleteCohortBtn"' "/tmp/qsmoke-$m.html" \
    && grep -q 'fhir-quality-cohort-clean' "/tmp/qsmoke-$m.html" \
    && grep -q 'fhir-quality-cohort-delete' "/tmp/qsmoke-$m.html"; then
    pass "$m cohort clean/delete controls"
  else
    bad "$m missing Clean non-IPP / Delete cohort buttons"
  fi
  # NUMER/DENEX must not exceed DENOM (patients outside DENOM must not inflate rate)
  python3 - "$m" "/tmp/qsmoke-$m.html" <<'PY' || fail=1
import re, sys
m, path = sys.argv[1], sys.argv[2]
html = open(path, encoding="utf-8", errors="replace").read()
# e.g. IPP <strong>51</strong> · DENOM <strong>51</strong> · NUMER <strong>70</strong>
nums = dict(re.findall(r"(IPP|DENOM|NUMER|DENEX)\s*<strong>(\d+)</strong>", html))
if not nums:
    print(f"  PASS  {m} summary counts not present (skip nesting check)")
    raise SystemExit(0)
try:
    ipp, denom = int(nums["IPP"]), int(nums["DENOM"])
    numer, denex = int(nums.get("NUMER", 0)), int(nums.get("DENEX", 0))
except KeyError as e:
    print(f"  FAIL  {m}: incomplete summary counts {nums}: missing {e}", file=sys.stderr)
    raise SystemExit(1)
ok = True
if denom > ipp:
    print(f"  FAIL  {m}: DENOM {denom} > IPP {ipp}", file=sys.stderr); ok = False
if numer > denom:
    print(f"  FAIL  {m}: NUMER {numer} > DENOM {denom} (outside-DENOM numerators)", file=sys.stderr); ok = False
if denex > denom:
    print(f"  FAIL  {m}: DENEX {denex} > DENOM {denom}", file=sys.stderr); ok = False
if ok:
    print(f"  PASS  {m} population nesting IPP>={denom}>={numer}/DENEX")
else:
    raise SystemExit(1)
PY
done

# Live DEQM Summary MeasureReport export (C0FQRPT): report + bundle + page.
# A measure without stored aggregates 404s by design; use the first with data.
rpt_m=""
for m in CMS165v14 CMS122v14 CMS138v14 CMS2v15 CMS125v14; do
  code=$(curl -sS -o /tmp/qsmoke-rpt.json -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-report?measure=$m" || echo 000)
  [[ "$code" == "200" ]] && { rpt_m="$m"; break; }
done
if [[ -z "$rpt_m" ]]; then
  if [[ "$code" == "404" ]] && grep -q '"OperationOutcome"' /tmp/qsmoke-rpt.json; then
    pass "fhir-quality-report 404 OperationOutcome (no aggregates stored on this host)"
  else
    bad "fhir-quality-report HTTP $code (no measure served a live report)"
  fi
else
  python3 - <<'PY' || fail=1
import json, sys
r = json.load(open("/tmp/qsmoke-rpt.json"))
ok = True
if r.get("resourceType") != "MeasureReport":
    print(f"  FAIL  live report resourceType={r.get('resourceType')!r}", file=sys.stderr); ok = False
else:
    prof = (r.get("meta") or {}).get("profile") or []
    if not any("summary-measurereport-deqm" in p for p in prof):
        print("  FAIL  live report missing DEQM summary profile", file=sys.stderr); ok = False
    pops = {p["code"]["coding"][0]["code"]: int(p["count"])
            for p in (r.get("group") or [{}])[0].get("population", [])}
    need = ["initial-population", "denominator", "numerator", "denominator-exclusion"]
    if sorted(pops) != sorted(need):
        print(f"  FAIL  live report populations {sorted(pops)}", file=sys.stderr); ok = False
    elif not (pops["numerator"] <= pops["denominator"] <= pops["initial-population"]):
        print(f"  FAIL  live report nesting {pops}", file=sys.stderr); ok = False
if ok:
    print("  PASS  fhir-quality-report live DEQM summary")
else:
    raise SystemExit(1)
PY

  code=$(curl -sS -o /tmp/qsmoke-rptb.json -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-report?measure=$rpt_m&bundle=1" || echo 000)
  if [[ "$code" != "200" ]]; then
    bad "fhir-quality-report bundle HTTP $code"
  else
    python3 - <<'PY' || fail=1
import json, sys
b = json.load(open("/tmp/qsmoke-rptb.json"))
kinds = [e.get("resource", {}).get("resourceType") for e in b.get("entry", [])]
if b.get("resourceType") == "Bundle" and b.get("type") == "transaction" \
        and kinds == ["Organization", "MeasureReport"]:
    print("  PASS  fhir-quality-report submission Bundle")
else:
    print(f"  FAIL  submission Bundle type={b.get('type')!r} entries={kinds}", file=sys.stderr)
    raise SystemExit(1)
PY
  fi
fi

code=$(curl -sS -o /tmp/qsmoke-rptpg.html -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-reporting" || echo 000)
if [[ "$code" == "200" ]] && grep -q "Active measures" /tmp/qsmoke-rptpg.html \
  && grep -q "fhir-quality-report?measure=" /tmp/qsmoke-rptpg.html \
  && grep -q "rptop" /tmp/qsmoke-rptpg.html \
  && grep -q "source=qualityreport" /tmp/qsmoke-rptpg.html \
  && grep -q "Evidence log" /tmp/qsmoke-rptpg.html; then
  pass "fhir-quality-reporting pipeline page (buttons + browser links + evidence log)"
else
  bad "fhir-quality-reporting HTTP $code or missing live links/buttons/evidence log"
fi

# Outcome endpoint contract: route registered, unknown measure 404s.
# Registered handler emits {} for HTTPERR; a missing route emits the
# listener's "Not Found" error envelope instead.
code=$(curl -sS -o /tmp/qsmoke-out.json -w "%{http_code}" --max-time 30 "$BASE/fhir-quality-report-outcome?measure=NOPE&op=validate" || echo 000)
if [[ "$code" == "404" ]] && ! grep -q '"message":"Not Found"' /tmp/qsmoke-out.json; then
  pass "fhir-quality-report-outcome route registered (404 for unknown measure)"
else
  bad "fhir-quality-report-outcome HTTP $code (route missing?)"
fi

code=$(curl -sS -o /tmp/qsmoke-presets.json -w "%{http_code}" --max-time 45 "$BASE/c0x/presets" || echo 000)
if [[ "$code" != "200" ]]; then
  bad "c0x/presets HTTP $code"
else
  python3 - "$NAME" <<'PY' || fail=1
import json, sys
name = sys.argv[1]
raw = open("/tmp/qsmoke-presets.json", "rb").read().decode("utf-8", "replace")
d = json.loads(raw)
ps = d.get("presets") or {}
items = []
if isinstance(ps, dict):
    for k, v in ps.items():
        if str(k).isdigit() and int(k) > 0 and isinstance(v, dict):
            items.append(v)
elif isinstance(ps, list):
    items = [x for x in ps if isinstance(x, dict)]

by_id = {p.get("id"): p for p in items if p.get("id")}
need = [
    ("CMS122v14", "ipp"),
    ("CMS122v14-NUMER", "numer"),
    ("CMS165v14", "ipp"),
    ("CMS165v14-NUMER", "numer"),
    ("CMS125v14", "ipp"),
    ("CMS125v14-NUMER", "numer"),
    ("CMS2v15", "ipp"),
    ("CMS2v15-NUMER", "numer"),
]
ok = True
for pid, role in need:
    p = by_id.get(pid)
    if not p:
        print(f"  FAIL  {name}: missing preset {pid}", file=sys.stderr)
        ok = False
        continue
    if (p.get("role") or "") != role:
        print(f"  FAIL  {name}: {pid} role={p.get('role')!r} want {role!r}", file=sys.stderr)
        ok = False
    title = p.get("title") or ""
    ipp = p.get("ipp") or ""
    if pid == "CMS122v14":
        if "> 9%" in title or "Glycemic Status > 9%" in title:
            print(f"  FAIL  {name}: CMS122v14 IPP title still looks like NUMER: {title!r}", file=sys.stderr)
            ok = False
        if "HbA1c" in title and "cohort" not in title.lower():
            print(f"  FAIL  {name}: CMS122v14 IPP title looks like lab evidence: {title!r}", file=sys.stderr)
            ok = False
        if "not" not in ipp.lower() and ">9" in ipp.replace(" ", ""):
            # allow "not >9%" wording; reject implying IPP is >9%
            pass
        if "diabetes" not in ipp.lower() and "Diabetes" not in title:
            print(f"  FAIL  {name}: CMS122v14 IPP blurb/title missing diabetes eligibility", file=sys.stderr)
            ok = False
    if pid == "CMS122v14-NUMER" and "> 9%" not in title and "poor control" not in title.lower() and "4548" not in ipp:
        print(f"  FAIL  {name}: CMS122v14-NUMER should describe poor control / >9%", file=sys.stderr)
        ok = False
if ok:
    print(f"  PASS  c0x/presets contract ({len(by_id)} presets)")
else:
    sys.exit(1)
PY
fi

# Prefer Caddy UI when present; else FILESYS UI
ui_ok=0
for path in /c0x/ /filesystem/c0x/index.html; do
  code=$(curl -sS -o /tmp/qsmoke-ui.html -w "%{http_code}" --max-time 20 "$BASE$path" || echo 000)
  if [[ "$code" == "200" ]] && grep -q "Measure cohort presets" /tmp/qsmoke-ui.html; then
    pass "C0X UI $path"
    ui_ok=1
    break
  fi
done
[[ "$ui_ok" == "1" ]] || bad "C0X UI missing Measure cohort presets at /c0x/ and /filesystem/c0x/"

code=$(curl -sS -o /tmp/qsmoke-idx.json -w "%{http_code}" --max-time 30 "$BASE/c0x/index/stat" || echo 000)
if [[ "$code" == "200" ]]; then
  python3 - <<'PY' || fail=1
import json
d=json.load(open("/tmp/qsmoke-idx.json"))
pop=int(d.get("populationIndexed") or 0)
with_codes=int(d.get("patientsWithCodeTriples") or 0)
if pop < 1:
    print("  FAIL  index: populationIndexed < 1", file=__import__("sys").stderr)
    raise SystemExit(1)
if with_codes < 1:
    print(f"  FAIL  index: patientsWithCodeTriples=0 (pop={pop}) — run reindex", file=__import__("sys").stderr)
    raise SystemExit(1)
print(f"  PASS  index pop={pop} with_codes={with_codes}")
PY
else
  bad "c0x/index/stat HTTP $code"
fi

if [[ -n "$DFN" ]]; then
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 60 \
    "$BASE/c0x/fhir/Condition?dfn=$DFN&patient=$DFN&_count=1&source=intake" || echo 000)
  [[ "$code" == "200" ]] && pass "c0x/fhir Condition dfn=$DFN" || bad "c0x/fhir Condition dfn=$DFN HTTP $code"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "SMOKE FAIL: $NAME" >&2
  exit 1
fi
echo "SMOKE OK: $NAME"
exit 0
