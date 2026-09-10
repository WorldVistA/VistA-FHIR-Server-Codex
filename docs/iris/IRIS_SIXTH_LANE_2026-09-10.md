# irisfhir wired in as the non-blocking sixth FHIR lane — 2026-09-10

`irisfhir.vistaplex.org` (VistA-on-IRIS, container `iris`, FOIA namespace) now
serves HTTP on port 9080 and is part of the fleet smoke as a **sixth lane that
can never gate the five GT.M servers**.

## The surprise that made this easy

The M-Web-Server needed no porting. On the GT.M fleet it runs behind xinetd +
the `_ydbmwebserver.so` YottaDB plugin, but `%webreq` itself carries a native
Cache/IRIS branch: it opens a `|TCP|<port>` device in `"ACT"` mode and JOBs a
`CHILD` handler per connection. All the key routines (`%webreq`, `%webrsp`,
`%webhome`, `%webapi`, `%webutils`) had already compiled clean during the
routine import. Bring-up was just:

```
D EN^SYNWEBRG        ; register SYN + C0FHIR routes into ^%web(17.6001) — 100 routes
D job^%webreq(9080)  ; JOB the listener (Cache branch)
```

After that, without any further work, IRIS serves the portal (`/`),
`/fhir/metadata` (HTTP 200 — same OperationOutcome body as vehu10, which is the
fleet contract), `/fhir/Patient`, `/fhir-dashboard`, `/fhir-quality-dashboards`
(all six CMS measures listed), and `/fhir-quality-reporting`. Only `/c0x/*` is
absent (the fhir-triple-store is a separate deploy, pointless on a box with an
empty patient file).

## Pieces

| Piece | What it does |
|---|---|
| `scripts/iris-web-setup.sh` | Idempotent bring-up: registers routes, upgrades the host self-heal script, starts the listener, verifies from outside |
| `/opt/iris/ensure-broker.sh` (host) | Now ensures **both** listeners: RPC broker 9430 (CPRS) and web 9080 (FHIR); run by `iris-broker.timer` every 5 min |
| `scripts/iris-lane-smoke.sh` | Right-sized lane smoke: portal, `fhir/metadata`, quality-dashboards measure links, reporting page, broker TCP accept, plus `iris-smoke.sh` session checks |
| `scripts/deploy-quality-all.sh` | `irisfhir` added to default targets; deploy stage runs `iris-web-setup.sh` non-fatally; smoke failure reports `WARN … does not gate` and leaves the exit code untouched |

## Proof (2026-09-10)

- Full fleet smoke: all six lanes green —
  `OK fhirdev / vehu10 / rpms-candidate / rpmsfhir / fhirprod` +
  `OK irisfhir (non-blocking lane)`, exit 0.
- Non-blocking property: forced the IRIS lane to fail (`IRIS_WEB_PORT=9999`) —
  summary showed `WARN irisfhir (non-blocking lane, does not gate)` and the run
  still exited 0 with vehu10 OK.
- Self-heal: `D stop^%webreq` took 9080 down; `/opt/iris/ensure-broker.sh`
  brought it back and `/fhir/metadata` answered HTTP 200.

## Note on the pristine snapshot

The DigitalOcean snapshot `irisfhir-pristine-cprs+fhir-2026-09-09` predates
this work. Restoring it requires re-running `scripts/iris-web-setup.sh` to
re-register routes (`^%web` global) and reinstall the dual-port ensure script.

## Deferred

- Deploy the C0X triple store to IRIS (needs patients first).
- Add a test patient (FileMan stub or Synthea → `/addpatient`).
- Point the Day-2 CI round-trip lane at IRIS as an optional target.
