#!/usr/bin/env bash
# Copy a Synthea (or other) FHIR bundle to fhirdev and POST /addPatient.
# Register the route if needed; use empty Expect: to avoid curl 100-continue issues.
# See docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md
set -euo pipefail

FHIRDEV_HOST="${FHIRDEV_HOST:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
VEHU_ENV="${VEHU_ENV:-/home/vehu/etc/env}"
REMOTE_JSON=""
LOCAL_JSON=""
REGISTER=0
# Empty = auto: restart webreq when --register, else no restart
RESTART_WEBREQ=""
HTTP_URL="${FHIRDEV_HTTP:-http://127.0.0.1:9080}"

usage() {
  echo "Usage: $0 [options] LOCAL_BUNDLE.json"
  echo "  LOCAL_BUNDLE.json   FHIR Bundle file to POST to addPatient"
  echo "  --register          Run addService^%webutils for POST addPatient (once per site)"
  echo "  --restart-webreq    d stop^%webreq d go^%webreq (implied after --register unless --no-restart-webreq)"
  echo "  --no-restart-webreq Skip listener restart (use with --register if routes already picked up)"
  echo "  --remote-path PATH  Staging path on host (default /tmp/synthea-patient-PID.json)"
  echo "Env: FHIRDEV_HOST (default $FHIRDEV_HOST)"
  echo "     FHIRDEV_CONTAINER (default $FHIRDEV_CONTAINER)"
  echo "     FHIRDEV_HTTP (default $HTTP_URL, used from remote host via curl)"
  echo "     FHIRDEV_REMOTE_JSON if set, skip scp and POST this path on the remote host"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --register) REGISTER=1; shift ;;
    --restart-webreq) RESTART_WEBREQ=1; shift ;;
    --no-restart-webreq) RESTART_WEBREQ=0; shift ;;
    --remote-path) REMOTE_JSON="$2"; shift 2 ;;
    --remote-path=*) REMOTE_JSON="${1#*=}"; shift ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$LOCAL_JSON" ]]; then
        echo "error: extra argument: $1" >&2
        exit 2
      fi
      LOCAL_JSON="$1"
      shift
      ;;
  esac
done

if [[ -z "$REMOTE_JSON" ]]; then
  REMOTE_JSON="/tmp/synthea-patient-$$.json"
fi

if [[ -z "$FHIRDEV_REMOTE_JSON" ]]; then
  if [[ -z "$LOCAL_JSON" ]]; then
    echo "error: LOCAL_BUNDLE.json required (or set FHIRDEV_REMOTE_JSON)" >&2
    usage >&2
    exit 2
  fi
  if [[ ! -f "$LOCAL_JSON" ]]; then
    echo "error: not a file: $LOCAL_JSON" >&2
    exit 1
  fi
  echo "scp -> $FHIRDEV_HOST:$REMOTE_JSON"
  scp -o BatchMode=yes "$LOCAL_JSON" "$FHIRDEV_HOST:$REMOTE_JSON"
  REMOTE_USE="$REMOTE_JSON"
else
  REMOTE_USE="$FHIRDEV_REMOTE_JSON"
  echo "using remote file $REMOTE_USE (no scp)"
fi

if [[ -z "$RESTART_WEBREQ" ]]; then
  if [[ "$REGISTER" -eq 1 ]]; then
    RESTART_WEBREQ=1
  else
    RESTART_WEBREQ=0
  fi
fi

if [[ "$REGISTER" -eq 1 ]]; then
  echo "register POST addPatient -> wsPostFHIR^SYNFHIR in $FHIRDEV_CONTAINER"
  printf '%s\n' \
    'S DUZ=1 D ^XUP' \
    '^' \
    'D addService^%webutils("POST","addPatient","wsPostFHIR^SYNFHIR")' \
    'H' \
    | ssh -o BatchMode=yes "$FHIRDEV_HOST" \
        "docker exec -i -u vehu $FHIRDEV_CONTAINER bash -lc 'source $VEHU_ENV >/dev/null 2>&1; mumps -dir'"
fi

if [[ "$RESTART_WEBREQ" -ne 0 ]]; then
  echo "restart %webreq in $FHIRDEV_CONTAINER"
  ssh -o BatchMode=yes "$FHIRDEV_HOST" \
    "docker exec -u vehu $FHIRDEV_CONTAINER bash -lc 'source $VEHU_ENV >/dev/null 2>&1; mumps -run %XCMD \"d stop^%webreq d go^%webreq\"'"
fi

echo "POST $HTTP_URL/addPatient (Expect disabled)"
# shellcheck disable=SC2029
ssh -o BatchMode=yes "$FHIRDEV_HOST" \
  "curl -sS -H 'Expect:' -H 'Content-Type: application/json' \
    --data-binary @\"$REMOTE_USE\" \
    \"$HTTP_URL/addPatient\""

echo ""
