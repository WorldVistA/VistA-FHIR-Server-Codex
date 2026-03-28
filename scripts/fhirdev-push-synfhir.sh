#!/usr/bin/env bash
# Copy SYNFHIR.m (any path; often VistA-FHIR-Data-Loader master or the same file as fhir/vehu9) into fhirdev22.
# Does not compile in M — run ZL/ZS or your reload + XINDEX on the container after copy.
# fhirdev22 may track an integration branch whose SYNFHIR omits wsShow; master (and fhir/vehu9) include it.
# After deploy, GET http://<host>:9080/r/SYNFHIR should list wsShow.
set -euo pipefail

FHIRDEV_SSH="${FHIRDEV_SSH:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
REMOTE_DIR="${FHIRDEV_ROUTINE_DIR:-/home/osehra/p}"
REMTMP="/tmp/SYNFHIR-$$.m"

SYNFHIR_M="${1:-${SYNFHIR_M:-}}"
if [[ -z "$SYNFHIR_M" ]]; then
  echo "Usage: $0 /path/to/SYNFHIR.m" >&2
  echo "   or: SYNFHIR_M=/path/to/SYNFHIR.m $0" >&2
  echo "Env: FHIRDEV_SSH, FHIRDEV_CONTAINER, FHIRDEV_ROUTINE_DIR (default $REMOTE_DIR)" >&2
  exit 2
fi
if [[ ! -f "$SYNFHIR_M" ]]; then
  echo "error: not a file: $SYNFHIR_M" >&2
  exit 1
fi

echo "scp -> $FHIRDEV_SSH:$REMTMP"
scp -o BatchMode=yes "$SYNFHIR_M" "$FHIRDEV_SSH:$REMTMP"
echo "docker cp -> $FHIRDEV_CONTAINER:$REMOTE_DIR/SYNFHIR.m"
ssh -o BatchMode=yes "$FHIRDEV_SSH" "docker cp '$REMTMP' '$FHIRDEV_CONTAINER:$REMOTE_DIR/SYNFHIR.m' && rm -f '$REMTMP'"
echo "Done. On the container, reload SYNFHIR from $REMOTE_DIR and XINDEX SYNFHIR."
echo "Public check: open /r/SYNFHIR on the listener — current repo build includes wsShow and wsReplayIntake."
