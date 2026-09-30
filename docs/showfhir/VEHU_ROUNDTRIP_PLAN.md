# VEHU round-trip lane — plan

**Date:** 2026-09-30 · **Companion:** `SHOWFHIR_SETUP_2026-09-28.md` · **Scripts:**
`scripts/vehu-install.sh` (shared install), `scripts/ci-vehu-roundtrip.sh` (levels)

Goal: a disposable-container round trip built from stock **`worldvista/vehu:latest`**
(YottaDB r2.06, the image showfhir runs), growing level by level from "it boots" to
"the quality measures line up", each level with a rerunnable pass/fail gate. It
runs beside the existing `ci-roundtrip-local.sh` (`glilly/fhir-dev-server`, r2.00)
until it has been green for a week of nights, then replaces it.

## Principles

1. **One install path.** The container-side half of `showfhir-setup.sh` becomes
   `scripts/vehu-install.sh <container>`. CI calls it against a local container;
   showfhir calls it through Docker's own `DOCKER_HOST=ssh://root@host` transport.
   `showfhir-setup.sh` keeps only host work (Docker, UFW, Caddy/TLS, UI dist).
   Two diverging install paths is how showfhir missed GRAPHLABS and OS5.
2. **No pet-container dependencies.** Everything comes from the image or a repo —
   never `docker cp` out of `Show` or `vehu10`.
3. **Every level has a gate** that writes a row to `docs/ci-reports/VEHU_ROUNDTRIP_<UTC>.md`;
   `--level N` stops after level N.
4. **Provenance in every report:** image digest, `$ZYRELEASE`, and
   `branch@sha(+dirty)` for each repo copied in.

## Levels

| Level | Adds | Gate |
|---|---|---|
| L0 Boot | fresh container from `worldvista/vehu:latest` | boot marker; M answers; `$ZYRELEASE` recorded |
| L1 Web listener | vendored classic M-Web-Server (`vendor/m-web-server`), `^%webhome`, listener with the 11 s stop/go rule, restart hook | `/ping` 200; listener `running`; survives `docker restart` |
| L2 Code install | Codex `src`, C0RG, C0T, SYN (all copies touched); `EN^C0RGSE`, `EN^SYNWEBRG` | `/fhir/metadata` 200; zero stale objects; XINDEX clean on every copied routine |
| L3 Encoder | c0rgenc plugin; `ENCODER` set explicitly | `SMOKE^C0RGFENCT` PATH=PLUGIN; oracle OK |
| L4 Maps + flags | `LOADOS5`, `EN^SYNOS5PT`, `GRAPHLABS=1` | OS5 count; fixed SCT probe list maps; flags read back |
| L5 One patient | golden JOHN-SALT + fixed Synthea seed + random seed | per-domain thresholds; per-type readback parity; strict JSON `/fhir?dfn=`; CFH-WRITE-001 13/13 |
| L6 Cohort | 20 (nightly) → 180 (weekly) from `synthea-1000-20260804` | `harvest-load-errors.py` rates ≥ recorded baseline |
| L7 UI | CPRS demo dist, TJSON browser, rehmp envelopes | `/demos/cprs/` 200 + version = rehmp HEAD; TJSON 200; `rehmp-smoke.sh` |
| L8 Population | C0X deploy, POPIDX | indexed = patients; 6 SPARQL IPP presets; `smoke-quality-host.sh` |
| L9 Quality | CQL re-eval via cds1 under `ENCODER=JSNE` (matches showfhir), DEQM builders | IPP/DENOM/NUMER/DENEX vs golden table; `check-deqm-summary.py` |
| L10 Resilience | restart + reinstall | L1–L5 green after `docker restart`; second install is a no-op; install over L6 data keeps it |

## Decisions (George, 2026-09-30)

- **Encoder:** test **PLUGIN** at L3–L5, then run L9 under **JSNE** to match
  showfhir's live setting — both paths covered every run.
- **cds1:** may be called anytime, unattended, no restrictions (our server).
- **Golden measure table:** use a fixed slice of `synthea-1000-20260804`. After the
  first clean run, **review where the cohorts land in each measure** (is it a useful
  demo set?) before freezing expected counts.

## Findings while building (2026-09-30)

- `worldvista/vehu:latest` ships the **YottaDB Web Server v5 plugin**
  (`_ydbmwebserver.so`, v5.0.0), which renamed the API to `%ydbweb*`. Our code
  needs the classic `%web*` names → vendored M-Web-Server 0.1.4 (byte-identical to
  vehu10's), sha256-guarded by `check-artifacts.sh`.
- Stock VEHU does **not** start a web listener at boot (`/etc/init.d/vehuvista`
  starts TaskMan/Rocto/GUI only).
- `C0FZREPR` (showfhir load-error remediation) exists **only inside the showfhir
  container**, not in any repo, and its current copy has `LABGRAPH` + `CON` but no
  `PRC`/`CSAMP`. `LABGRAPH` relabels Lab errors as graph-retained `loaded`, so
  showfhir's "Lab 100%" is partly a relabel. L6 gates use **honest filing rates**
  measured on the first clean run, not the post-remediation 100%.
- `docker cp` preserves repo mtimes; when those are older than an image's
  compiled `.o`, YDB keeps the stale object (`$T` → `""`). Every install touches
  what it copies.
- Stock VEHU also lacks `%WC` (the cURL web-services client `C0FQUAL` uses to
  reach cds1) → vendored under `vendor/m-wc`.
- The image's `/etc/init.d/vehuvista` already starts `job^%webreq(9080)` when
  `_webreq.m` is in `p/`, so no restart hook is needed (adding one races it).
- **Bug fixed — ISI lab import spins forever** (`src/C0FWLAB.m`, `VALOK`): ISI's
  batch result editor (`V45^ISIIMPL9`) re-prompts endlessly when a value fails the
  #63 input transform (here JOHN-SALT TROPONIN `.05`), pinning a web job at 100%
  CPU. `C0FWLAB` now runs the test's own transform first and keeps a failing value
  graph-retained with an explicit message. This is likely the "MAKELAB hang"
  showfhir papered over with `LABGRAPH`.
- **Bug fixed — VistA output leaking ahead of HTTP headers** (`src/C0FWCTX.m`,
  `src/C0FWDOM.m`): web jobs have no `IO(0)`, so `^%ZISC` sets `IO(0)=$P` (the
  client socket) and later echo output (the `EN^LRDPA` patient display) is written
  to the client before the status line — curl reports "HTTP/0.9" / HTTP 000. It
  appeared whenever a new patient shared a surname with an existing one (11/20 of
  the first cohort). `LOAD^C0FWDOM` now homes `IO`/`IO(0)` on `%webrsp`'s null
  device. Likely also the "test-patient banner I/O hangs %webreq" note.
- **Bug fixed — duplicated JSON tail from `TOJSON^C0FHIRBU`** (`src/C0FHIRBU.m`):
  its encoder choice was `IF … DO ENCODE^C0RGFENC(…)` / `ELSE IF … DO
  ENCODE^C0RGJSNE(…)` / `ELSE DO ENCODE^XLFJSON(…)`. `DO` with arguments does not
  restore `$TEST`, so when the encoder left `$TEST=0` the ELSE lines re-encoded
  into the same array; XLFJSON's different line breaks overwrote lines 1..n-1 and
  the first encoder's last line survived as a duplicated suffix. Data-dependent,
  encoder-independent. It broke cds1 reeval for the two biggest cohorts ("Request
  body must be JSON") and is the same "complete Bundle + duplicated trailing
  suffix" symptom the showfhir notes chased. Four display-only `IF…DO…`/`ELSE`
  pairs remain in `C0FQUAL` (lines ~506–540; HTML lines, low risk) for review.
- JOHN-SALT Lab gaps on stock VEHU (data, not code): INR (#60 5110) has no #60.03
  collection samples; ISI rejects one GLUCOSE `RESULT_DT`. L5 allows `Lab=0.14`
  for JOHN-SALT only, with that reason in the script.
- XINDEX gate: 83–85 F findings are baselined (`scripts/xindex-baseline.tsv`) —
  RPMS-only / optional-module references and YDB `ZY*` commands XINDEX predates.
  The two "Block structure mismatch" hits in vendored `C0TSWS` are an argumentless
  `D` with no dot block — sloppy but harmless.

## Rollout

1. Build `vehu-install.sh` + `ci-vehu-roundtrip.sh` L0–L5; run beside the current lane.
2. After a green week, make it the nightly round trip; retire the r2.00 lane.
3. Nightly adds L6 (20 patients); weekly runs L6 (180) + L7–L9.
4. Rewire `showfhir-setup.sh` to call `vehu-install.sh` via `DOCKER_HOST=ssh://`.
