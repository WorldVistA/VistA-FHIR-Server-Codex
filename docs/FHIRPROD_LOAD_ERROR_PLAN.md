# fhir.vistaplex.org patient-load errors — plan and protocol

Status date: 2026-09-09

This is the working plan for the load failures visible on
`https://fhir.vistaplex.org/fhir` (Load Log column → `/gtree/.../"load"`).
Evidence is from the live dashboards on fhirprod, fhirdev, and rpmsfhir,
plus two full fhirprod load trees (DFN 1661 Colton / IEN 1666 and DFN 1643
Adam / IEN 1648) and host probes of `^SYN("2002.030","sct2os5")` and file 81.

## What “Bad Request” means

`POST /addpatient` returns **HTTP 400** when the body is empty or is not a
FHIR Bundle with an `entry` array (`C0FWADD`). That is a request-shape
error, not a clinical-domain load error.

A malformed JSON body currently **crashes XLFJSON** (`SETBOOL+11^XLFJSOND`,
null subscript) and returns **HTTP 500**, even though `C0FWADD` intends 400.
That is a shared decoder-hardening item, not fhirprod-specific.

Large Synthea bundles that a browser or proxy rejects as “400 Bad Request”
are usually Caddy/body-size or `Expect: 100-continue` issues. Use
`curl -H 'Expect:' --data-binary @bundle.json`.

## How to read the dashboard numbers

`DOMSUM^C0FHIR` counts only `loadStatus=loaded`. **skipped** and
**not_implemented** look like failures in `loaded/source`.

On fhirprod DocumentReference, many rows are `skipped` / “TIU note already
matched” — the note exists; the fraction is not a TIU outage. fhirdev’s
same patients show ~99% `loaded` because those notes were filed on first
pass.

Two naming generations appear on the same page:

| Style | Loader | Typical DFNs on fhirprod |
|---|---|---|
| `encounters`, `labs`, `meds`, `procedures` | Legacy SYN | older mixed rows (~1442) |
| `Encounter`, `Lab`, `Medication`, `Procedure` | C0FW | recent Synthea cohort **1643–1661** |

Compare C0FW-to-C0FW, not mixed SYN leftovers.

## Host comparison (C0FW domains)

| Domain | fhirprod C0FW | fhirdev C0FW | rpmsfhir C0FW | Scope |
|---|---:|---:|---:|---|
| Patient | 100% | 100% | 100% | OK everywhere |
| Smoking | 100% | 100% (tiny n) | 0% (RPMS deferred) | RPMS adapter gap |
| Observation (vitals) | **100%** | 86% | 84% | Day 2: skipped BMI counts as success |
| Encounter | 75% | 56% | 50% | Shared; fhirdev/RPMS worse |
| DocumentReference | **100%** | 99% | 99.6% | Day 2: skipped “already matched” counts |
| Condition | **89%** | 35% | 50% | Day 2 skip social findings; leftover true ICD gaps |
| Immunization | **86%** | 31% | 89% | Day 2 skip missing CVX / already-filed |
| Lab | **100%** | 17% | 3.7% (graph-of-record) | Day 1 replay + PTT round |
| Procedure | **99.4%** | 6.8% | **85%** | fhirprod OS5 + imaging allowlist |
| Medication | 0% | 0% | 0% | Shared stub `C0FWMED` |
| CarePlan | 0% | 0% | 0% | Shared stub `C0FWCP` |

fhirdev’s matching showcase patients (SCHMELER, GUSIKOWSKI, …) were loaded
with **older C0FW stubs** (`Procedure filing requires a C0FW PCE adapter`).
Later fhirdev patients (e.g. DFN 101123–101127) file procedures at 96–98%.
So fhirdev is not “healthy procedures” for the shared cohort; RPMS is.

## What is unique to fhir.vistaplex.org

### 1. OS5 codes exist in `^SYN` but not in file 81 (confirmed)

| Check | fhirprod | fhirdev |
|---|---|---|
| `$$COUNT^SYNOS5LD` | 1041 | 1041 |
| `sct2os5` inverse codes | 1041 | 1041 |
| Those codes missing from `^ICPT` (#81) | **951** | **0** |
| `0583H` (mammography OS5) in #81 | missing | IEN 200000155 |
| `3048M` (depression-screen OS5) in #81 | missing | IEN 200000382 |
| `EN^SYNOS5PT` run? | no (or failed) | yes |

`PRCADD^SYNDHP65` maps SCT→OS5, then `DATA2PCE^PXAI` fails because the OS5
code is not in CPT. Load log: `PRCADD failed: -1` (526 of 804 procedure
errors on Colton) and `Code <sct> not mapped` for SCTs outside the 1041-map.

RPMS stays at 85% because `C0FWPRC` `ENSURECPT` seeds #81 on the fly.

**Fix:** `D EN^SYNOS5PT` on fhirprod, then replay procedures. Also make the
VEHU path call `ENSURECPT` before `PRCADD` so a missed seed cannot recur.

### 2. Urine / UA lab dictionary is thinner than fhirdev

On fhirprod, `URINE GLUCOSE` (#60 IEN 148) has **no** collection sample
(`60.03`) and **no** accession area (`60.11`). fhirdev has accession but
still no collection sample. Chemistry tests (A1C, glucose, creatinine,
cholesterol) already have both on fhirprod.

Load log: `Couldn't locate COLLECTION SAMPLE (#60.03)` (540 on Colton).

### 3. Stale C0FWCON V POV FileMan fields

`Problem saving RPMS V POV: File #9000010.07 does not contain a field N`
appears on WorldVistA fhirprod (RPMS detect is **false**). The message
string says “RPMS” but `ADDPOV^C0FWCON` is using VistA FileMan fields that
this DD does not have. Shared code; surfaces more on fhirprod’s C0FW loads.

## What is shared across every C0FW load

These are **not** fhirprod configuration. They will recur on vehu10,
fhirdev, and any new VistA host.

1. **Medication 0%** — `C0FWMED` is a placeholder; no `SYNFMED` call.
2. **CarePlan 0%** — `C0FWCP` is a placeholder.
3. **DiagnosticReport panels** — `C0FWLAB` marks them `not_implemented`
   (540 on Colton). Atomic Observations are the filing path.
4. **Urine set-of-codes** — Synthea `negative` / `cloud` / etc. fail VistA
   #60 answer lists (`Choose from: Neg. NEG Trace…`, length limits).
5. **Unmapped LOINCs** — PHQ (`44261-6`, `93025-5`), mammography
   (`24623002` side), USCDI screens (`34533-0`, `32167-9`, `55758-7`,
   `75626-2`, `70274-6`). Keep graph-of-record rather than hard-fail
   (partially already in `C0FWLAB`).
6. **Condition findings treated as diagnoses** — `Medication review due`,
   employment, education, housing, IPV. No ICD-10; should **skip**, not
   error.
7. **BMI vital skipped** — `39156-5` not in `C0FWVIT` map.
8. **Immunization CVX** — missing or inactive in `^AUTTIMM` on VistA;
   RPMS file is richer.
9. **`LABADD` empty status** — ISI/lab package returns `""` (720 on
   Colton). Needs a real RETSTA from `SYNDHP63` plus accession setup.
10. **True SCT gaps in `sct2os5`** — e.g. `428211000124100`,
    `430193006`, `763302001`. Map regeneration, not #81 seed.

Legacy SYN rows on fhirprod (`meds` 54%, `procedures` 64%, `labs` 33%)
show the old importer was strictly better for meds/procedures than current
C0FW stubs/paths. Do not “fix” those historical rows unless we replay them
through C0FW after the adapters exist.

## Error catalog (from fhirprod IEN 1666 + 1648)

| Class | Example message | Host | First fix |
|---|---|---|---|
| A | `PRCADD failed: -1` | fhirprod #81 | `EN^SYNOS5PT` + `ENSURECPT` |
| B | `PRCADD failed: -1^Code N not mapped` | all VistA | extend `sct2os5` / allowlist |
| C | Medication / CarePlan `not_implemented` | all | native adapters (days) |
| D | `DiagnosticReport lab panels are not filed` | all | accept or panel importer |
| E | `Couldn't locate COLLECTION SAMPLE (#60.03)` | fhirprod worse | seed `60.03` / `60.11` |
| F | `URINE * result validation error` | all | normalize Synthea UA values |
| G | `Unable to map LOINC … (#60)` | all | `SYNQLDM` / graph-ok |
| H | `LABADD … empty status` | fhirprod | ISI RETSTA + accession |
| I | Condition no ICD-10 (findings) | all | skip non-diagnosis SCT |
| J | `File #9000010.07 does not contain a field N` | VistA DD | `ADDPOV^C0FWCON` field map |
| K | `Immunization CVX code not found` / inactive | VistA | seed `^AUTTIMM` |
| L | BMI unsupported | all | `C0FWVIT` map |
| M | TIU already matched (counted as miss) | display | count skip as success |
| N | HTTP 400/500 on `/addpatient` | all | empty-body / XLFJSON |

## Multi-day execution plan

### Day 0 (this pass) — fhirprod OS5 + VEHU procedure path — DONE

1. `D EN^SYNOS5PT` on fhirprod: `missing81` **951 → 0**. `0583H` IEN 200000155, `3048M` IEN 200000382.
2. `C0FWPRC` VEHU path now `ENSURECPT`s before `PRCADD` and falls back to `FILEPCE` when DATA2PCE returns −1.
3. Deployed `C0FWPRC` to fhirprod. Replayed Procedure errors on DFN 1661 / IEN 1666:
   **12 loaded / 804 error → 801 loaded / 15 error** (1.5% → 98.2%).
4. Harvest script + Synthea loop checked in (`scripts/harvest-load-errors.py`,
   `scripts/synthea-load-error-loop.sh`).

Replay of DFNs 1643–1661 Procedure errors (2026-09-09):

**1.7% → 96.8%** (267/15304 → 14812/15304 loaded). Errors 15037 → 492.

Leftover SCTs (true `sct2os5` gaps, not #81):

| n | SCT | Display |
|---|---|---|
| 321 | 241046008 | Dental plain X-ray bitewing |
| 93 | 314971001 | Camera fundoscopy |
| 66 | 700070005 | OCT of retina |
| 3 | 713024005 | Plain X-ray of wrist |
| 3 | 1290407002 | Plain X-ray of knee |
| 3 | 713026007 | Plain X-ray of humerus |
| 3 | 168594001 | Plain X-ray of clavicle |

C0FWPRC allowlist maps these imaging SCTs to standard CPT (70300, 92250,
92134, 73100, 73560, 73060, 73000). After the third replay pass, **all 19
patients are 15304/15304 procedures loaded (100%)**.

UA `#60.03` / `#60.11` seeded on fhirprod for every `#60` name containing
`URINE` plus `APPEARANCE` (URINE GLUCOSE 148, ketones 147, protein 149,
nitrite 1194, LE 1195, etc.).

### Day 1 — urine / lab dictionary (fhirprod) — DONE

Cohort DFNs 1643–1661 Lab replay (2026-09-09):

- Colton DFN 1661: **144/3126 → 3126/3126 (100%)**
- All C0FW patients on fhirprod: **8473/61782 (13.7%) → 61725/61782 (99.9%)**
- DiagnosticReport `not_implemented` → GRAPHOK (panels stay graph-of-record)
- Unmapped LOINCs (PHQ etc.) → GRAPHOK
- UA values: Synthea findings/`negative`/strip numbers → NEG/TRACE/1+…4+
- ISI `COLLECTION_SAMPLE=BLOOD` rewrites to `RED TOP` (missing on FOIA #62).
  `SYNDHP63` now omits empty CSAMP so ISI uses the test’s `#60.03` default.

Leftover PTT rows (`32.479` > 5 chars) were rounded to 1 decimal and
replayed: cohort Lab errors **33 → 0**.

1. Seed `#60.03` / `#60.11` for UA tests — done.
2. Normalize Synthea UA strings in `C0FWLAB` — done (`UANORM` / `UADIP`).
3. Graph-ok unmapped LOINCs and DiagnosticReports — done.
4. Replay Lab errors on DFNs 1643–1661 — done.

### Day 2 — Condition / Immunization / display honesty — DONE

1. `C0FWCON`: skip situation/social findings with no ICD (employment,
   education, “medication review due”, housing, IPV). Keep disorders.
2. `ADDPOV` DD-guards already shipped (`1203`/`1216`/`1217`).
3. `C0FWIMM`: missing/inactive CVX is `skipped`, not `error`.
4. `DOMSUM^C0FHIR`: count `skipped` as loaded-equivalent (TIU already
   matched, social findings, missing CVX). `not_implemented` still a miss.
5. `C0FWVIT`: map LOINC `39156-5` to BMI when file 120.51 has that type.

Replay DFNs 1643–1661 (2026-09-09): Colton Conditions **79 loaded / 154 error → 108 loaded / 114 skip / 11 error**.
Dashboard C0FW: Condition **30% → 89%**, DocumentReference **33% → 100%**, Immunization **27% → 86%**, Observation **87% → 100%**.
Leftover Condition errors are true ICD gaps (dental caries, gingival disease, back pain, imaging finding).
Leftover Immunization errors are missing encounter visit pointers (not CVX).

### Days 3–4 — Medication and CarePlan (shared, large)

1. Decide engine: native C0FW vs temporary `SYNFMED2` / `SYNFCP` wrappers
   (policy today is native-only; wrappers are the faster closure).
2. File outpatient meds that have a VistA drug match; skip the rest with a
   clear `skipped` reason, not `not_implemented`.
3. CarePlan write is native `C0FWCP`: reuse `SYNFHF` (`HFCPCAT` / `HFCP` /
   `HFACT` / `HFADDR` / `HFGOAL`) and file V Health Factor via DATA2PCE
   (VistA) or `RPMSHF^C0FWENC` (RPMS). Do **not** call `importCarePlan^SYNFCP`.
   No visit or missing SYNFHF → `skipped`. Already on visit → `skipped`
   (DOMSUM counts that as loaded). Read is already `GETCP^C0FHIRD`
   (`SYN CP ` names, id `CP-{AUPNVHF}`). RPMS first-pass no longer defers
   CarePlan.

Verify: CarePlan leaves `not_implemented`. A new Synthea patient shows
CarePlan as skipped/loaded and `GET /fhir/CarePlan?patient={dfn}` returns
the filed plans. Medication may still be a stub.

### Day 5+ — map coverage and the loop

1. Regenerate `sct2os5` from current Synthea + Codex `codes/` for the
   remaining unmapped procedure SCTs.
2. Run the protocol below on fhirprod, fhirdev, and vehu10 with the same
   seed. Compare harvest JSON. Close only when the same error class is
   gone on all three, or is documented as host-policy (RPMS lab graph,
   RPMS smoking deferred).

## Repeatable protocol (Synthea → load → harvest → tests)

Script: `scripts/synthea-load-error-loop.sh`

```text
1. Generate one Synthea FHIR Bundle (dockerized Java, unique OUT_DIR, optional -s seed).
2. POST /addpatient?load=1  (Expect: disabled, data-binary).
   Record HTTP status, ien, dfn. HTTP 400 = Bad Request (bundle/body), not domain errors.
3. GET /fhir  and the patient's /gtree load URL.
4. scripts/harvest-load-errors.py writes:
     domain loaded/source/skipped/error/not_implemented
     top messages
     compared to baseline JSON if present
5. Fail the loop if a *new* error class appears, or if a class marked
   closed in the baseline returns.
6. Optional: XINDEX on changed routines; /fhir?dfn= smoke; quality preset
   only when the patient is in a curated POP.
```

Loop until the harvest delta is empty or only contains accepted skips
(BMI until mapped, CarePlan until adapter exists, graph-ok LOINCs).

Hosts:

| Name | addpatient | graph |
|---|---|---|
| fhirprod | `https://fhir.vistaplex.org/addpatient?load=1` | `^%wd(17.040801,3)` |
| fhirdev | `https://devfhir.vistaplex.org/addpatient?load=1` | `^SYNGRAPH(2002.801,2)` |
| vehu10 | `http://127.0.0.1:9085/addpatient?load=1` | local VEHU |
| rpmsfhir | `https://rpmsfhir.vistaplex.org/addpatient?load=1` | RPMS C0FW |

Do not treat a single-host green as done. The same bundle on fhirdev vs
fhirprod is the OS5/#81 regression test.

## Success criteria

- fhirprod `missing81` = 0 and stays 0 after the next Synthea load.
- Recent cohort Procedure % is no longer ~2% (target: approach RPMS 85%
  for mapped SCTs; remaining misses are true map gaps).
- Harvest protocol runs on two hosts without hand-clicking Load Log.
- Each remaining error class has an owner in the table above.
- No new `not_implemented` domains without a dated adapter task.
