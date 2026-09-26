# CPRS on VistA-on-IRIS (irisfhir.vistaplex.org) — 2026-09-09

CPRS (the VA's Windows GUI chart) now connects to the ported VistA running on
InterSystems IRIS Community Edition, through the standard VistA RPC Broker on
**TCP 9430**. This closes the loop on the IRIS portability audit: the same FOIA
VistA database that serves FHIR through our product routines also serves a
real, unmodified CPRS client.

## Connect from Windows

1. Client: `CPRS1_33_109_1` (or `CPRS1_32_515_2`) — the downloaded VA CPRS GUI.
2. When CPRS starts, it shows the **Connect To** dialog (or run
   `CPRSChart.exe s=irisfhir.vistaplex.org p=9430`). If the dialog does not
   appear, hold **Shift** while launching to force it.
   - **Server / Address:** `irisfhir.vistaplex.org`
   - **Port:** `9430`
3. Sign on:
   - **Access Code:** `USER.1`
   - **Verify Code:** `VISTA.99`

That account (USER,ONE, DUZ 1) has the ORES / PROVIDER / XUPROGMODE keys and the
`OR CPRS GUI CHART` option, so it reaches the chart. The verify code does not
expire and multiple sign-on is allowed, so reconnects don't collide.

> This is a demo/test account on a demo dataset (FOIA VistA). Not for real PHI.

## What makes it work (server side)

The RPC Broker needs pieces a headless FHIR server does not. `iris-cprs-setup.sh`
performs all of it and is idempotent:

1. **Kernel `%`-routines mapped into FOIA.** The broker calls `HOME^%ZIS`
   (device handler), `%ZTLOAD` (TaskMan), `%ZOSV` (OS layer) and listens via
   `%ZISTCPS`. In this FOIA extract those Kernel routines are compiled under the
   FOIA routine database, so a single `Routine_%Z*->FOIA` mapping resolves them.
   (They are *not* in the base IRIS `%SYS`/IRISLIB, and are absent from the old
   manager DB and old `irislib` extract — this mapping is the fix.)
2. **A listener on 9430**, started with
   `J LISTEN^%ZISTCPS(9430,"NT^XWBTCPM")` and kept up by a self-healing systemd
   timer on the host (`iris-broker.timer` → `/opt/iris/ensure-broker.sh`). The
   listener is a JOB'd process that dies with the container, so it is
   re-established on every (re)start; `STRT^XWBTCP` / `LISTEN^%ZISTCPS` are
   semaphore-guarded, so re-running is a safe no-op.
3. **A sign-on account** (see above), created directly in file 200.

Docker publishes `-p 9430:9430`; the setup script `iris-host-setup.sh` should
include that port on the `docker run` line for a fresh host.

## Verifying without CPRS

The broker handshake and sign-on can be exercised from any host with Python.
The client encrypts the Access;Verify pair with the server's cipher pad (the
`Z` table in `XUSRB1`, fetched at runtime by real CPRS). A minimal round trip:
`TCPConnect` → `XUS SIGNON SETUP` → `XUS AV CODE` with the encrypted
`USER.1;VISTA.99` returns `DUZ=1, signon=0, vcchg=0` (clean login). See the
sprint transcript for the reference probe.

## Troubleshooting

- **`<NOROUTINE> ... *%ZIS`** on `STRT^XWBTCP`: the `%Z*` routine mapping is
  missing — re-run step 1 of `iris-cprs-setup.sh`.
- **`<NOROUTINE> EVAL+6^%ZTLOAD1 *%RCR`** (seen via `ORWTIU START` at CPRS
  startup): TaskMan's `%ZTLOAD1` copies the task's saved-variable array with
  `%XY^%RCR`, and `%RCR` isn't a `%Z*` routine, so it needs its own mapping
  (`Routine_%RCR→FOIA`). FOIA has exactly 85 `%`-routines (`%DT %DTC %RCR
  %XUCI %ZIS* %ZOSV* %ZT* %web*`) — all covered by the mappings in step 1 plus
  the host-setup `%DT/%DTC/%XUCI/%web*`. Do **not** blanket-map `%*→FOIA`: base
  IRIS `%`-routines live in IRISLIB and would be shadowed.
- **"Not a valid ACCESS CODE/VERIFY CODE pair"**: the client and server RPC
  Broker cipher pads disagree, so the encrypted Access;Verify string decrypts to
  garbage. This FOIA extract shipped a **non-standard pad** in `XUSRB1` (the
  `Z` table), while a stock CPRS uses the canonical pad baked into the client
  (`XWBHash.pas`). Fix: import the canonical pad —
  `src/iris-kernel/XUSRB1.mac` (regenerate with
  `scripts/gen-xusrb1-stdpad.py`), applied automatically by step 1b of
  `iris-cprs-setup.sh`. Diagnosed by capturing a real handshake with
  `XWBDEBUG=3` (`^XTMP("XWBLOG"_$J)`): the client's bytes decode to the
  plaintext A/V only under the canonical pad, never under the shipped `Z` pad.
- **"MULTIPLE SIGNONS NOT ALLOWED"**: a stale signed-on flag
  (`^VA(200,1,1.1)` piece 3) — cleared by the bootstrap; multiple sign-on is
  enabled (`^VA(200,1,200)` piece 4 = 1) so it should not recur.
- **"VERIFY CODE must be changed"**: VC-never-expires (`^VA(200,1,0)` piece 8)
  is set by the bootstrap to avoid the first-login change prompt.
- **"Server/Client Incompatibility ... running server version is X"**: CPRS
  calls `ORWU VERSRV`, which returns the version string from the
  `OR CPRS GUI CHART` option (`^DIC(19,ien,0)` piece 2 =
  `CPRSChart version N.N.N.N`). If the server version differs from the client
  exe's required version and the division isn't the default, the GUI
  hard-blocks. Fix: set that option's version to the client build (step 3b of
  `iris-cprs-setup.sh`, `CPRS_VER`). This FOIA image shipped `1.33.112.1`; the
  client here is `1.33.109.1`.
