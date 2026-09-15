#!/usr/bin/env bash
# Generate one Synthea patient, POST /addpatient, harvest the load log.
# Usage:
#   scripts/synthea-load-error-loop.sh fhirprod
#   scripts/synthea-load-error-loop.sh fhirdev
#   HOST=https://fhir.vistaplex.org scripts/synthea-load-error-loop.sh
#   SEED=42 AGE=60-65 scripts/synthea-load-error-loop.sh fhirprod
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYN="${SYN_ROOT:-$ROOT/../synthea}"
TARGET="${1:-fhirprod}"
SEED="${SEED:-}"
AGE="${AGE:-}"
POP="${POP:-1}"

case "$TARGET" in
  fhirprod|fhir)
    HOST="${HOST:-https://fhir.vistaplex.org}"
    ;;
  fhirdev|devfhir)
    HOST="${HOST:-https://devfhir.vistaplex.org}"
    ;;
  vehu10)
    HOST="${HOST:-http://127.0.0.1:9085}"
    ;;
  rpmsfhir)
    HOST="${HOST:-https://rpmsfhir.vistaplex.org}"
    ;;
  *)
    echo "unknown target $TARGET (fhirprod|fhirdev|vehu10|rpmsfhir)" >&2
    exit 2
    ;;
esac

if [[ ! -d "$SYN" ]]; then
  echo "Synthea checkout not found at $SYN" >&2
  exit 2
fi

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$SYN/output_c0fw_java/${TARGET}-${RUN_ID}"
mkdir -p "$OUT_DIR" \
  /home/glilly/work/vista-stack/synthea-gradle-cache-user \
  /home/glilly/work/vista-stack/synthea-gradle-project-cache-user \
  /home/glilly/work/vista-stack/synthea-build-user

PARAMS="['-p','${POP}','--exporter.baseDirectory=/work/${OUT_DIR#"$SYN/"}','--exporter.fhir.export=true','--exporter.fhir.transaction_bundle=true'"
if [[ -n "$SEED" ]]; then
  PARAMS="${PARAMS},'-s','${SEED}'"
fi
if [[ -n "$AGE" ]]; then
  PARAMS="${PARAMS},'-a','${AGE}'"
fi
PARAMS="${PARAMS}]"

echo "=== generate Synthea → $OUT_DIR ==="
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e GRADLE_USER_HOME=/gradle-cache \
  -v "$SYN:/work" \
  -v /home/glilly/work/vista-stack/synthea-gradle-cache-user:/gradle-cache \
  -v /home/glilly/work/vista-stack/synthea-gradle-project-cache-user:/project-cache \
  -v /home/glilly/work/vista-stack/synthea-build-user:/work/build \
  -w /work \
  eclipse-temurin:17-jdk \
  sh -lc "./gradlew --project-cache-dir /project-cache run -Params=\"${PARAMS}\""

BUNDLE="$(ls -1t "$OUT_DIR"/fhir/*.json | head -n 1)"
echo "bundle: $BUNDLE"

RESP="$(mktemp)"
echo "=== POST $HOST/addpatient?load=1 ==="
HTTP="$(curl -sS -o "$RESP" -w '%{http_code}' \
  -H 'Expect:' \
  -H 'Content-Type: application/json' \
  --data-binary "@${BUNDLE}" \
  "${HOST}/addpatient?load=1")"
echo "HTTP $HTTP"
head -c 800 "$RESP"; echo
if [[ "$HTTP" == "400" ]]; then
  echo "Bad Request: empty/non-Bundle body or proxy rejection — not a domain load error." >&2
  exit 1
fi
if [[ "$HTTP" != "200" && "$HTTP" != "201" ]]; then
  echo "addpatient failed" >&2
  exit 1
fi

HARVEST_DIR="${HARVEST_DIR:-$ROOT/tmp/load-harvest}"
mkdir -p "$HARVEST_DIR"
OUT="$HARVEST_DIR/${TARGET}-${RUN_ID}.json"
echo "=== harvest $HOST/fhir ==="
python3 "$ROOT/scripts/harvest-load-errors.py" \
  --url "${HOST}/fhir" \
  --logs "${LOGS:-2}" \
  --out "$OUT"
echo "harvest: $OUT"
echo "LOOP STEP OK host=$TARGET http=$HTTP harvest=$OUT"
