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

## `showfhir`, `tfhir`, `gtree`, and `vpr` Web Services

Servers may or may not have the routines installed that implement these web services (e.g. SYNFHIR, SYNVPR, C0FHIRWS). When they do, the web service interface is configured by registering routes with `addService^%webutils`; the portal at `/` (e.g. `http://localhost:9081/`) lists what is currently registered in `^%web(17.6001)`. Some sites (e.g. vehu9) do not have these routes registered by default.

**Two different endpoints and routines:** Do **not** change **`showfhir`**. Keep it registered to **`wsShow^SYNFHIR`** only. Add **`tfhir`** separately, registered to **`wsShow^C0FHIR`** only. They are **not** interchangeable paths to the same M tag.

**showfhir** → **`wsShow^SYNFHIR`** (routine **`SYNFHIR`**; not in this repo). Stored Synthea JSON by **`ien`** / **`icn`** / **`dfn`**. URI pattern **`showfhir`** (no `/*`).

```text
d addService^%webutils("GET","showfhir","wsShow^SYNFHIR")
```

**tfhir** → **`wsShow^C0FHIR`** (in-repo). **`wsShow^C0FHIR`** calls **`wsShow^SYNFHIR`** so the JSON comes from the same graph-store path as **`showfhir`**; **`FILTER("format")`** is removed before that call so **`SYNFHIR`** does not see **`tjson`**. If **`format=tjson`**, **`C0FHIR`** runs **`tjson^%wd`** on the **`OUT`** line array, wraps the TJSON in **`&lt;html&gt;&lt;pre&gt;` … `&lt;/pre&gt;&lt;/html&gt;`**, and sets **`text/html; charset=utf-8`**. If **`SYNFHIR`** is missing (rare), **`WSSHOWFB^C0FHIR`** uses the older **`$$GSROOT^C0FHIR`** / **`encode^SYNJSON`** / **`TOJSON^C0FHIRBU`** path. URI pattern **`tfhir`** (no `/*`).

```text
d addService^%webutils("GET","tfhir","wsShow^C0FHIR")
```

**In-repo shortcut:** after **`ZLINK`** current **`C0FHIR.m`**, run **`D REGTFHIR^C0FHIR`** (same registration; removes **`GET tfhir/*`** if present). Convenience script: **`~/ops/scripts/register-tfhir-route.sh`** (use **`HOST=local`** for Docker container **`fhir`**).

The in-repo FHIR index (**`FHIRIDX^C0FHIR`**) links the “Synthea Json” column to **`/tfhir?ien=…`** so the portal uses the **C0FHIR** implementation.

**TJSON:** only on **`tfhir`** with **`wsShow^C0FHIR`**: **`FILTER("format")="tjson"`** → **`text/html; charset=utf-8`** with **`&lt;html&gt;&lt;pre&gt;` … `&lt;/pre&gt;&lt;/html&gt;`** around the TJSON. Example: **`/tfhir?ien=…&format=tjson`**.

If **`tfhir`** was registered wrong (e.g. `tfhir/*` or pointed at **`SYNFHIR`**), fix **`tfhir`** only — leave **`showfhir`** → **`SYNFHIR`** unchanged:

```text
d deleteService^%webutils("GET","tfhir/*")
d addService^%webutils("GET","tfhir","wsShow^C0FHIR")
```

**Test after adding `tfhir`** (replace host/port and **`ien`**). **`showfhir`** = **`SYNFHIR`**; **`tfhir`** = **`C0FHIR`** (404 until **`tfhir`** is registered):

```bash
curl -sS -o /dev/null -w "showfhir(SYNFHIR) %{http_code}\n" "http://fhir.vistaplex.org:9080/showfhir?ien=1534"
curl -sS -o /dev/null -w "tfhir(C0FHIR)     %{http_code}\n" "http://fhir.vistaplex.org:9080/tfhir?ien=1534"
```

**`format=tjson`** applies only to **`tfhir`** (**`C0FHIR`**). Expect **`Content-Type: text/html; charset=utf-8`**:

```bash
curl -sS -D - "http://fhir.vistaplex.org:9080/tfhir?ien=1534&format=tjson" -o /dev/null | head -5
```

**gtree** (graph-store tree view; used for load log and JSON tree links):

```text
d addService^%webutils("GET","gtree/{root}","wsGtree^SYNVPR")
```

**vpr** (VPR patient data by DFN; only register when VPR is available on the system):

```text
d addService^%webutils("GET","vpr","wsVPR^SYNVPR")
```

After adding services, the listener may need to be restarted or the process may pick up new routes on the next request depending on the web stack.

**When a route is not registered**, requests like `GET /tfhir?ien=6` or `GET /gtree/SYNGRAPH(2002.801,2,6,%22load%22)` can fall through to a static file handler and return a 404 with an error such as:

- `DEVOPENFAIL` / `Error opening /home/vehu/www/tfhir` (or `.../gtree/...`) / `No such file or directory`

That indicates the route is not defined; register the service(s) above and restart the listener.

## Web Listener Smoke Check

**Every `docker restart` of the FHIR/VistA container:** restart the M listener (**`%webreq`**); it often does not come back on its own. Canonical copy: **`~/ops/agent-context/vista-container-developer-guide.md`** §10 (same commands as below).

In **`mumps -direct`** (as the container’s VistA user):

```text
d stop^%webreq
d go^%webreq
```

Quick check: `zwr ^%webhttp(0,"listener")` → `"running"`.

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
