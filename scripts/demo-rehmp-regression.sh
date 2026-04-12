#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] DFN

Run the rehmp regression demo with saved artifacts and a terminal transcript.

Options:
  --base-url URL         Base URL for the FHIR server.
                         Default: http://127.0.0.1:9085
  --artifacts-root DIR   Parent directory for dated demo artifacts.
                         Default: ./tmp/demo-artifacts
  -h, --help             Show this help.

Example:
  ./scripts/demo-rehmp-regression.sh 101075
EOF
}

FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9085}"
ARTIFACTS_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -ge 2 ]] || { echo "error: --base-url requires a value" >&2; exit 2; }
      FHIR_HTTP_BASE="$2"
      shift 2
      ;;
    --artifacts-root)
      [[ $# -ge 2 ]] || { echo "error: --artifacts-root requires a value" >&2; exit 2; }
      ARTIFACTS_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

DFN="${1:-}"
if [[ -z "$DFN" ]]; then
  usage >&2
  exit 2
fi
shift || true
if [[ $# -gt 0 ]]; then
  echo "error: unexpected argument: $1" >&2
  usage >&2
  exit 2
fi

if [[ -z "$ARTIFACTS_ROOT" ]]; then
  ARTIFACTS_ROOT="$REPO_ROOT/tmp/demo-artifacts"
fi

mkdir -p "$ARTIFACTS_ROOT"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ARTIFACTS_ROOT/rehmp-$RUN_STAMP-dfn-$DFN"
mkdir -p "$RUN_DIR"
LOG_FILE="$RUN_DIR/demo.log"

echo "rehmp regression demo"
echo "base url:       $FHIR_HTTP_BASE"
echo "dfn:            $DFN"
echo "artifact root:  $ARTIFACTS_ROOT"
echo "run directory:  $RUN_DIR"
echo "terminal log:   $LOG_FILE"
echo

(
  cd "$REPO_ROOT"
  ./scripts/rehmp-smoke.sh --base-url "$FHIR_HTTP_BASE" --artifacts-dir "$RUN_DIR" "$DFN"
) 2>&1 | tee "$LOG_FILE"

echo
echo "demo complete"
echo "open artifacts: $RUN_DIR"
