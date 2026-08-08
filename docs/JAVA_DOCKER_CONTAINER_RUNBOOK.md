# Java Docker container runbook

Use a Java Docker image when the host does not have a usable JDK or `JAVA_HOME`.
This keeps Java tooling isolated and avoids installing packages on the host.

The image used for Synthea work is:

```bash
eclipse-temurin:17-jdk
```

Synthea currently requires Java 17 or newer, and Java 17 is a conservative LTS
choice for other Java commands in this workspace.

## Run a one-off Java command

```bash
docker run --rm eclipse-temurin:17-jdk java -version
```

## Run Java against a mounted workspace

From the host, mount the project into the container and set the working
directory:

```bash
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  eclipse-temurin:17-jdk \
  java -version
```

## Preserve generated files as the host user

When the command writes files into the mounted checkout, run the container as the
current host user:

```bash
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "$PWD:/work" \
  -w /work \
  eclipse-temurin:17-jdk \
  sh -lc 'java -version'
```

## Use a cache directory for Gradle or Maven

For Gradle builds, mount a host cache and point `GRADLE_USER_HOME` at it. Use
a user-owned cache directory when running the container with `-u`, because an
older root-owned cache can block Gradle wrapper lock files.

```bash
mkdir -p /home/glilly/work/vista-stack/synthea-gradle-cache-user

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e GRADLE_USER_HOME=/gradle-cache \
  -v "$PWD:/work" \
  -v /home/glilly/work/vista-stack/synthea-gradle-cache-user:/gradle-cache \
  -w /work \
  eclipse-temurin:17-jdk \
  ./gradlew --project-cache-dir /gradle-cache/project-cache --version
```

For Maven, use the same pattern with `/root/.m2` or a custom `MAVEN_CONFIG`
directory if the project expects one.

## Troubleshooting

- If generated files are owned by `root`, rerun with `-u "$(id -u):$(id -g)"`.
- If Gradle reports permission denied for a `.lck` file, switch to a new
  user-owned cache directory or fix ownership on the existing cache.
- If Gradle reports permission denied under the mounted project's `.gradle`
  directory, pass `--project-cache-dir /gradle-cache/project-cache`.
- If Gradle redownloads dependencies each run, verify `GRADLE_USER_HOME` points
  at a mounted host directory.
- If the project script says `JAVA_HOME` is missing on the host, make sure the
  script is being run inside the container rather than before `docker run`.
