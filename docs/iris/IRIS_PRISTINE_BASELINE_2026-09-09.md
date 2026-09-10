# irisfhir pristine baseline — 2026-09-09

A "come back to" snapshot point for `irisfhir.vistaplex.org`: VistA-on-IRIS
that is **both FHIR-ready and CPRS-ready**, with all bring-up fixes applied and
**no patient data yet** (file 2 empty) — a clean demo base.

**Snapshot captured:** DigitalOcean droplet snapshot
`irisfhir-pristine-cprs+fhir-2026-09-09` (14.79 GB, region NYC1, 2026-09-09;
created from droplet `iris-docker-s-2vcpu-4gb-120gb-intel`).
Droplet spec: 2 vCPU / 4 GB / 120 GB (within IRIS Community's ≤8-core limit).
Taken live; on restore IRIS does a brief automatic journal recovery and the
`iris-broker.timer` re-establishes the 9430 listener within ~45s. Health at
capture: `iris-smoke` 5/5 and broker sign-on `DUZ=1`.

## Host / container

- Host: `irisfhir.vistaplex.org` (Ubuntu Docker host, root).
- Image: `containers.intersystems.com/intersystems/iris-community:latest-em`
  → `IRIS for UNIX 2026.1 (Build 234U)`, Community Edition.
- Container `iris`, `--restart unless-stopped`, `--cpus 2`.
- Published ports: `1972` (superserver), `52773` (mgmt portal), `9080`
  (M-Web-Server), `9430` (VistA RPC Broker for CPRS).
- Durable config: `ISC_DATA_DIRECTORY=/durable/iris` (host `/opt/iris/durable`,
  ~221M). Databases on host `/opt/iris/data` (~5.2G).

## Databases & namespace

- `FOIA` database = `/data/foia` (the 4.5G FOIA VistA: DD + FileMan +
  application routines + Kernel + RPC Broker + M-Web-Server).
- `OLDSYS` database = `/data/sys` (old manager DB, reference only).
- Namespace `FOIA`: Globals→FOIA, Routines→FOIA, Library→IRISLIB.

## Routine mappings into FOIA (the load-bearing ones)

- Routines: `%`, `%DT`, `%DTC`, `%XUCI`, `%web*`, `%C0*`, `%Z*`, `%RCR`.
  (`%Z*` = Kernel device/TaskMan/OS layer; `%RCR` = TaskMan var-array copy;
  `%web*` = M-Web-Server; `%C0*` = our FHIR product; FileMan `%DT/%DTC`.)
  FOIA holds 85 `%`-routines total, all covered by the above.
- Globals→FOIA: `%Serenj*`, `%Z*`, `%ut*`.
- Globals→IRISTEMP: `HLTMP`, `TMP`, `UTILITY`, `XTMP`, `XUTL`.

## CPRS enablement (all applied, all reproducible)

1. RPC Broker listener on 9430: `LISTEN^%ZISTCPS(9430,"NT^XWBTCPM")`, kept up by
   the host `iris-broker.timer` systemd unit (enabled).
2. Canonical RPC Broker cipher pad restored in `XUSRB1` (image shipped a
   non-standard `Z` pad). Source: `src/iris-kernel/XUSRB1.mac`.
3. `OR CPRS GUI CHART` option version set to `1.33.109.1`
   (`^DIC(19,8552,0)` piece 2) to match the `CPRS1_33_109_1` client.
4. Sign-on account `USER,ONE` (DUZ 1): Access `USER.1`, Verify `VISTA.99`,
   keys ORES/PROVIDER/XUPROGMODE, `OR CPRS GUI CHART` secondary menu,
   VC-never-expires, multiple sign-on allowed.

Verified: stock `CPRS1_33_109_1` reaches the Patient Selection screen.
`XWBDEBUG` is **off** in this baseline.

## Reproduce from scratch

`scripts/iris-host-setup.sh` (namespace + mappings + product/M-Web-Server) →
`scripts/iris-cprs-setup.sh` (Kernel `%Z*`/`%RCR` map, `XUSRB1` pad, account,
listener + durability, `CPRS_VER` alignment) → `scripts/iris-smoke.sh` (5/5).

## What is deliberately NOT in this baseline

- No patients (file 2 empty). Add a FileMan stub, or load via the Synthea →
  `/addpatient` pipeline once IRIS is wired into the FHIR lane.
- IRIS not yet a FHIR fleet lane (still the five GT.M servers + this host).
  **Update 2026-09-10:** the sixth lane landed the day after this snapshot —
  web routes in `^%web(17.6001)` + the 9080 listener + the dual-port ensure
  script are NOT in this image. After restoring, re-run
  `scripts/iris-web-setup.sh` (see `IRIS_SIXTH_LANE_2026-09-10.md`).

## Taking the snapshot consistently

IRIS caches writes; for a clean disk/VM snapshot of a *running* instance, use an
external freeze so the on-disk image is transaction-consistent:

```
# quiesce writes (returns quickly; reads continue, writes queue)
docker exec iris iris session IRIS -U %SYS \
  "##class(Backup.General).ExternalFreeze()"
# ... take the VM/disk snapshot now ...
docker exec iris iris session IRIS -U %SYS \
  "##class(Backup.General).ExternalThaw()"
```

A live snapshot without the freeze is still crash-consistent (IRIS recovers
from the WIJ/journal on restart), but the freeze/thaw guarantees a clean image.
