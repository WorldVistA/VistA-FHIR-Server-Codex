#!/usr/bin/env bash
# Rerun SYN domain loaders (labs, vitals, encounters, …) from graph-stored JSON
# without POST /addPatient (avoids Duplicate SSN when the bundle was already ingested once).
# Prereq: register GET replayIntake (and optional alias replayImport) -> wsReplayIntake^SYNFHIR.
set -euo pipefail

FHIRDEV_HOST="${FHIRDEV_HOST:-root@fhirdev.vistaplex.org}"
BASE_URL="${FHIRDEV_BASE_URL:-http://fhirdev.vistaplex.org:9080}"
# Path segment: replayIntake (default) or replayImport (alias to same handler; see SYNWEBRG EN^SYNWEBRG)
REPLAY_ROUTE="${FHIRDEV_REPLAY_ROUTE:-replayIntake}"
IEN=""
DFN=""
REINDEX=1

usage() {
  echo "Usage: $0 --ien IEN [--dfn DFN] [--reindex 0|1]"
  echo "  --ien     Graph-store IEN holding the FHIR bundle (from addPatient JSON or /fhir index)."
  echo "  --dfn     Existing VistA patient; required when the graph row is orphan (e.g. Duplicate SSN)."
  echo "  --reindex 1 (default) rebuild type index from json; 0 to skip."
  echo "Or only --dfn to use dfn2ien^SYNFUTL (patient already linked to a graph row)."
  echo "Env: FHIRDEV_HOST (ssh unused), FHIRDEV_BASE_URL (default $BASE_URL), FHIRDEV_REPLAY_ROUTE (default $REPLAY_ROUTE)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ien) IEN="$2"; shift 2 ;;
    --dfn) DFN="$2"; shift 2 ;;
    --reindex) REINDEX="$2"; shift 2 ;;
    *) echo "unknown: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$IEN" && -z "$DFN" ]]; then
  echo "error: need --ien and/or --dfn" >&2
  usage >&2
  exit 2
fi

q=()
[[ -n "$IEN" ]] && q+=(--data-urlencode "ien=$IEN")
[[ -n "$DFN" ]] && q+=(--data-urlencode "dfn=$DFN")
q+=(--data-urlencode "reindex=$REINDEX")

curl -sS -G "$BASE_URL/$REPLAY_ROUTE" "${q[@]}"
echo ""
