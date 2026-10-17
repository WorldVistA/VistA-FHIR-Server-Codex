# native.vistaplex.org — YottaDB on the metal

**Date:** 2026-10-16
**Host:** `native.vistaplex.org` (`161.35.53.219`)
**Script:** `scripts/native-ydb-setup.sh`

This host is the bare-metal lane for performance comparisons: native YottaDB against iris2, and against the Docker lanes devfhir (r2.00) and showfhir (r2.06). It is not a fleet deploy target. The unmerged indirection build stays here. The 2026-10-17 numbers are in the Comparisons section below and in `JSON-with-Mumps/docs/YDB1278_INDIRECTION_EVAL_2026-10-16.md`.

## What is on the machine today

Inspected 2026-10-16, before any install:

| | |
|---|---|
| Name | `native-yottadb-metal-rocky-linux-s-2vcpu-4gb-120gb-intel-nyc1` |
| OS | Rocky Linux 9.8, x86_64 |
| CPU / RAM / disk | 2 vCPU, 3.6 GiB, 119 GB (2 GB used) |
| Listening | ssh/22, rpcbind/111 |
| Installed | no Docker, no YottaDB, no Caddy, no `vehu` user |

SSH: `root@native.vistaplex.org` with the workstation key.

## Which YottaDB

The bench container `ydb1278-bench` is Ubuntu 24.04, ICU 74. This host is Rocky 9, ICU 67. Those binaries do not load here. The script compiles on the host.

Default source, the build measured in `JSON-with-Mumps/docs/YDB1278_INDIRECTION_EVAL_2026-10-16.md`:

| | |
|---|---|
| URL | `https://gitlab.com/nars1/YDB.git` |
| Branch | `indrfast_ydb1278` |
| Commit | `80f2b92d29f14234eabb89b81b1c089b28facc31` |
| Install | `/opt/yottadb/native/yottadb_r207` |

`NATIVE_YDB_URL`, `NATIVE_YDB_REF`, and `NATIVE_YDB_COMMIT` override that. An empty `NATIVE_YDB_COMMIT` follows the branch tip. A second tree (upstream master, for an A/B on this same box) uses another prefix, for example `NATIVE_YDB_PREFIX=/opt/yottadb/master`.

showfhir, vehu10, fhirdev, and wvehr keep their released YottaDB. This script refuses those hostnames.

## Where the VEHU data comes from

Stock `worldvista/vehu:latest`, not the live showfhir database and not a local CI container. Both of those already have Synthea patients and our routines on top of VEHU.

The image is YottaDB r2.06. Its `vehu.dat` is 864,216 blocks of 4096 bytes with 1,166 free: about 3.4 GB of real globals. An r2.06 database file does not open under the r2.07 build. The script runs `mupip extract -format=zwr` inside a one-shot container on the workstation, copies the extract to the host, creates a new global directory, and `mupip load`s it.

| Region | File in the image | Loaded |
|---|---|---|
| DEFAULT | `/home/vehu/g/vehu.dat` (record 16368, key 1019) | yes |
| AIM | `aim.dat` | yes |
| OCTO | `octo.dat` | yes |
| TEMP | `temp.dat` (`XTMP`, `CacheTemp*`, …) | empty region only |

Routines are the `.m` files from `/home/vehu/r` (39,666 of them). Object files stay behind. The new YottaDB compiles them on first use. Our tree is copied into `/home/vehu/p`, which is first on `ydb_routines`, the same order as `scripts/vehu-install.sh`.

Docker on the workstation is only how the image is read. The host never runs Docker.

## Parity with showfhir

After `install` and `caddy`, the stack matches the live showfhir lane:

| | showfhir | native |
|---|---|---|
| Encoder | `C0RG ENCODER=JSNE` | same |
| Graph labs | `^C0FHIR("EXPERIMENT","GRAPHLABS")=1` | same |
| Routines | Codex + C0RG + SYN + C0T + C0X + vendored web | same set, via this script |
| Plugin | `libc0rgenc.so` built in the guest | rebuilt against this `ydb_dist` |
| HTTP | Caddy → `127.0.0.1:9080` | same routes, domain `native.vistaplex.org` |
| Listener | `job^%webreq(9080)` from the image init | systemd `vehu-webreq.service` |

Journals stay off. showfhir journals DEFAULT, AIM, and OCTO. A journal flush would show up in the timings this host is for.

Population (180 Synthea, JOHN-SALT, the common cohort) is the same step as `SHOWFHIR_LOAD=1` in `scripts/showfhir-setup.sh`. It is off until `NATIVE_LOAD=1`. The loaded database is then stock VEHU plus our parameters, which is the baseline for a native-versus-iris run. Run the population step when the comparison should include showfhir's patients.

FileMan needs the image's null-subscript settings. `/home/vehu/etc/env` sets `ydb_lct_stdnull=1` and `ydb_lvnullsubs=2`.

## Memory

3.6 GiB of RAM and a 3.4 GB region. The script adds a 4 GB swap file before the compile and before the load, and it builds with `-j2`. Release builds link with LTO. If the compile is killed, the swap file is the first thing to check. If the load is killed, delete `/home/vehu/g/*.dat` and rerun the `load` phase. A partial database is not resumed.

The workstation needs room under `NATIVE_EXTRACT_DIR` (default `/tmp/native-vehu-extract`) for the ZWR files. Expect several gigabytes.

## Run it

From `VistA-FHIR-Server-Codex`:

```bash
scripts/native-ydb-setup.sh host
scripts/native-ydb-setup.sh build
scripts/native-ydb-setup.sh extract
scripts/native-ydb-setup.sh load
scripts/native-ydb-setup.sh install
scripts/native-ydb-setup.sh caddy
scripts/native-ydb-setup.sh smoke
```

`scripts/native-ydb-setup.sh all` is those seven in order. Each phase can be repeated. `load` refuses to overwrite an existing `vehu.dat` unless `NATIVE_LOAD_FORCE=1`. `build` skips a tree that already reports `NATIVE_YDB_COMMIT` unless `NATIVE_YDB_REBUILD=1`.

Smoke is `https://native.vistaplex.org/fhir/metadata` returning 200, `$ZYRELEASE` containing the commit's release, and `ENCODER=JSNE`.

## Comparisons

Run 2026-10-17. Same 1,500-entry Bundle, same djb2 `1316296645`. The write-up, including the container master-versus-patch pair and the fuzzer, is `JSON-with-Mumps/docs/YDB1278_INDIRECTION_EVAL_2026-10-16.md`. Logs are in that repo under `exploratory/2026-10-16-ydb1278/`.

| Question | Result |
|---|---|
| Does !1944 hold here, with Kernel and the VEHU database open? | Yes. Unique-name indirection 234 ns/call, encode 94 ms, `FUZZ OK`. String pool 332,232, against about 963,000 on unpatched showfhir. |
| Native versus IRIS | iris2 encodes the same Bundle in 58 ms. Unique-name indirection 152 ns/call. The merge request does not apply to IRIS. |
| Native versus Docker YottaDB | devfhir r2.00 encodes it in 500 ms (3,177 ns/call). showfhir r2.06 encodes it in 569 ms (4,727 ns/call). |

Listeners stayed up and `ENCODER` stayed `JSNE`. A checksum mismatch stops the comparison.
