#!/usr/bin/env bash
# iris-host-setup.sh — stand up VistA-on-IRIS on a fresh host (irisfhir.vistaplex.org).
#
# Reproduces the 2026-09-09 bring-up (docs/iris/IRIS_REHEARSAL_2026-09-09.md)
# on a persistent host: IRIS 2026.1 Community, the FOIA VistA database as a
# FOIA namespace, all product routines + M-Web-Server imported and compiled.
#
# Prereqs on the host: Docker; <=8 CPUs (Community license limit); and the two
# migrated database files already staged (rsync'd from ~/work/iris-migration):
#   /opt/iris/data/foia/IRIS.DAT   (VistA data+DD+routines, 4.5G)
#   /opt/iris/data/sys/IRIS.DAT    (old system db, optional reference)
# and routine sources under /opt/iris/import/{codex,web}/*.m
#
# Usage (from the host, as root):  bash iris-host-setup.sh
set -euo pipefail

IMG="containers.intersystems.com/intersystems/iris-community:latest-em"
NAME="iris"

docker pull "$IMG"
mkdir -p /opt/iris/durable /opt/iris/data/foia /opt/iris/data/sys /opt/iris/import
chown -R 51773:51773 /opt/iris/durable /opt/iris/data

docker rm -f "$NAME" 2>/dev/null || true
docker run -d --name "$NAME" --restart unless-stopped --cpus 2 \
  -p 1972:1972 -p 52773:52773 -p 9080:9080 -p 9430:9430 \
  -v /opt/iris/durable:/durable \
  -v /opt/iris/data:/data \
  -e ISC_DATA_DIRECTORY=/durable/iris \
  "$IMG"

echo "waiting for IRIS to boot..."; sleep 45
docker exec "$NAME" iris list | grep -E 'status|versionid'

# --- FOIA database + namespace + mappings (idempotent: Create is a no-op if present) ---
docker exec -i "$NAME" iris session IRIS -U %SYS <<'MSYS'
S P("Directory")="/data/foia" W "FOIA db: ",##class(Config.Databases).Create("FOIA",.P),!
K P S P("Directory")="/data/sys" W "OLDSYS db: ",##class(Config.Databases).Create("OLDSYS",.P),!
K P S P("Globals")="FOIA",P("Routines")="FOIA",P("Library")="IRISLIB" W "FOIA ns: ",##class(Config.Namespaces).Create("FOIA",.P),!
K P S P("Database")="FOIA" F R="%","%DT","%DTC","%XUCI","%web*","%C0*","%Z*","%RCR" W R," rtn: ",##class(Config.MapRoutines).Create("FOIA",R,.P),!
K P S P("Database")="FOIA" F G="%Serenj*","%Z*","%ut*" W G," gbl: ",##class(Config.MapGlobals).Create("FOIA",G,.P),!
K P S P("Database")="IRISTEMP" F G="HLTMP","TMP","UTILITY","XTMP","XUTL" W G," gbl: ",##class(Config.MapGlobals).Create("FOIA",G,.P),!
H
MSYS

# --- routine sources -> UDL .mac (ROUTINE header line; _foo -> %foo) then import+compile ---
docker cp /opt/iris/import/codex "$NAME":/tmp/src-codex
docker cp /opt/iris/import/web   "$NAME":/tmp/src-web
docker exec "$NAME" sh -c 'rm -rf /tmp/mac && mkdir -p /tmp/mac
  for f in /tmp/src-codex/*.m; do b=$(basename "$f" .m); printf "ROUTINE %s [Type=MAC]\n" "$b" | cat - "$f" > /tmp/mac/$b.mac; done
  for f in /tmp/src-web/*.m;   do b=$(basename "$f" .m); nb=$(echo "$b" | sed "s/^_/%/"); printf "ROUTINE %s [Type=MAC]\n" "$nb" | cat - "$f" > /tmp/mac/$nb.mac; done
  ls /tmp/mac/*.mac | wc -l'

docker exec -i "$NAME" iris session IRIS -U FOIA <<'MFOIA'
ZN "FOIA"
K err,loaded
S sc=$SYSTEM.OBJ.ImportDir("/tmp/mac","*.mac","ck-d",.err,1,.loaded)
S k="",c=0 F  S k=$O(err(k)) Q:k=""  S c=c+1
W "import errors: ",c," (expect ~10, all vendored M-Web-Server GT.M-isms)",!
H
MFOIA

echo "iris-host-setup complete. Smoke: scripts/iris-smoke.sh"
echo "For CPRS (RPC Broker on 9430): scripts/iris-cprs-setup.sh"
