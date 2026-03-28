#!/usr/bin/env bash
# Generate one Synthea patient as a FHIR R4 bundle (Docker + JDK).
# See docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md — seed must be numeric.
set -euo pipefail

SYN_SYNTHEA_ROOT="${SYN_SYNTHEA_ROOT:-/home/glilly/work/vista-stack/synthea}"
STATE="${STATE:-Massachusetts}"
RUN_DATE="${RUN_DATE:-$(date +%Y%m%d)}"
SEED=""
OUT_DIR=""
DOCKER_IMAGE="${SYNTHEA_JDK_IMAGE:-eclipse-temurin:17-jdk}"

usage() {
  echo "Usage: $0 -o OUT_DIR [-s SEED] [-S STATE] [-r YYYYMMDD]"
  echo "  -o OUT_DIR   Host directory for exporter output (created if missing)."
  echo "  -s SEED      Numeric Synthea RNG seed (default: seconds since epoch)."
  echo "  -S STATE     Synthea state (default: Massachusetts)."
  echo "  -r RUN_DATE  Reference date YYYYMMDD (default: today)."
  echo "Env: SYN_SYNTHEA_ROOT — path to synthea clone (default: $SYN_SYNTHEA_ROOT)"
  echo "     SYNTHEA_JDK_IMAGE — Docker JDK image (default: $DOCKER_IMAGE)"
}

while getopts "ho:s:S:r:" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    o) OUT_DIR="$OPTARG" ;;
    s) SEED="$OPTARG" ;;
    S) STATE="$OPTARG" ;;
    r) RUN_DATE="$OPTARG" ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  echo "error: -o OUT_DIR is required" >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$SYN_SYNTHEA_ROOT/run_synthea" ]]; then
  echo "error: missing $SYN_SYNTHEA_ROOT/run_synthea (set SYN_SYNTHEA_ROOT?)" >&2
  exit 1
fi

if [[ -z "$SEED" ]]; then
  SEED="$(date +%s)"
fi
if ! [[ "$SEED" =~ ^[0-9]+$ ]]; then
  echo "error: -s SEED must be numeric (Synthea -s); got: $SEED" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

echo "Synthea: root=$SYN_SYNTHEA_ROOT out=$OUT_DIR seed=$SEED runDate=$RUN_DATE state=$STATE"

docker run --rm \
  -e GRADLE_USER_HOME=/tmp/gradle \
  -v "$SYN_SYNTHEA_ROOT:/work" \
  -v "$OUT_DIR:/out" \
  -w /work \
  "$DOCKER_IMAGE" \
  ./run_synthea \
    -p 1 \
    -s "$SEED" \
    -r "$RUN_DATE" \
    --exporter.fhir.export=true \
    --exporter.baseDirectory="/out" \
    "$STATE"

FHIR_DIR="$OUT_DIR/fhir"
if [[ ! -d "$FHIR_DIR" ]]; then
  echo "error: expected directory $FHIR_DIR" >&2
  exit 1
fi

mapfile -t bundles < <(find "$FHIR_DIR" -maxdepth 1 -type f -name '*.json' ! -name 'hospitalInformation*.json' | sort)
if [[ "${#bundles[@]}" -lt 1 ]]; then
  echo "error: no patient bundle JSON under $FHIR_DIR" >&2
  exit 1
fi

if [[ "${#bundles[@]}" -gt 1 ]]; then
  echo "warning: multiple bundles; using first sorted path:" >&2
fi
BUNDLE="${bundles[0]}"
echo "BUNDLE=$BUNDLE"
echo "bytes=$(wc -c <"$BUNDLE")"
