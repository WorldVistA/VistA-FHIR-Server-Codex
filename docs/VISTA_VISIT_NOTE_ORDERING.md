# VistA visit and clinical note ordering

This document captures how **Patient Care Encounter (PCE) visits** and **TIU documents (`^TIU(8925,...)`)** should relate, how **CPRS / Order Entry** actually wires them (which can look “reversed”), and how **`ORWPCE1`** handles **inpatient** note–visit linkage—including **admission-dated** vs **note-appropriate** encounters.

It is written for implementers integrating synthetic or external data (for example **SYN**) and for readers of VA M source snapshots such as a local **`vista-update-source`** tree.

---

## 1. Conceptually correct order (recommended for new code)

For a **new** integration (batch loader, FHIR import, test harness):

1. **Create or resolve the visit** in PCE so `^AUPNVSIT` reflects the **correct clinical encounter date/time** and context (location, service category, inpatient vs outpatient as appropriate).
2. **Create or update the TIU document** with the **visit pointer** set to that visit’s IEN (FileMan field **1207** in TIU; visit is also central to CPRS’s notion of “associated visit”).

Rationale: the **note’s clinical date** should align with the **encounter** you mean to document. For **inpatient** care, the visit used for the note is often **not** the same as “admission day only”; using the wrong visit produces notes that appear tied to the **admission** encounter instead of the **movement or dated contact** that matches when the note was written.

---

## 2. What CPRS does (workflow vs. final FileMan order)

In the **CPRS GUI workflow**, clinicians often start a **note** first: a **TIU shell** exists with an IEN (`NOTEIEN`) before encounter filing is complete.

The **Order Entry** side still ends up **filing PCE before it finalizes TIU’s visit pointer**:

- Build a **PCELIST**-shaped array and convert it through **`PXRPC`** into the **`PXAPI`** layout.
- Call **`$$DATA2PCE^PXAPI`** to create or update the **visit** and related PCE data, producing **`ORAVST`** (visit IEN).
- **Then** update TIU via **`FILE^TIUSRVP`**, setting **`1207`** (associated visit) to **`ORAVST`** when rules require it.

So: **UI order** can be “note first,” but **`DQSAVE^ORWPCE1`** still does **PCE first, TIU pointer second** for the linkage step.

---

## 3. ORWPCE1: `DQSAVE` pipeline (CPRS / OR)

Routine **`ORWPCE1`** (*PCE Calls from CPRS GUI*) implements this. Authoritative source in a typical VA/WorldVistA tree is **`ORWPCE1.m`**; the excerpts below match a **Feb 12, 2024** header (local snapshots may differ slightly by patch).

### 3.1 Declared dependencies (ICR-style references)

The routine header documents calls including:

- **`$$DATA2PCE^PXAPI`** — PCE filing API.
- **`DQSAVE^PXRPC`** — turn **PCELIST** into **`PXAPI`** and related arrays.
- **`FILE^TIUSRVP`** — TIU update (visit pointer, etc.).
- **`^TIU(8925,`** and **`^AUPNVSIT(`** — TIU and visit files.

### 3.2 Visit normalization before `DATA2PCE`

Before building the API array, **`DQSAVE`** may **strip** a visit IEN from **`PCELIST(1)`** and, for **hospital** encounters (`U,7)="H"` on `^AUPNVSIT(ORAVST,0)`), **validate** that the visit string built from `^AUPNVSIT` matches **`PCELIST(1)`** piece 4. If it does not match, **`ORAVST`** is cleared so **`DATA2PCE`** can establish a consistent visit. That supports the rule that the **encounter used for PCE** must match the **intended visit string**, not an arbitrary admission stub.

### 3.3 `DATA2PCE` then TIU update (inpatient)

After **`$$DATA2PCE^PXAPI`**, the code sets **`$P(ORRESULT(0),U,2)=ORAVST`**.

For **inpatient TIU** documents only, it updates the note’s visit:

- Condition: visit filing succeeded, **`NOTEIEN`** is set, and **`^TIU(8925,+NOTEIEN,0)`** piece **13** is **`"H"`** (inpatient).
- Action: **`FILE^TIUSRVP`** with **`ORX(1207)=ORAVST`**.

**Addenda:** if **`$$ISADDNDM^TIULC1(NOTEIEN)`** is true, the code may update the **parent** document (`TIEN` from piece 6 of the note’s zero-node) when the parent’s **node 12** does not already have a visit (piece 7 of node 12), so parent and addendum stay aligned with the **same** PCE visit.

Together, this implements “**note may exist first in the UI**, but **visit IEN used for TIU** is the one **`DATA2PCE`** produced,” and special handling so **inpatient** notes (and addenda) point at the **appropriate** visit rather than leaving stale or admission-only linkage.

---

## 4. PXRPC’s role

**`PXRPC`** (*PCE DATA2PCE RPC*) is the layer that:

- Validates **package** and **source** (e.g. source such as **TEXT INTEGRATION UTILITIES**).
- Calls **`DQSAVE^PXRPC1`** to translate **`PCELIST`** into an array acceptable to **`$$DATA2PCE^PXAI`**.
- Invokes **`DATA2PCE`** which, in current source, uses **`$$DATA2PCE^PXAI`**.

Broker RPCs such as **`PX SAVE DATA`** / **`PXRPC SAVE2`** hang off this routine. **`ORWPCE1`** calls **`DQSAVE^PXRPC`** directly so OR shares the same **PCELIST** semantics as those RPCs.

---

## 5. Outpatient vs inpatient (summary)

| Aspect | Outpatient | Inpatient |
|--------|------------|-----------|
| Typical visit date | Usually the encounter date of service | Admission date may define a **parent** encounter; **note** may need a **movement/dated** visit whose date matches documentation time |
| **`ORWPCE1` TIU block** | Not driven by the `NOTEIEN` + `"H"` branch shown above | **`NOTEIEN`** path runs: after **`DATA2PCE`**, **`FILE^TIUSRVP`** sets visit **1207** to **`ORAVST`**, with addendum/parent logic as applicable |
| Design goal | One visit IEN, note points to it | Ensure TIU points to the **clinically correct** visit (not only “admission visit”) |

---

## 6. Relation to SYN / FHIR work in this ecosystem

- **Synthetic loader (`VistA-FHIR-Data-Loader`)** typically files encounters and clinical data via **`$$DATA2PCE^PXAI`** (and related **SYNDHP\*** entry points), not via **`ORWPCE1`**. The **correctness rule** is the same: **visit IEN and encounter timing should be right before** (or at least when) you treat the encounter as documented in TIU.
- **`SYNFTIU`** stores **lines of text** under the **`fhir-intake`** graph for an encounter key; that is **not** the same as creating **`^TIU(8925)`** documents. Real notes for CPRS/VPR still require **TIU** (and usually **PCE**) as above.
- **FHIR export (`C0FHIR*`)** reads **VPR-shaped** data; encounter-linked **document** text on the encounter comes from VPR when **TIU-backed** documents exist for the visit, not from the graph **`SYNFTIU`** buffer.

---

## 7. Local source snapshot

If you maintain **`/home/glilly/vista-update-source`** (or similar), use it to diff **`ORWPCE1.m`** and **`PXRPC.m`** against your deployed system after patches. Build numbers in the second line of each routine change with VA releases.

---

## 8. References (external)

- WorldVistA Vivian routine pages (search **ORWPCE1**, **PXRPC**, **PXRPC1**): [Vivian DOX](https://vivian.worldvista.org/dox/routines.html)
- ICRs cited on those pages (e.g. **PXAPI** / **TIUSRVP**) govern **supported** calls from packages other than the owning one.

---

## Document history

- **2026-03-30** — Initial capture of visit-first vs CPRS note-first workflow, **`ORWPCE1`** inpatient/`FILE^TIUSRVP` linkage, **`PXRPC`** / **`PXAI`** roles, and SYN/TIU/FHIR caveats.
