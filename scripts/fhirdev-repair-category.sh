#!/usr/bin/env bash
# Selectively rerun SYN wsIntake* loaders for one patient on fhirdev22 (remote SSH + docker exec).
# Uses setroot^SYNWD("fhir-intake") for ROOT (matches typical VEHU graph store).
# Prereq: updated routines (e.g. SYNFLAB) copied to the container and XINDEX'd.
set -euo pipefail

FHIRDEV_SSH="${FHIRDEV_SSH:-root@fhirdev.vistaplex.org}"
FHIRDEV_CONTAINER="${FHIRDEV_CONTAINER:-fhirdev22}"
VEHU_ENV="${VEHU_ENV:-/home/vehu/etc/env}"
DFN=""
IEN=""
CATEGORIES="labs"
DEBUG_M="0"

usage() {
  echo "Usage: $0 --dfn DFN [--ien IEN] [--category labs] [--debug]"
  echo "  --category  comma list: labs,vitals,encounters,immunizations,conditions,allergy,appointment,meds,procedures,careplan"
  echo "Env: FHIRDEV_SSH (default $FHIRDEV_SSH), FHIRDEV_CONTAINER (default $FHIRDEV_CONTAINER)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dfn) DFN="$2"; shift 2 ;;
    --ien) IEN="$2"; shift 2 ;;
    --category) CATEGORIES="$2"; shift 2 ;;
    --debug) DEBUG_M="1"; shift ;;
    *) echo "unknown: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$DFN" ]]; then
  echo "error: --dfn required" >&2
  usage >&2
  exit 2
fi

resolve_ien() {
  ssh -o BatchMode=yes "$FHIRDEV_SSH" "docker exec -i -u vehu $FHIRDEV_CONTAINER bash -lc 'source $VEHU_ENV >/dev/null 2>&1; mumps -dir'" <<MUMPS
S DUZ=1 D ^XUP
^
N DFN,R,I,MX S DFN=$DFN,R=\$\$setroot^SYNWD("fhir-intake"),MX=0
F I=0:0 S I=\$O(@R@("DFN",DFN,I)) Q:I<1  S:I>MX MX=I
W "MAX_IEN=",MX,!
H

MUMPS
}

if [[ -z "$IEN" ]]; then
  echo "Resolving graph IEN for DFN $DFN..."
  out="$(resolve_ien | tr -d '\r')"
  echo "$out"
  IEN="$(echo "$out" | sed -n 's/^MAX_IEN=//p' | tail -1 | tr -d '[:space:]')"
  if [[ -z "$IEN" || "$IEN" -lt 1 ]]; then
    echo "error: could not resolve IEN (got '$IEN')" >&2
    exit 1
  fi
  echo "Using IEN=$IEN"
fi

# Map category -> short M lines (direct mode truncates very long lines). LK = load subscript name.
build_repair_block() {
  local cat="$1"
  case "$cat" in
    labs)
      printf 'K RTN\nD wsIntakeLabs^SYNFLAB(.ARGS,,.RTN,%s)\nN LK S LK="labs"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### labs ###",!\n' "$IEN" "$IEN"
      ;;
    vitals)
      printf 'K RTN\nD wsIntakeVitals^SYNFVIT(.ARGS,,.RTN,%s)\nN LK S LK="vitals"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### vitals ###",!\n' "$IEN" "$IEN"
      ;;
    encounters)
      printf 'K RTN\nD wsIntakeEncounters^SYNFENC(.ARGS,,.RTN,%s)\nN LK S LK="encounters"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### encounters ###",!\n' "$IEN" "$IEN"
      ;;
    immunizations)
      printf 'K RTN\nD wsIntakeImmu^SYNFIMM(.ARGS,,.RTN,%s)\nN LK S LK="immunizations"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### immunizations ###",!\n' "$IEN" "$IEN"
      ;;
    conditions)
      printf 'K RTN\nD wsIntakeConditions^SYNFPRB(.ARGS,,.RTN,%s)\nN LK S LK="conditions"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### conditions ###",!\n' "$IEN" "$IEN"
      ;;
    allergy)
      printf 'K RTN\nD wsIntakeAllergy^SYNFALG(.ARGS,,.RTN,%s)\nN LK S LK="allergy"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### allergy ###",!\n' "$IEN" "$IEN"
      ;;
    appointment)
      printf 'K RTN\nD wsIntakeAppointment^SYNFAPT(.ARGS,,.RTN,%s)\nN LK S LK="appointment"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### appointment ###",!\n' "$IEN" "$IEN"
      ;;
    meds)
      printf 'K RTN\nD wsIntakeMeds^SYNFMED2(.ARGS,,.RTN,%s)\nN LK S LK="meds"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### meds ###",!\n' "$IEN" "$IEN"
      ;;
    procedures)
      printf 'K RTN\nD wsIntakeProcedures^SYNFPROC(.ARGS,,.RTN,%s)\nN LK S LK="procedures"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### procedures ###",!\n' "$IEN" "$IEN"
      ;;
    careplan)
      printf 'K RTN\nD wsIntakeCareplan^SYNFCP(.ARGS,,.RTN,%s)\nN LK S LK="careplan"\nI $D(RTN(LK)) M @ROOT@(%s,"load",LK)=RTN(LK)\nW !,"### careplan ###",!\n' "$IEN" "$IEN"
      ;;
    *) echo "error: unknown category '$cat'" >&2; exit 2 ;;
  esac
}

{
  echo "S DUZ=1 D ^XUP"
  echo "^"
  echo "D INITMAPS^SYNQLDM"
  echo 'N ROOT S ROOT=$$setroot^SYNWD("fhir-intake")'
  echo 'S ARGS("load")=1'
  echo "S ARGS(\"debug\")=$DEBUG_M"
  IFS=',' read -ra ARR <<< "$CATEGORIES"
  for raw in "${ARR[@]}"; do
    c="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    [[ -z "$c" ]] && continue
    build_repair_block "$c"
  done
  echo "H"
} | ssh -o BatchMode=yes "$FHIRDEV_SSH" "docker exec -i -u vehu $FHIRDEV_CONTAINER bash -lc 'source $VEHU_ENV >/dev/null 2>&1; mumps -dir'"

echo "done DFN=$DFN IEN=$IEN categories=$CATEGORIES"
