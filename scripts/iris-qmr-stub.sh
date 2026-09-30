#!/usr/bin/env bash
# Publish a stub MeasureReports tree on Iris so QMRDIR^C0FQUAL finds index.html
# quickly (option C). EMPTY marker tells HASQMR there are no Patient-*.json freezes
# yet — remove EMPTY when real freezes are copied in.
#
# Usage: ./scripts/iris-qmr-stub.sh [ssh-host]
set -euo pipefail
HOST="${1:-root@irisfhir.vistaplex.org}"
ROOT=/opt/iris/durable/www/filesystem/quality/measurereports
SSHCTL="/tmp/ssh-qmrstub-$$"
SSHMUX=(-o BatchMode=yes -o ConnectTimeout=25 -o ConnectionAttempts=10 \
        -o ControlMaster=auto -o "ControlPath=$SSHCTL" -o ControlPersist=60)
trap 'ssh -o "ControlPath=$SSHCTL" -O exit "$HOST" 2>/dev/null || true' EXIT

ssh "${SSHMUX[@]}" "$HOST" bash -s <<REMOTE
set -euo pipefail
ROOT='$ROOT'
mkdir -p "\$ROOT"
cat > "\$ROOT/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Quality MeasureReports (Iris stub)</title>
  <style>
    body { font-family: Georgia, serif; margin: 2rem; color: #1b1b1b; background: #f7f4ef; }
    .muted { color: #666; }
  </style>
</head>
<body>
  <h1>Quality MeasureReports</h1>
  <p class="muted">Stub published for Iris so dashboard QMRDIR probes succeed.
  No frozen Patient MeasureReports on this lane yet. Remove the EMPTY marker
  file in this directory when real freezes are deployed.</p>
</body>
</html>
HTML
# Presence of EMPTY => HASQMR^C0FQUAL returns 0 without per-DFN FTG misses.
echo "no-freezes" > "\$ROOT/EMPTY"
chmod -R a+rX "\$ROOT"
ls -la "\$ROOT"
REMOTE

echo "Stub OK at $HOST:$ROOT"
echo "Verify: curl -sS -o /dev/null -w '%{http_code} %{time_total}s\\n' https://irisfhir.vistaplex.org/fhir-quality-dashboards/CMS122v14"
