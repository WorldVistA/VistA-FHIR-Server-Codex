#!/usr/bin/env bash
# Copy SYNFHIR.m (any path; often VistA-FHIR-Data-Loader master or the same file as fhir/vehu9) into fhirdev22.
# Does not compile in M — run ZL/ZS or your reload + XINDEX on the container after copy.
# fhirdev22 may track an integration branch whose SYNFHIR omits wsShow; master (and fhir/vehu9) include it.
# After deploy, GET http://<host>:9080/r/SYNFHIR should list wsShow.
set -euo pipefail

FHIRDEV_SSH="${FHIRDEV_SSH:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
# fhirdev22 uses vehu-owned sources under /home/vehu/p (not /home/osehra/p).
REMOTE_DIR="${FHIRDEV_ROUTINE_DIR:-/home/vehu/p}"
VEHU_ENV="${VEHU_ENV:-/home/vehu/etc/env}"
REMTMP="/tmp/SYNFHIR-$$.m"

SYNFHIR_M="${1:-${SYNFHIR_M:-}}"
if [[ -z "$SYNFHIR_M" ]]; then
  echo "Usage: $0 /path/to/SYNFHIR.m" >&2
  echo "   or: SYNFHIR_M=/path/to/SYNFHIR.m $0" >&2
  echo "Env: FHIRDEV_SSH, FHIRDEV_CONTAINER, FHIRDEV_ROUTINE_DIR (default $REMOTE_DIR), FHIRDEV_ZL=1, VEHU_ENV" >&2
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
echo "Done. Copied to $FHIRDEV_CONTAINER:$REMOTE_DIR/SYNFHIR.m"

if [[ "${FHIRDEV_ZL:-0}" == 1 ]]; then
  echo "FHIRDEV_ZL=1: ZL \"SYNFHIR\" via mumps -dir (user vehu)"
  ssh -o BatchMode=yes "$FHIRDEV_SSH" "docker exec -i -u vehu $FHIRDEV_CONTAINER bash -lc 'source $VEHU_ENV >/dev/null 2>&1; mumps -dir'" <<'MUMPS'
ZL "SYNFHIR"
H
MUMPS
fi

echo "If not using FHIRDEV_ZL=1: at VEHU> run ZL \"SYNFHIR\" then XINDEX SYNFHIR as needed."
echo "Smoke: curl -sS 'http://127.0.0.1:9080/showfhir?ien=<graph-ien>' (use host/port your listener uses)."
echo "Public check: /r/SYNFHIR should list wsShow when this build is loaded."
