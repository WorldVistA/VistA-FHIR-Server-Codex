#!/usr/bin/env bash
# Self-announcing CPRS-demo UI drift check across the public fleet.
#
# Compares each lane's /demos/cprs/version.json (written by
# rehmp/deploy/publish-ui-all.sh) against the rehmp repo HEAD. Born from
# the 2026-09-13 audit that found four silent UI vintages live (Sep 9 /
# Sep 9 / Aug 6 / Jul 13). Called at the end of deploy-quality-all.sh;
# also rerunnable standalone.
#
# Exit: 0 all match, 1 drift or missing stamp (callers may treat as WARN).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REHMP="${REHMP_ROOT:-$ROOT/../rehmp}"
HOSTS="${UI_CHECK_HOSTS:-devfhir.vistaplex.org irisfhir.vistaplex.org rpmsfhir.vistaplex.org fhir.vistaplex.org}"

EXPECT=""
if [[ -d "$REHMP/.git" ]]; then
  EXPECT="$(git -C "$REHMP" rev-parse --short HEAD 2>/dev/null || true)"
fi
if [[ -z "$EXPECT" ]]; then
  echo "ui-versions: SKIP (rehmp repo not found at $REHMP)"
  exit 0
fi

FAIL=0
for H in $HOSTS; do
  GOT="$(curl -sk -m 15 "https://$H/demos/cprs/version.json" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("commit",""))' 2>/dev/null)"
  if [[ -z "$GOT" ]]; then
    echo "ui-versions: WARN $H — no version.json (pre-stamp build live?)"
    FAIL=1
  elif [[ "$GOT" == "$EXPECT" || "$GOT" == "$EXPECT-dirty" ]]; then
    echo "ui-versions: OK   $H — $GOT"
  else
    echo "ui-versions: WARN $H — serving $GOT, rehmp HEAD is $EXPECT (run rehmp/deploy/publish-ui-all.sh)"
    FAIL=1
  fi
done
exit $FAIL
