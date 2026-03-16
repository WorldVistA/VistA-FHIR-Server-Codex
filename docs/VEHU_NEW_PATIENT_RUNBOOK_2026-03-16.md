# VEHU New Patient Runbook

## Purpose

This runbook captures the exact steps used to prepare `VEHU` on `fhirdev.vistaplex.org` for loading a brand new Synthea patient without doing a full KIDS install.

It covers:

- direct routine deployment into the running container
- `XINDEX` checks on the deployed routines
- the post-deploy rebuild needed to refresh file `81` and Lex
- `addPatient` web-service registration and usage
- Dockerized Synthea generation on the local workstation

## Target Code Levels

- `FHIR`: `master` at `aa179ea`
- `SYN`: `vaready-wd-compat` at `4fc4858`

## Runtime Facts Confirmed On VEHU

- SSH target: `root@fhirdev.vistaplex.org`
- Docker container: `fhirdev`
- In-container VistA user: `vehu`
- Routine directory: `/home/vehu/p`
- Host-local HTTP base: `http://127.0.0.1:9080`

During setup, host-local `127.0.0.1:9080` worked reliably from the remote host, while the public `fhirdev.vistaplex.org:9080` path was not reliable from the outside. For admin smoke checks and the import POST, prefer running `curl` on the host through SSH.

## Direct Routine Deployment

The following routine set was copied into `/home/vehu/p`:

- `C0FHIR.m`
- `C0FHIRP.m`
- `SYNDHP61.m`
- `SYNQLDM.m`
- `SYNWD.m`
- `SYNFLAB.m`
- `SYNLABFX.m`
- `SYNGBLLD.m`
- `SYNOS5LD.m`
- `SYNOS5PT.m`
- `SYNOS5D1.m`
- `SYNOS5D2.m`
- `SYNOS5D3.m`
- `SYNOS5D4.m`
- `SYNOS5D5.m`
- `SYNOS5D6.m`

Commands:

```bash
FHIR_SRC="/home/glilly/work/vista-stack/VistA-FHIR-Server-Codex/src"
SYN_SRC="/home/glilly/work/vista-stack/VistA-FHIR-Data-Loader/src"
HOST="root@fhirdev.vistaplex.org"
REMOTE_STAGE="/tmp/vehu-deploy-20260316"

ssh "$HOST" "mkdir -p \"$REMOTE_STAGE\""

scp \
  "$FHIR_SRC/C0FHIR.m" \
  "$FHIR_SRC/C0FHIRP.m" \
  "$SYN_SRC/SYNDHP61.m" \
  "$SYN_SRC/SYNQLDM.m" \
  "$SYN_SRC/SYNWD.m" \
  "$SYN_SRC/SYNFLAB.m" \
  "$SYN_SRC/SYNLABFX.m" \
  "$SYN_SRC/SYNGBLLD.m" \
  "$SYN_SRC/SYNOS5LD.m" \
  "$SYN_SRC/SYNOS5PT.m" \
  "$SYN_SRC/SYNOS5D1.m" \
  "$SYN_SRC/SYNOS5D2.m" \
  "$SYN_SRC/SYNOS5D3.m" \
  "$SYN_SRC/SYNOS5D4.m" \
  "$SYN_SRC/SYNOS5D5.m" \
  "$SYN_SRC/SYNOS5D6.m" \
  "$HOST:$REMOTE_STAGE/"

ssh "$HOST" '
  for f in /tmp/vehu-deploy-20260316/*.m; do
    docker cp "$f" fhirdev:/home/vehu/p/
  done
'
```

## XINDEX On VEHU

Use smaller `QUICK^XINDX6` batches rather than one very long routine list, because the direct-mode input line becomes awkward to manage.

Example:

```bash
printf '%s\n' \
  'S DUZ=1 D ^XUP' \
  '^' \
  'D QUICK^XINDX6("C0FHIR,C0FHIRP")' \
  'H' \
  | ssh root@fhirdev.vistaplex.org \
      "docker exec -i fhirdev bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -dir'"
```

Observed result on VEHU:

- no syntax errors in the deployed routines
- `C0FHIR` still reports expected size warnings
- legacy/generated `SYN*` routines still report known SAC/style warnings

## Post-Deploy Rebuild For File 81 And Lex

`POST^SYNKIDS` is a M routine entrypoint, not a web service. For this direct-copy deployment, the correct post-deploy rebuild step is `EN^SYNGBLLD`.

Why `EN^SYNGBLLD` matters here:

- reloads `^SYN("2002.030","sct2cpt")`
- reloads `^SYN("2002.030","sct2os5")` from `SYNOS5D*.m` via `LOADOS5^SYNOS5LD`
- recreates missing synthetic OS5 entries in file `81` and Lex via `EN^SYNOS5PT`

Command:

```bash
printf '%s\n' \
  'S DUZ=1 D ^XUP' \
  '^' \
  'D EN^SYNGBLLD' \
  'H' \
  | ssh root@fhirdev.vistaplex.org \
      "docker exec -i fhirdev bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -dir'"
```

Verified immediately after rebuild:

- `$$COUNT^SYNOS5LD` returned `1041`
- `^SYN("2002.030","sct2os5","direct",410620009,...)` contains `3282K`
- `^ICPT("B","3282K",...)` resolves to IEN `200000319`
- `^LEX(757.02,"CODE","3282K ",...)` resolves to IEN `3000000320`

Verification command:

```bash
printf '%s\n' \
  'S DUZ=1 D ^XUP' \
  '^' \
  'W $$COUNT^SYNOS5LD,! ' \
  'W $O(^SYN("2002.030","sct2os5","direct",410620009," ")),! ' \
  'W $O(^ICPT("B","3282K",0)),! ' \
  'W $O(^LEX(757.02,"CODE","3282K ",0)),! ' \
  'H' \
  | ssh root@fhirdev.vistaplex.org \
      "docker exec -i fhirdev bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -dir'"
```

## `addPatient` Web Service

The handler is:

- method: `POST`
- route: `addPatient`
- entrypoint: `wsPostFHIR^SYNFHIR`

Registration from the `VEHU>` prompt:

```text
d addService^%webutils("POST","addPatient","wsPostFHIR^SYNFHIR")
```

`load=1` is optional. `wsPostFHIR^SYNFHIR` defaults `ARGS("load")=1` when patient creation succeeds, so these are equivalent for normal imports:

- `POST /addPatient`
- `POST /addPatient?load=1`

## Web Listener Smoke Check

Confirmed on VEHU after deployment:

- `curl http://127.0.0.1:9080/fhir` returned HTTP `200`
- the response body began with `FHIR Patient Index`

Status-only check:

```bash
ssh root@fhirdev.vistaplex.org \
  "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9080/fhir"
```

Content-prefix check:

```bash
ssh root@fhirdev.vistaplex.org \
  "python3 - <<'PY'
import urllib.request
url='http://127.0.0.1:9080/fhir'
with urllib.request.urlopen(url, timeout=15) as r:
    body = r.read(300).decode('utf-8', errors='replace')
    print('STATUS', r.status)
    print(body)
PY"
```

If the listener is not answering, start `%webreq` inside the container:

```bash
ssh root@fhirdev.vistaplex.org \
  "docker exec fhirdev bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -run %XCMD \"d go^%webreq\"'"
```

## Run Synthea Locally With Docker

Java does not need to be installed directly on the workstation if Synthea is run inside a JDK container.

Validated bootstrap command:

```bash
docker run --rm \
  -e GRADLE_USER_HOME=/tmp/gradle \
  -v "/home/glilly/work/vista-stack/synthea:/work" \
  -w /work \
  eclipse-temurin:17-jdk \
  ./run_synthea -h
```

Notes:

- the first run downloads Gradle and compiles the project, so expect several minutes of startup time
- `GRADLE_USER_HOME=/tmp/gradle` avoids stale lock issues under the mounted repo
- the warning about missing `git` inside the container affects `version.txt` only and did not block Synthea execution

Example one-patient generation command with a host-mounted output directory:

```bash
RUN_DATE="$(date +%Y%m%d)"
SEED="20260316"
mkdir -p "/home/glilly/FHIR-source-files/tonight"

docker run --rm \
  -e GRADLE_USER_HOME=/tmp/gradle \
  -v "/home/glilly/work/vista-stack/synthea:/work" \
  -v "/home/glilly/FHIR-source-files/tonight:/out" \
  -w /work \
  eclipse-temurin:17-jdk \
  ./run_synthea \
    -p 1 \
    -s "$SEED" \
    -r "$RUN_DATE" \
    --exporter.fhir.export=true \
    --exporter.baseDirectory="/out" \
    Massachusetts
```

Expected output location:

- `/home/glilly/FHIR-source-files/tonight/fhir/*.json`

## POST The Generated Patient To VEHU

Because host-local `127.0.0.1:9080` was the reliable path during setup, the cleanest import flow is:

1. copy the generated patient JSON to the VEHU host
2. run the `POST /addPatient` from that host

Example:

```bash
PATIENT_JSON="/home/glilly/FHIR-source-files/tonight/fhir/<patient>.json"

scp "$PATIENT_JSON" root@fhirdev.vistaplex.org:/tmp/new-patient.json

ssh root@fhirdev.vistaplex.org \
  "curl -sS \
     -H 'Content-Type: application/json' \
     --data-binary @/tmp/new-patient.json \
     http://127.0.0.1:9080/addPatient"
```

The JSON response should include at least:

- `dfn`
- `ien`
- per-domain load status nodes such as encounters, procedures, labs, vitals, and conditions

## Quick Post-Load Checks

After a successful `addPatient` response:

- request `GET /fhir?dfn=<DFN>` through the VEHU host-local listener
- confirm the imported patient appears in the FHIR patient index
- review the returned loader status counts for obvious domain failures
- if needed, use the existing loader menu and load-log tools on VEHU for category-level troubleshooting

## Live Run Notes

The first two real import attempts produced useful runtime findings:

- `Sergio619 Manzanares924` was rejected as `Duplicate SSN` and was later
  confirmed to already exist on VEHU as `DFN 101088`.
- `Abbie917 Leighann368 Harris789` initially failed in lab import with
  `%YDB-E-LVUNDEF` at `LABADD+24^SYNDHP63` because `SYNFLAB` called
  `LABADD^SYNDHP63` without passing `DHPCSAMP`, while `SYNDHP63` wrote that
  local variable directly.

That lab issue was fixed in `VistA-FHIR-Data-Loader` by normalizing the
argument at the start of `LABADD^SYNDHP63`:

```mumps
S DHPCSAMP=$G(DHPCSAMP)
```

After redeploying `SYNDHP63` and rerunning `XINDEX`, a new patient imported
successfully:

- patient: `Francesco636 Daugherty69`
- source bundle:
  `FHIR-source-files/tonight-20260315-1773628785/fhir/Francesco636_Daugherty69_26f32ae0-b3d2-fff6-88ee-26c5ac1f697b.json`
- `DFN`: `101090`
- `ICN`: `4263043815V188953`
- graph `IEN`: `15`

Successful `addPatient` response summary:

- encounters loaded: `32`, errors: `2`
- procedures loaded: `94`, errors: `24`
- labs loaded: `102`, errors: `13`
- vitals loaded: `54`, errors: `10`
- conditions loaded: `19`, errors: `9`
- meds loaded: `2`, errors: `6`
- immunizations loaded: `5`, errors: `9`
- care plans loaded: `2`

`GET /fhir?dfn=101090` then returned these resource totals:

- `Patient`: `1`
- `Encounter`: `34`
- `Condition`: `19`
- `Observation`: `156`
- `DiagnosticReport`: `14`
- `MedicationRequest`: `2`
- `Immunization`: `5`
- `Procedure`: `103`

The placeholder-procedure regression check stayed clean on this patient:

- exported placeholder procedures (`6456Q` / `OUTPATIENT ENCOUNTER`): `0`

## Summary

The direct-copy VEHU preparation path that worked was:

1. copy the updated `FHIR` and `SYN` routines into `/home/vehu/p`
2. run `XINDEX`
3. run `EN^SYNGBLLD`
4. confirm `3282K` exists in `^SYN`, file `81`, and Lex
5. confirm `POST addPatient -> wsPostFHIR^SYNFHIR`
6. confirm `http://127.0.0.1:9080/fhir` returns `200`
7. generate a fresh patient locally with Dockerized Synthea
8. `POST` the patient JSON to VEHU from the remote host
