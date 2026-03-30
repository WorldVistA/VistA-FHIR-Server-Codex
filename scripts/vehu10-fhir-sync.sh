#!/usr/bin/env bash
# Sync Server-Codex routines into **vehu10** and smoke the HTTP listener on host **9085**.
#
# Use this (not the minimal **fhir** container) when you need **TIU** / visit-linked
# documents on real VEHU patients. Example DFN **101075** often has rich notes on shared VEHU.
#
# Full bootstrap (clone Data-Loader + Codex inside the container): **vehu10_bootstrap.py**
#
# Usage:
#   ./scripts/vehu10-fhir-sync.sh              # smoke /fhir index only
#   ./scripts/vehu10-fhir-sync.sh 101075       # /fhir and /tiustats for that DFN
set -euo pipefail

export FHIR_CONTAINER="${FHIR_CONTAINER:-vehu10}"
export FHIR_HTTP_BASE="${FHIR_HTTP_BASE:-http://127.0.0.1:9085}"
export FHIR_REMOTE_P="${FHIR_REMOTE_P:-/home/vehu/p}"
export FHIR_M_USER="${FHIR_M_USER:-vehu}"
export FHIR_MUMPS="${FHIR_MUMPS:-/home/vehu/lib/gtm/mumps}"

exec "$(cd "$(dirname "$0")" && pwd)/local-fhir-container-sync.sh" "$@"
