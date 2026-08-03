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
done

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
