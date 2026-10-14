#!/usr/bin/env bash
# Mount a staged FOIA IRIS.DAT as the FOIA namespace on native IRIS.
#
# Prereq: install.sh has run, and the database file is already at
#   /opt/iris/data/foia/IRIS.DAT
# (copy it with foia-copy.sh, or place it there yourself).
#
# Mappings match scripts/iris-host-setup.sh, plus the %WC routine map that
# iris-web-setup.sh adds. %web* does not cover %WC.
# %wd* is mapped here, before any graph read or write. ^%wd is the Synthea
# graph. An unmapped percent global is stored in the manager database, so a
# later FOIA file copy does not bring it along.
#
# Usage: scripts/iris-native/foia.sh root@host
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"
native_begin "${1:?root@host}"
require_session_helper

echo "== iris-native foia: $HOST =="
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
dat=/opt/iris/data/foia/IRIS.DAT
[[ -f "$dat" ]] || { echo "ERROR: $dat missing; run foia-copy.sh or stage the file" >&2; exit 1; }
id irisusr >/dev/null
mkdir -p /opt/iris/data/foia
chown irisusr:irisusr /opt/iris/data/foia "$dat"
chmod 750 /opt/iris/data/foia
chmod 660 "$dat"
if command -v getenforce >/dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
  # Native kit stores iris.cpf in the install dir. The mgr copy is the Docker layout.
  ref_file=/usr/irissys/iris.cpf
  [[ -f /usr/irissys/mgr/iris.cpf ]] && ref_file=/usr/irissys/mgr/iris.cpf
  chcon --reference=/usr/irissys/mgr /opt/iris/data/foia
  chcon --reference="$ref_file" "$dat"
  echo "SELinux context aligned with /usr/irissys/mgr and $ref_file"
fi
stat -c 'dat %s bytes %U:%G %a' "$dat"
REMOTE

native_m '%SYS' <<'M'
S P("Directory")="/opt/iris/data/foia" W "FOIA db: ",##class(Config.Databases).Create("FOIA",.P),!
K P S P("Globals")="FOIA",P("Routines")="FOIA",P("Library")="IRISLIB" W "FOIA ns: ",##class(Config.Namespaces).Create("FOIA",.P),!
K P S P("Database")="FOIA" F R="%","%DT","%DTC","%XUCI","%web*","%C0*","%Z*","%RCR","%WC" W R," rtn: ",##class(Config.MapRoutines).Create("FOIA",R,.P),!
K P S P("Database")="FOIA" F G="%wd*","%Serenj*","%Z*","%ut*" W G," gbl: ",##class(Config.MapGlobals).Create("FOIA",G,.P),!
K P S P("Database")="IRISTEMP" F G="HLTMP","TMP","UTILITY","XTMP","XUTL" W G," gbl: ",##class(Config.MapGlobals).Create("FOIA",G,.P),!
H
M

out="$(native_m FOIA <<'M'
ZN "FOIA"
D DT^DICRW
W "NS=",$NAMESPACE,!
W "DT=",DT,!
W "DD=",$G(^DD(0,0)),!
H
M
)"
printf '%s\n' "$out"
printf '%s\n' "$out" | grep -q 'NS=FOIA' || { echo "ERROR: FOIA namespace not active" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'DD=ATTRIBUTE' || { echo "ERROR: FileMan DD header missing" >&2; exit 1; }
echo "iris-native foia complete"
