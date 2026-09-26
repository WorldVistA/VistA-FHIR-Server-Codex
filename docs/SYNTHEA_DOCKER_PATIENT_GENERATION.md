# Synthea Docker patient generation

Use this when the host does not have a configured Java runtime. The workflow runs
the local Synthea checkout inside `eclipse-temurin:17-jdk`, writes FHIR output
back to the mounted checkout, and then posts the generated bundle to a FHIR
intake endpoint.

## Inputs

- Synthea checkout: `/home/glilly/work/vista-stack/synthea`
- Gradle cache: `/home/glilly/work/vista-stack/synthea-gradle-cache-user`
- Gradle project cache: `/home/glilly/work/vista-stack/synthea-gradle-project-cache-user`
- Gradle build directory: `/home/glilly/work/vista-stack/synthea-build-user`
- Java image: `eclipse-temurin:17-jdk`
- Default target: `https://devfhir.vistaplex.org/addpatient?load=1`

## Generate one patient

Pick a unique output directory so each run is easy to inspect:

```bash
cd /home/glilly/work/vista-stack/synthea

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="output_c0fw_java/${RUN_ID}"
mkdir -p "$OUT_DIR"
mkdir -p /home/glilly/work/vista-stack/synthea-gradle-cache-user
mkdir -p /home/glilly/work/vista-stack/synthea-gradle-project-cache-user
mkdir -p /home/glilly/work/vista-stack/synthea-build-user

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e GRADLE_USER_HOME=/gradle-cache \
  -v "$PWD:/work" \
  -v /home/glilly/work/vista-stack/synthea-gradle-cache-user:/gradle-cache \
  -v /home/glilly/work/vista-stack/synthea-gradle-project-cache-user:/project-cache \
  -v /home/glilly/work/vista-stack/synthea-build-user:/work/build \
  -w /work \
  eclipse-temurin:17-jdk \
  sh -lc './gradlew --project-cache-dir /project-cache run -Params="['\''-p'\'','\''1'\'','\''--exporter.baseDirectory=/work/'"${OUT_DIR}"''\'','\''--exporter.fhir.export=true'\'','\''--exporter.fhir.transaction_bundle=true'\'',]"'
```

The generated FHIR bundle should appear under:

```text
/home/glilly/work/vista-stack/synthea/output_c0fw_java/<run-id>/fhir/
```

## Post the patient to devfhir

Use the generated `.json` bundle as the POST body:

```bash
BUNDLE="$(ls -1t /home/glilly/work/vista-stack/synthea/output_c0fw_java/*/fhir/*.json | head -n 1)"

curl -sS -w '\nHTTP %{http_code}\n' \
  -H 'Expect:' \
  -H 'Content-Type: application/json' \
  --data-binary "@${BUNDLE}" \
  'https://devfhir.vistaplex.org/addpatient?load=1'
```

Successful responses include a graph row `ien` and a VistA `dfn`. If `load=1`
is used, C0FW also runs the domain loaders for the bundle.

## Notes

- Use `load=0` when you only want to create/link the patient graph row and defer
  clinical domain loading.
- Add Synthea flags such as `-s <seed>`, `-g M`, `-a 60-65`, or a state/city at
  the end of the `./run_synthea` command when you need a repeatable or targeted
  patient.
- Keep generated output outside Git. The existing Synthea output directories are
  working artifacts, not source.
- If the checkout already has root-owned `.gradle` or `build` directories from
  an older Docker run, keep `--project-cache-dir /project-cache` and the
  `/work/build` bind mount in place rather than changing ownership of the
  checkout.
