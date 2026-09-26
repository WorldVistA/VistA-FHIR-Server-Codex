# Encounter-associated codes: visit type vs POV vs problem list

**Status:** working design note (started 2026-09-25)  
**Audience:** agents and humans filing or reading Encounters on VistA/RPMS FHIR lanes  
**Related:** `C0T-terminology-gateway/docs/BSTS_SYN_CODE_MAPPING_OPTIONS.md`,  
`VistA-FHIR-Data-Loader` (`SYNFENC` / `ENCTUPD^SYNDHP61` / `SYNOS5*`),  
`VistA-FHIR-Server-Codex` (`C0FWENC`, `C0FWCON`, `C0FHIR` / `C0FHIRP`),  
`CPRS-on-FHIR/docs/analysis/cprs-encounter-pce.md`

## Why this note exists

An Encounter in our stack carries **at least two different kinds of clinical code**, and we have been mixing them:

| Role | Real-world usual code | Open-source / Synthea usual code | VistA / PCE home |
|------|------------------------|----------------------------------|------------------|
| **Visit type** (what kind of visit / E&M-like workload) | CPT (AMA) | SNOMED *procedure / regime* concepts | **V CPT** on the Visit (DATA2PCE PROCEDURE / visit-type) |
| **POV / purpose of visit / reason** (why the patient is here) | ICD-10-CM | SNOMED *disorder / finding* (often) | **V POV** — **ICD required** |
| **Problem list** (ongoing problems) | ICD-10-CM **and** SNOMED CT | Often SCT-only from Synthea | Problem file `.01` = ICD; `80001`/`80002` = SCT |

When one side of a dual code is missing, loaders invent fallbacks (OS5 hybrids, STD CODES, Z76.89, historically R69.). That is where quality measures, dashboards, and round-trips get confused.

---

## 1. Visit-type code (procedure-shaped)

### What it is

The visit-type answers: *what class of encounter / service was this?*  
Examples: office visit, ED visit, telehealth, inpatient admission.

In licensed US practice this is usually a **CPT** (often E&M).  
In Synthea and other open-source generators it is almost always a **SNOMED CT** concept from the *encounter* ValueSet — coded as a procedure/regime, e.g.:

- `185349003` — Encounter for check up (default when type is empty in SYN)
- `4525004` — Emergency department patient visit  
- `308335008` — Patient encounter procedure (generic; **not** a diagnosis)

Source ValueSet in-tree: `VistA-FHIR-Server-Codex/codes/encounter_sct.json`.

### How we file it today

1. FHIR `Encounter.type.coding[].code` (SYN: often first coding) → `SCTCPT`.
2. `ENCTUPD^SYNDHP61` maps:
   - try `sct2cpt` (real CPT in file 81), else
   - try **`sct2os5`**, else
   - fallback OS5 **`6456Q`** (Outpatient Encounter).
3. Result is written as a **PROCEDURE** row on the Visit (visit-type / V CPT), **not** as V POV.

Read path (`SETETYP` / `ENCCOD^C0FHIR`): V CPT / OS5 on the visit → `Encounter.type` with SCT preferred and CPT/OS5 as a second coding. Encounter-only OS5 rows are **excluded from Procedure** (`SKIPVCPT` / `ISENCD^C0FHIRP`).

### How to choose the right SNOMED visit-type

1. Prefer a code from the **Synthea encounter ValueSet** (`codes/encounter_sct.json`), not from condition/procedure disorder sets.
2. Prefer concepts whose FSN hierarchy is *procedure / regime/therapy / situation* for visits — **not** *disorder / finding* used as POV.
3. If the Bundle already has a CPT visit-type, keep it; map SCT→CPT only when filing into file 81.
4. Empty type → SYN default `185349003` (acceptable generic). Avoid treating `308335008` as a diagnosis (C0FWENC already special-cases this toward Z76.89 POV rather than an ICD map of the procedure SCT).

### Do OS5 codes help?

**Yes — for open-source VistA without an AMA CPT license.**

| Piece | Role |
|-------|------|
| `maps/SYNOS5.GO` + `SYNOS5LD` / `SYNOS5D*` | Builds `^SYN("2002.030","sct2os5",…)` (~1000+ SCT↔OS5 pairs) |
| `SYNOS5PT` | Seeds hybrid “CPT-shaped” entries into file **81** so DATA2PCE can store them |
| Runtime | Visit-type SCT → OS5 → V CPT; read inverse OS5 → SCT for `Encounter.type` |

**Caveats:**

- OS5 codes are **not** AMA CPT. Do not advertise them as `http://www.ama-assn.org/go/cpt` without also emitting the true SCT (Codex comments already warn about this).
- The generated `sct2os5` table is built from **multiple** Synthea ValueSets (encounter *and* procedure *and* other categories). Using a disorder SCT as “visit type” can still get an OS5 row — that does **not** make it a valid visit-type. Role discipline matters more than map hit rate.
- Ops: after loading maps, run `EN^SYNOS5PT` so file 81 actually contains the hybrids (`ENSURECPT` before PRCADD). Map-only without #81 seed → procedure/visit filing failures.

**BSTS / OS5:** BSTS (IHS) is the production SNOMED↔ICD (and related) association service for RPMS. It helps **POV / problem ICD**, not OS5 visit-type synthesis. For FOIA/open-source lanes, OS5 remains the visit-type stand-in; BSTS/Lexicon `5217693` remains the SCT→ICD path for diagnoses.

---

## 2. POV / purpose of visit / reason (diagnosis-shaped)

### What it is

The POV answers: *why was this visit?*  
Examples: type 2 diabetes follow-up, acute bronchitis, wellness without illness.

Usual code: **ICD-10-CM**.  
Synthea often sends **SNOMED CT** disorders/findings on `Encounter.reasonCode` or as `Encounter.diagnosis` → Condition.

### How we file it today

| Incoming | Behavior |
|----------|----------|
| ICD-9 / ICD-10 on reasonCode | Resolve with `ICDEX` → file **V POV** |
| SNOMED on reasonCode | Map via `sct2icd` / `sct2icdnine` (date-aware) or Lexicon `GETASSN^LEXTRAN1(…,5217693)` |
| Map succeeds | V POV with ICD |
| Map fails (SYN) | **STD CODES** with system SCT + optional HF `SYN SNOMED PURPOSE OF VISIT` — **not** a true V POV |
| Map fails / Lexicon R69 (Codex) | Prefer reject R69; C0FWCON `SCTICD10` rejects R69 catch-all; residual repair via `C0FR69X` |

**Rule of the platform:** a **true V POV row requires ICD**. SCT-only is documentation/audit, not PCE diagnosis workload in the ICD sense.

Read path for encounter-diagnosis Conditions (`SETENCDX^C0FHIRD`) emits **ICD** from V POV. Problem-list Conditions prefer SCT when `sctc` is present.

---

## 3. Problem list: both ICD and SCT

VistA/RPMS Problem List filing in this stack:

- **`.01`** = ICD diagnosis (required to file).
- **`80001` / `80002`** = SNOMED CT concept (+ designation) when available.

`C0FWCON` / `PROBFDA^SYNDHP61`:

- SCT-only with no ICD map → **error / skip** (do not invent R69.).
- ICD-only → can file; SCT backfill when Lexicon/BSTS can (`SETSCT`).
- Prefer SYN/BSTS table maps first so **stale Lexicon R69 associations cannot win**.

This matches the clinical rule you stated: problems are dual-coded; missing ICD blocks filing; missing SCT is incomplete but sometimes tolerated until backfill.

---

## 4. Where we get confused (tracked)

| Confusion | What happens | Fix direction |
|-----------|--------------|---------------|
| Visit-type SCT filed as POV | Procedure concept forced through ICD map → junk ICD or Z76.89 | Keep visit-type on V CPT / `Encounter.type` only |
| POV SCT with no ICD | STD CODES / skip; visit looks “reason-less” for ICD measures | Explicit map, intentional proxy ICD, or accept STD CODES — document which |
| Lexicon → **R69.** | Unspecified illness on POV/problems | Reject in `SCTICD10` / `SCT2ICD`; repair with `C0FR69X`; prefer `sct2icd` tables |
| SCT-only Procedure, OS5 not in #81 | PRCADD fails | `SYNOS5PT` + `ENSURECPT` |
| OS5 hybrid claimed as AMA CPT on export | Misleading Coding.system | Prefer SCT coding; label OS5 honestly |
| Encounter OS5 appearing as Procedure | Inflated procedure lists | Keep `ISENCD` / `SKIPVCPT` |
| Same SCT in both encounter and condition ValueSets | Ambiguous role | Bundle role wins: type vs reasonCode vs Procedure vs Condition |
| ICD-only Condition on PL | Files without SCT | Backfill SCT when possible; don’t block ICD-only if ICD is valid |

---

## 5. Does VistA use Note Title or Clinic to pick the CPT?

### Short answer

**Neither TIU Note Title nor Clinic Stop is the CPT visit-type in our open-source FHIR write path.**  
In CPRS/PCE production, visit-type CPT is chosen on the **PCE Visit Type** page (location-parameterized pick list), optionally auto-selected per clinic policy — **not** derived from the note title string.

### Production CPRS / PCE pattern

From CPRS analysis (`cprs-encounter-pce.md`):

1. Encounter context = Hospital Location + date/time + category (visit created lazily on first PCE/TIU write).
2. **Visit-type (CPT)** lists come from `ORWPCE VISIT` for that **location/date**; auto-select via `ORWPCE AUTO VISIT TYPE SELECT`.
3. Diagnoses (POV) are a separate page (`ORWPCE DIAG` / lexicon / problem import).
4. Procedures are yet another page (`ORWPCE PROC`).
5. TIU note title drives **document class, cosign, workload prompts** (`TIU GET DOCUMENT PARAMETERS`) — it may *require* that PCE be completed before sign (`CPTREQD`-style behavior), but it does **not** itself supply the CPT code.
6. Clinic / stop code is **location and workload metadata** (we expose stop-code as `Encounter.serviceType` **text** only in Codex). It scopes which visit-type pick list you see; it is not a substitute for the coded visit-type row.

### What we do on Synthea / C0FW lanes

| Mechanism | Used for visit-type CPT? |
|-----------|---------------------------|
| Explicit `Encounter.type` → SCT→OS5/CPT → V CPT | **Yes — primary** |
| Explicit `Procedure` → V CPT | Yes, for clinical procedures |
| Hospital Location / clinic name from load maps | Visit pointer / stop-code context |
| TIU note title | Not used to derive CPT in SYN/C0FW ingest |

### What we should do to follow the pattern

1. **Always send a clear visit-type** on `Encounter.type` (SCT from encounter ValueSet, or real CPT when licensed).
2. **Always send POV as ICD** when we need a true V POV; if only SCT is available, map or document STD CODES fallback — do not shove visit-type SCT into POV.
3. **Do not** invent CPT from note title in FHIR writes unless a site explicitly models PCE auto-visit-type rules as configuration.
4. **May** use clinic/location to *select* a default visit-type from a configured list (mirroring `ORWPCE AUTO VISIT TYPE SELECT`) — treat that as site policy, not terminology magic.
5. Keep Problem List dual-coding: ICD required, SCT strongly preferred; never default R69.

---

## 6. Recommendations (working rules)

1. **One code, one role** in every Bundle:
   - `Encounter.type` → visit-type (SCT encounter set or CPT)
   - `Encounter.reasonCode` / encounter-diagnosis Condition → ICD POV (+ SCT if present)
   - `Procedure` → clinical procedure SCT/CPT
   - Problem List Condition → ICD + SCT
2. **OS5** is the open-source **visit-type/procedure stand-in for file 81**, not a diagnosis system and not AMA CPT.
3. **BSTS / Lexicon / `sct2icd`** are for **SCT→ICD** on POV and problems — use them there; reject R69.
4. When only one code exists:
   - Visit-type SCT only → OS5/CPT path; do not ICD-map it as POV.
   - POV SCT only → map to ICD or STD CODES; do not file fake R69.
   - Problem SCT only → fail closed until ICD exists.
   - Problem ICD only → file ICD; backfill SCT later.
5. Align FHIR write contracts with PCE: visit-type and POV are **separate DATA2PCE categories**, same as CPRS tabs.
6. Operational checklist for a lane: `LOADOS5` → `EN^SYNOS5PT` → verify `sct2os5` and file 81 → smoke one Encounter with both type and ICD reason.

---

## 7. Open questions

- Should C0FW expose an optional **clinic-default visit-type** table (location → OS5/CPT) to mirror `ORWPCE AUTO VISIT TYPE SELECT`?
- Should STD CODES SCT POV be promoted to a documented FHIR extension so round-trips do not look “missing reason”?
- How much of `sct2os5` should be split into **encounter-only** vs **procedure-only** maps to stop cross-role hits?

---

## 8. Pointers (code)

| Concern | Entry |
|---------|--------|
| SYN Encounter load | `SYNFENC`, `ENCTUPD^SYNDHP61` |
| OS5 maps | `SYNOS5LD`, `maps/SYNOS5.GO`, `EN^SYNOS5PT` |
| C0FW Encounter write | `C0FWENC` |
| C0FW Condition / PL | `C0FWCON` (`SCTICD10`, `SETSCT`) |
| FHIR Encounter.type read | `SETETYP` / `ENCCOD^C0FHIR` |
| Skip encounter CPT as Procedure | `ISENCD` / `SKIPVCPT^C0FHIRP` |
| R69 POV repair | `C0FR69X` |
| Terminology policy | `C0T-terminology-gateway/docs/BSTS_SYN_CODE_MAPPING_OPTIONS.md` |
| CPRS PCE visit-type vs note | `CPRS-on-FHIR/docs/analysis/cprs-encounter-pce.md` |

---

## 9. Audit vs working rules (2026-09-25)

Audit of **current code** against §6 recommendations. SYN = Data-Loader; C0FW = Codex write; read = Codex FHIR export.

| # | Rule | Verdict | Evidence |
|---|------|---------|----------|
| R1 | Visit-type → V CPT / PROCEDURE, not POV | **PASS** | SYN `ENCTUPD^SYNDHP61` files `SCTCPT` as PROCEDURE. **C0FWENC `BUILD` calls `ADDVTYP`** → `VTYMAP` (`sct2cpt`/`sct2os5`/fallback `6456Q`) → `ENSURECPT^C0FWPRC` → DATA2PCE `PROCEDURE`. Skips if a Procedure already queued. |
| R2 | POV needs ICD; SCT-only no fake R69 | **PASS** | ICD → `ADDDX`; SCT-only → `STD CODES` + skip. `SCTICD10^C0FWENC` delegates to `C0FWCON` (tables first + `ISR69`). |
| R3 | Generic type `308335008` not ICD-mapped as dx | **PASS** | `ADDPOV^C0FWENC` files **Z76.89** when type empty/`308335008` and no reason POV. Visit-type still goes to PROCEDURE via `ADDVTYP`. |
| R4 | Problem list ICD required; SCT-only fail closed | **PASS** | `C0FWCON` / `PROBFDA^SYNDHP61` error if no ICD; no R69 invent on PL path. |
| R5 | SCT→ICD: tables first; reject Lexicon R69 | **PASS** | Encounter + PL share `SCTICD10^C0FWCON`. SYN `SCT2ICD` rejects R69. |
| R6 | OS5 not advertised as AMA CPT | **PASS** | `ENCCOD` / `SETETYP^C0FHIR` gate on `$$ISCPT^C0FHIRP`; hybrids use `urn:va:syn:os5`. |
| R7 | Encounter-only OS5 excluded from Procedure | **PASS** | `SKIPVCPT` / `ISENCD^C0FHIRP`. |
| R8 | TIU note title does not derive CPT | **PASS** | No title→CPT in C0FWENC / C0FWPRC / SYN encounter load. |
| R9 | Clinic/stop = metadata only | **PASS** | Stop → `serviceType` text; clinic = location context. |
| R10 | OS5 seed / ENSURECPT available | **PASS** | `SYNOS5PT`, `SYNGBLLD`, `ENSURECPT^C0FWPRC`. |
| R11 | Role discipline (type ≠ reason ≠ procedure) | **PASS** | Read dual-role guards (`ISDUALS`). Writes: `OKVTY`/`ISENCS` gate in `ADDVTYP^C0FWENC` and `ENCTUPD^SYNDHP61` — disorder SCT as type is skipped (not silent OS5). |
| R12 | STD CODES fallback when POV map fails | **PASS** | SYN + C0FW both file SCT STD CODES / skip true V POV. |

**Score:** 12 PASS · 0 PARTIAL · 0 FAIL (post-P1, 2026-09-25 evening)

### Bottom line

P0 + P1 close the visit-type PROCEDURE path, OS5 AMA mislabel, Lexicon R69 on POV, unified SCT→ICD, and write-side encounter-role gate. P2 soft-splits OS5 maps by role, adds optional clinic visit-type defaults, and marks STD CODES on Encounter.reasonCode read.

---

## 10. Fix plan

### P0 — close the FAIL / dangerous PARTIALs

| ID | Change | Where | Status | Done when |
|----|--------|-------|--------|-----------|
| **P0a** | File visit-type as DATA2PCE **PROCEDURE** (SCT→`sct2cpt`→`sct2os5`→fallback OS5), mirror `ENCTUPD^SYNDHP61` | `BUILD` / `ADDVTYP` / `VTYMAP^C0FWENC` | **DONE** | vehu10: `ADDVTYP` for SCT `185349003` queues PROCEDURE → file 81 `99202`; `parms("VTYCPT")` set |
| **P0b** | Stop labeling OS5 as AMA CPT on Encounter.type | `ENCCOD` / `SETETYP^C0FHIR` + `$$ISCPT^C0FHIRP` | **DONE** | `ENCCOD("6456Q")` → `urn:va:syn:os5`; `ENCCOD(99213)` → AMA CPT |
| **P0c** | Reject R69 in encounter POV Lexicon map; prefer tables first | `SCTICD10^C0FWENC` → `$$SCTICD10^C0FWCON` | **DONE** | HTN `59621000` → ICD-10 `I10.` (ien 508014), not R69 |

### P1 — harden role + map consistency

| ID | Change | Where | Status | Done when |
|----|--------|-------|--------|-----------|
| **P1a** | Reject R69 if `sct2icd` ever returns it (treat as unmapped) | `ENCTUPD^SYNDHP61` after MAP | **DONE** | SYN POV path uses `SCT2ICD` (never R69); HTN → `I10.` |
| **P1b** | Unify SCT→ICD order everywhere: tables / BSTS → Lexicon → reject R69 | C0FWENC, C0FWCON, SYNDHP61 | **DONE** | `SCT2ICD^SYNDHP61` prefers `SCTICD10^C0FWCON` when present; same reject policy |
| **P1c** | Write-side role check: `Encounter.type` SCT must be encounter-set (`ISENCS` / `codes/encounter_sct.json`); refuse disorder SCT as visit-type | C0FWENC + SYNDHP61 | **DONE** | Disorder SCT `44054006` → no PROCEDURE; encounter SCT `185349003` → CPT `99202`; `308335008` added to `ENCSCT` |

### P2 — structural / policy

| ID | Change | Where | Status | Done when |
|----|--------|-------|--------|-----------|
| **P2a** | Split `sct2os5` into encounter-only vs procedure-only maps | `SPLITOS5^SYNOS5LD` → `sct2os5enc` / `sct2os5prc`; consumers prefer role map | **DONE** | vehu10: 1041→61 enc / 986 prc; pure encounter SCT not on prc map |
| **P2b** | Optional clinic → default visit-type table | `VTYDEF^C0FWENC` reads `^C0F("VTYDEF",LOC)` when type empty | **DONE** | Empty = no-op; set node when a site asks (no CPRS RPC coupling) |
| **P2c** | Mark STD CODES SCT POV on FHIR read | `SETSTD^C0FHIR` + `vista-standard-code` extension | **DONE** | Every V STANDARD CODES reasonCode has `vista-standard-code` boolean |

### Suggested implementation order

1. **P0c** (small, stops R69 on C0FW POV) → smoke reasonCode Bundle. ✅  
2. **P0b** (read-only export fix) → smoke `/fhir?dfn=` Encounter.type systems. ✅ (`ENCCOD` unit)  
3. **P0a** (write visit-type PROCEDURE) → smoke type-only Encounter; confirm V CPT + still no Procedure resource for encounter-only OS5 (**R7**). ✅ (`ADDVTYP` unit on vehu10)  
4. **P1a–P1c** → shared helper + role gate. ✅  
5. **P2a–P2c** → role maps + clinic default hook + STD CODES marker. ✅

### Implementation log (2026-09-25)

- Synced to **vehu10** via `./scripts/vehu10-fhir-sync.sh`.
- **P0a:** `ADDVTYP` + `VTYMAP`; SCT `185349003` → PROCEDURE CPT `99202`.
- **P0b:** `ENCCOD("6456Q")` → `urn:va:syn:os5`; real `99213` → AMA CPT.
- **P0c:** `SCTICD10^C0FWENC` → `C0FWCON`; HTN `59621000` → `I10.`, not R69.
- **P1a/b:** `SCT2ICD^SYNDHP61` (C0FWCON → sct2icd → Lexicon, reject R69); `ENCTUPD` uses it.
- **P1c:** `OKVTY` + `ISENCS` gate in `ADDVTYP^C0FWENC` and `ENCTUPD^SYNDHP61`; `308335008` in `ENCSCT^C0FHIRP`.
- Code: Codex `src/C0FWENC.m`, `src/C0FHIR.m`, `src/C0FHIRP.m`; Data-Loader `src/SYNDHP61.m`.
- **P2a:** `SPLITOS5^SYNOS5LD` builds `sct2os5enc`/`sct2os5prc`; `VTYMAP`/`ENCTUPD` prefer enc; `SCT2OS5P`/`SYNDHP65` prefer prc.
- **P2b:** `VTYDEF` / `^C0F("VTYDEF",LOC)` optional clinic default when Encounter.type empty.
- **P2c:** `SETSTD` emits `http://vistaplex.org/fhir/StructureDefinition/vista-standard-code`.
- Code (P2): Codex `src/C0FWENC.m`, `src/C0FWPRC.m`, `src/C0FHIR.m`; Data-Loader `src/SYNOS5LD.m`, `src/SYNDHP61.m`, `src/SYNDHP65.m`, `src/SYNDHPMP.m`.


### Verification commands (after each P0)

```text
; After P0a/P0c — file a Bundle, then:
D ENCTUPD^SYNDHP61 / or C0FW Encounter load
W $$GET1^DIQ(9000010.18,VCPTIEN,.01)   ; visit-type V CPT present
W $$GET1^DIQ(9000010.07,POVIEN,.01)    ; POV ICD, not R69.

; After P0b — HTTP:
curl -sS "$BASE/fhir?dfn=N" | jq '..|objects|select(.resourceType=="Encounter")|.type'
; coding[].system must not be ama-assn for OS5 hybrids
```

### Out of scope for this plan

- Changing TIU titles or clinic stop codes to invent CPT (rules say don’t).  
- Unattended fhirprod experiments.  
- Expanding OS5 to replace BSTS for ICD.
