#!/usr/bin/env bash
# check-artifacts.sh — artifact hygiene (sprint Day 2, PATH_FORWARD Phase 2).
#
# Guards the mirrored/vendored artifacts that have silently drifted or been
# clobbered before:
#   1. vendor/tjson/web/** and vendored C0TS*.m — sha256 manifest drift check
#   2. HL7-FHIR-quality-testing measure value_sets*.json — must parse, be
#      non-empty, and carry concepts (refuses the "empty VSAC overwrite"
#      failure mode)
#
# Usage:
#   scripts/check-artifacts.sh           # verify (exit 1 on any failure)
#   scripts/check-artifacts.sh --update  # re-record the sha256 manifest
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QT="${QT_ROOT:-$ROOT/../HL7-FHIR-quality-testing}"
MANIFEST="$ROOT/scripts/artifacts.sha256"
FAILED=0

manifest_paths() {
  ( cd "$ROOT" && find vendor/tjson -type f | sort
    ls src/C0TSWS.m src/C0TSWSU.m 2>/dev/null )
}

if [[ "${1:-}" == "--update" ]]; then
  ( cd "$ROOT" && manifest_paths | xargs sha256sum ) > "$MANIFEST"
  echo "manifest recorded: $MANIFEST ($(wc -l < "$MANIFEST") files)"
  exit 0
fi

echo "== artifact check =="

# 1. manifest drift
if [[ ! -f "$MANIFEST" ]]; then
  echo "  FAIL manifest missing — run: scripts/check-artifacts.sh --update"
  FAILED=1
else
  if ( cd "$ROOT" && sha256sum --quiet -c "$MANIFEST" ) >/tmp/artifact-drift.log 2>&1; then
    echo "  PASS vendored artifacts match manifest ($(wc -l < "$MANIFEST") files)"
  else
    echo "  FAIL vendored artifact drift:"
    sed 's/^/       /' /tmp/artifact-drift.log | head -10
    echo "       (intentional update? re-run with --update and commit both)"
    FAILED=1
  fi
fi

# 2. VSAC value sets: structural validation
while IFS= read -r VS; do
  RES="$(python3 - "$VS" <<'PYEOF'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"FAIL unparseable: {e}"); sys.exit(1)
sets = d if isinstance(d, list) else list(d.values())
if not sets:
    print("FAIL zero value sets"); sys.exit(1)
def concepts(vs):
    if isinstance(vs, dict):
        c = vs.get("concepts")
        if c is None and "compose" in vs: return 1  # FHIR ValueSet shape
        return len(c or [])
    return 0
empty = [i for i, vs in enumerate(sets) if concepts(vs) == 0]
if len(empty) == len(sets):
    print(f"FAIL all {len(sets)} value sets have zero concepts"); sys.exit(1)
total = sum(concepts(vs) for vs in sets)
print(f"OK {len(sets)} value sets, {total} concepts" + (f" ({len(empty)} empty)" if empty else ""))
PYEOF
)"
  if [[ "$RES" == OK* ]]; then
    echo "  PASS ${VS#"$QT"/}: $RES"
  else
    echo "  FAIL ${VS#"$QT"/}: $RES"
    FAILED=1
  fi
done < <(find "$QT/2026/measures" \( -name 'value_sets.json' -o -name 'value_sets.vsac-local.json' \) 2>/dev/null | sort)
# (dated snapshots like value_sets.empty-overnight-*.json are historical
#  records of past incidents and deliberately not checked)

if [[ $FAILED -eq 0 ]]; then echo "ARTIFACTS OK"; else echo "ARTIFACTS FAILED"; fi
exit $FAILED
