# Panel + replay work plan — 2026-09-13

Work package assembled from the findings in
`PUBLIC_FLEET_COHORT_RECONCILIATION_2026-09-12.md`. Decisions recorded
2026-09-13 PM:

- **fhirprod is being retired** (container at fhir.vistaplex.org; the host
  stays and gets a new WorldVistA container — separate migration effort).
  All fhirprod dedupe/cache items are dropped from this plan.
- **Bundle parity approved**: graph-ON lanes (devfhir, rpmsfhir) should
  materialize panel member Observations like irisfhir does. Big bundles are
  wanted.
- **New experiment**: time continuation-slice processing on irisfhir vs the
  YottaDB lanes (which have gzip configured) to decide whether IRIS needs
  its compression enabled for long downloads.

## Phase 1 — Loader correctness (DONE 2026-09-13, loader commit `5c29c2f`)

1. **Namespace the SYNFPAN loop locals — done.** Rather than hunt the one
   victim, the whole loop state is now SYN-namespaced (`SYNTROOT`,
   `SYNEVAL`, `SYNJSON`, `SYNARGS`, `SYNJLOG`, `SYNSUCC`, ...; formal
   params renamed too — positional, so callers unaffected; leaking
   `DHPLOC` NEWed). CI proof: with a keyed DUZ the loop survived **11
   consecutive successful `LAB^ISIIMP12` filings and processed all 12
   lab-category DiagnosticReports** (pre-fix behavior: died after the
   first filing — iris live run stopped at 2 of 316).
2. **Invalidate the bundle cache on replay — done.** `INVCACHE` in
   `replayIntakeDomains^SYNFHIR` calls `INV^C0FWCAC` (guarded for legacy
   sites). CI proof: cache node `$D` 10 → 0 after each replay.
3. **Rehearsed on a disposable `ci-roundtrip` container — done**, plus two
   findings fixed/filed along the way:
   - **New bug found + fixed: panel reruns were never idempotent.** The
     loop top did `k @jlog`, killing the whole per-entry node *including*
     the `loadstatus="loaded"` marker before the skip check — run 2
     re-accessioned all 11 panels. Now only `log`+`vars` are cleared;
     run 3: `loaded=0`, 11 "already loaded" skips, no new accessions.
   - **C0FW writeback bookkeeping gap (→ Phase 2 item 4b).** The write
     harness's resources are appended to the graph row, but at least one
     write path leaves **no load marker** (entry zx=567: Encounter with
     no marker under any domain family; zx=563 was marked and correctly
     skipped by `C0FWLD`). Replay therefore filed it once more: +1
     Encounter (dup visit) whose CPT/provider explain +1 Procedure and
     +1 Practitioner. All 562 Synthea entries held with zero drift, and
     the second replay was fully idempotent (282=282 resources).

   Deployed 2026-09-13: fhirdev22 (`SYNFHIR`,`SYNFPAN` docker cp+zlink)
   and iris FOIA (`SYNFHIR`,`SYNFPAN` **plus the whole `C0FWLD` guard
   family** `SYNFHIRU/SYNFLAB/SYNFVIT/SYNFIMM/SYNFPRB/SYNFALG/SYNFAPT/
   SYNFPROC/SYNFENC/SYNFMED2/SYNFCP`, which iris had never received —
   all `$SYSTEM.OBJ.Load` sc=1).

## Phase 2 — Finish devfhir HARBER290

4b. **Mark simulation-staged writes — DONE 2026-09-13** (Codex `c4e466d`,
   deployed fleet-wide). Root cause of the Phase-1 dup: the unmarked
   entries were **simulation writes** (`load=0`) — C0FWWRT/C0FWUPD append
   entries with no per-entry marker, so replay filed staged simulation
   data. New `STAGED^C0FWSTAT` marks each staged entry `skipped` (honored
   via `C0FWLD`). The C0FWUPD no-DFN orphan path stays unmarked on
   purpose — replay-with-dfn is the duplicate-SSN recovery flow.
   Proof (fresh ci-roundtrip): 13 harness assertions green; all
   harness-written entries guard=1; replay over loaded+simulation writes
   = zero bundle drift (494=494).
4. Visit-linkage bridge for Procedures (0/737) + CarePlans (0/10):
   `-1^Visit not found` — legacy loaders resolve visits via lowercase
   encounter markers; C0FW stored `visitIen` per entry. Map across.
5. Lab replay with a keyed user — **panels attempted 2026-09-13, halted
   pending item-10 migration.** devfhir keyed DUZ found: 520824660
   (PROVIDER,UNKNOWN SYNTHEA; PMEM guard `ISIIMPU7` deployed first).
   `wsIntakePanels` on HARBER290 (ien 1399, DUZ 520824660): all 316
   entries processed (the Phase-1 loop fix holds at scale), 145 loaded /
   171 errors in ~25s. Key discovery: **the "labs 0/1669" tally was a
   marker artifact — devfhir's early-vintage load DID file individual
   labs** (2,291 CH rows under LRDFN 820 predating this work). So:
   - 170 rejects = `Duplicate Lab Test GLUCOSE...` — LABDUP correctly
     blocking BMP/CMP panels whose members already exist at the exact
     RESULT_DT (+1 APPEARANCE validation reject).
   - The 145 loaded panels (113 UA, 16 CBC, 12 BMP, 4 lipid) created
     **~476 twin rows** where pre-existing individual filings sat at +1s
     offsets LABDUP cannot see — same failure mode as iris DFN 2.
   **Conclusion: no further panel/lab replays on pre-loaded patients
   until the item-10 migration tool exists** (delete individual CH rows,
   refile grouped; rehearse on CI first). HARBER290/devfhir is now a
   second migration rehearsal candidate alongside iris DFN 2.
6. Diagnose conditions (31/160) + immunizations (3/13) blank importer
   statuses (DEBUG-traced replay).
7. Decide whether to replay the rest of the devfhir cohort.

## Phase 3 — Panels in CPRS on iris

File-60 config is done (C0FZPAN: BMP 5091, CMP 5092, COAG 5093, DIFF 5094
+ 60.03 collection samples). Remaining:

8. Per-lane labs-map aliases so members resolve on FOIA: TOT PROT→TOTAL
   PROTEIN, TOT. BIL→BILIRUBIN,TOTAL, ALT→SGPT, ALK PHOS→ALKALINE
   PHOSPHATASE, + UA/CBC drops (NITRITE, LEUCOCYTE ESTERASE, RDW-CV, MPV).
9. Foreground lab rollover on IRIS (`ROLL^C0FZLACC`) scheduled daily (host
   cron → `iris session`); Taskman does not run on IRIS.
10. **Migration** for already-loaded patients: replay duplicates (LABDUP
    only checks the panel's exact RESULT_DT; individual filings sit at +1s
    offsets). Migration = delete individual CH rows, refile through the
    panel path. Rehearse on a VEHU CI container, then iris DFN 2 with CPRS
    visual verify, then the 13-patient cohort.
11. **C0FW panel bridge** so future loads file panels natively: the C0FW
    lab writeback files individuals only. Teach it to file panel-mapped
    DiagnosticReports through ISIIMP12 first, remainder to the individual
    filer.
12. Upstream (coordinate with Sam): LABDUP ±window hardening; push the
    PMEM null-LIEN guard (committed on VistA-DataLoader
    `fix/patient-state-pointer-file5`, unpushed).

## Phase 4 — Read layer

13. **Parity — DONE 2026-09-13.** `GETGRPLAB^C0FHIRLG` (graph-ON path) now
    runs `REFFIX` after `GETGRPDR`, mirroring the graph-OFF path: panel
    result[] refs are repointed to in-bundle Observations or the graph
    Observation is emitted, so every member resolves. Verified:
    - devfhir HARBER290 (101122): demo bundle 634 → **4,525** entries
      (direct build: 5,336 / 4,181 Observations).
    - rpmsfhir dfn 33 (290 panels): → **1,635** entries, members nested.
    - iris unaffected (graph OFF; already materialized).

    **Enabling parity exposed a gateway scaling wall** (fixed in rehmp
    `d79e4bc`): C0RGFHB/C0RGBNC copied or JSON-encoded the FULL bundle
    several times per request — slice-1 on devfhir exceeded the 60s proxy
    limit. Now: skip the full-bundle encode when entry count > 10x
    CHUNKSIZE, merge to ^TMP only when returning whole, build FITCOUNT
    probes as header+first-N, and copy only the header in CHUNK. Deployed
    to fhirdev22, iris, rpmsfhir, vehu10, rpms-rebuild-candidate.
14. **Slice-timing experiment — baseline measured 2026-09-13** (full C0RG
    continuation walk, `Accept-Encoding: gzip`, two passes each, warm
    numbers shown; script rerunnable as `scripts/slice-timing-walk.py <base> <dfn>`):

    | Lane | dfn | Slices | Entries | Total | Mean/slice | p50 | Max | Wire→plain |
    |---|---|---|---|---|---|---|---|---|
    | irisfhir | 2 | 92 | 4,598 | 39.2s | **426ms** | 383ms | 3.3s | 439KiB→5.4MiB (gzip 0.08) |
    | devfhir | 101122 | 13 | 634 | 42.2s | **3,249ms** | 1,906ms | 20.3s | 132KiB→1.3MiB (gzip 0.10) |

    Findings:
    - **IRIS slices are ~5–8x faster than the YottaDB lane**, while
      serving 7x the resources. Per-slice p50: 383ms (iris) vs 1,906ms
      (devfhir).
    - **Both lanes already gzip on the wire** (front proxy): ~10x
      compression. IRIS-native compression is NOT needed for downloads —
      the wire problem is already solved; total transfer for iris's full
      4,598-resource walk is only 439KiB.
    - **devfhir's builder slice costs ~18–20s on every walk** (slice 1 =
      `patient.fhir.bundle`; slices 2+ are 1–2.3s). The C0RG gateway path
      rebuilds rather than hitting the C0FWCAC cache — worth a look when
      touching the gateway (fresh finding, not yet chased).
    - Re-measure after item 13 (parity) makes devfhir bundles comparably
      big; also worth timing rpmsfhir for the third data point.

    **Post-parity re-measurement (2026-09-13 PM, gateway fixes applied,
    equal ~4.5k-entry bundles on iris/devfhir — true apples-to-apples):**

    | Lane | dfn | Slices | Entries | Total | Mean | p50 | Max |
    |---|---|---|---|---|---|---|---|
    | irisfhir | 2 | 92 | 4,598 | 19.7s | 214ms | **193ms** | 1.2s |
    | devfhir | 101122 | 91 | 4,525 | 137.4s | 1,510ms | **1,384ms** | 5.5s |
    | rpmsfhir | 33 | 33 | 1,635 | 24.9s | 755ms | **471ms** | 9.3s (cold build) |

    - **IRIS processes slices ~7x faster than devfhir at identical bundle
      size and slice count.** The gateway fixes also halved iris's own
      slice time (426 → 214ms mean).
    - Full HARBER290 demo load: iris ~20s, devfhir ~2.3min. devfhir's
      per-slice floor (~1.4s) is host/M-platform, not payload: rpmsfhir
      (also YottaDB, different host) runs 471ms/slice.
    - Compression: unchanged conclusion — the proxy gzips ~12x on all
      lanes; IRIS-native compression unnecessary.

## Verification per phase (evidence gate)

| Phase | Rerunnable proof |
|---|---|
| 1 | CI container: replay ×2 + panel loop entry count + cache node check |
| 2 | devfhir dashboard tally row → N/N per domain |
| 3 | iris CPRS labs tab shows grouped panels for DFN 2; ^LR CH counts stable |
| 4 | walk script: slices × latency × bytes table per lane |
