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

## First patient: the full Synthea round trip runs on IRIS (same day)

POSTed the standard read-parity fixture
(`FHIR-source-files/Aaron697_Marquardt819_*.json`, 1,016-entry Synthea Bundle,
1.8 MB) to `/addpatient` — **HTTP 201 in 1.7 s**, and the whole VistA clinical
filing stack ran on IRIS: Patient filed by FileMan (DFN 1,
`MARQUARDT819,AARON697`, ICN assigned), 13/13 Encounters through `DATA2PCE`,
122 vitals through `GMVDCSAV`, 7 Immunizations, 16/20 Conditions (4 ICD-10
resolution errors), 686 labs retained in fhir-intake, smoking health factors
filed. Skips are the un-ported loader-repo routines (`SYNFHF`, `SYNFMED`,
`SYNDHP65`) — same as any Codex-only box.

Read side: `GET /fhir?dfn=1` generated a live 178-entry Bundle in 0.4 s;
`GET /fhir/Patient/1` and `GET /fhir/Condition?patient=1` (30 hits) serve from
the warmed cache. The lane smoke now asserts this round trip.

And the closing shot: **CPRS 1.33.109.1 shows `Marquardt819,Aaron697` in
Patient Selection** on irisfhir (screenshot, 2026-09-10 2:51 PM) — the patient
loaded over FHIR is served to a stock CPRS client over the RPC broker from the
same IRIS globals. FHIR write → FileMan → CPRS read, one server, no middle
tier.

Rerunnable evidence:

```
curl -X POST -H 'Content-Type: application/json' -H 'Expect:' \
  --data-binary @FHIR-source-files/Aaron697_Marquardt819_*.json \
  http://irisfhir.vistaplex.org:9080/addpatient
curl http://irisfhir.vistaplex.org:9080/fhir?dfn=1
```

### Two port bugs found on the way

- **`$TEST` bleed in `SYNWEBRG` LOADDEF** (fixed in `src/SYNWEBRG.m`): the
  `IF $T(handler)'="" DO addService(...) / E DO addService(fallback)` pairs
  relied on `$TEST` surviving a parameterized `DO` — it doesn't. The last
  internal `IF` in `addService^%webutils` is `$P($SY,",")=47` ("am I GT.M"),
  so on GT.M `$TEST` came back 1 (else never fired, by luck) and on IRIS it
  came back 0, making the fallback overwrite the correct route — `addpatient`
  pointed at the absent `wsPostFHIR^SYNFHIR`. Now uses `$SELECT` into a
  variable. vehu10 full deploy + 30-check smoke green after the change.
- **`Expect: 100-continue` handshake garbled on the IRIS listener**: curl's
  default for large POST bodies; the M-Web-Server's `100 Continue` reply comes
  out malformed on the IRIS TCP device and curl aborts ("Received HTTP/0.9").
  Workaround: send `-H 'Expect:'`. Worth a look in `%webreq` someday.

## Deferred

- Deploy the C0X triple store to IRIS.
- Chase the 4 Condition ICD-10 resolution errors from the Aaron697 load.
- Fix the `100 Continue` reply on the IRIS device path in `%webreq`.
- Point the Day-2 CI round-trip lane at IRIS as an optional target.
