# Plan: Integrating BSTS (parallel `bsts-vista` repo) with this system and rehmp

This document describes how to integrate **BSTS** (BSTS for VistA, `C0TS*` + `BSTS*`) as a **parallel repository** next to the FHIR/M web project and the **rehmp** C0RG stack, and how that integration supports **picklists** and broader **terminology** needs. It assumes deployment uses the same **M web listener** and reverse-proxy patterns already used for `/fhir` and `/rehmp` (see `docs/RUNNING_DEMOS.md`, `docs/FHIRDEV_LIVE_TOPOLOGY.md` as applicable).

**Note on evidence in-tree:** The canonical **C0RG** implementation (`C0RGAPI` and related) lives in the **sibling rehmp repository**, not in this repo (this project only carries the HTTP bridge `src/C0RGWEB.m`). When that sibling is checked out (e.g. `work/vista-stack/rehmp`), run a quick inventory of `C0RG` entry points and `RequestEnvelope` `operation` values to align the phases below with actual operations. This plan is written from **architecture and published docs** in this project plus the BSTS analysis in `docs/BSTS_C0TS_FORMAT_WEB_SERVICES.md`.

### Decisions (first implementation pass)

- **Start with Option A** (see section 3): clients use **`GET /bsts/*?format=…`** on the same origin as `/rehmp` and `/fhir`; no new `C0RG` / `RequestEnvelope` operation is required for that phase.
- **rehmp** documents that choice in **`docs/BSTS_TERMINOLOGY_OPTION_A.md`** (Vite/proxy and when to add Option B).
- **`bsts-vista`** carries the updated **`C0TSWS` / `C0TSWSU`** on branch **`feature/c0ts-format-bsts-integration`**, with deploy notes in that repo’s **`docs/C0TS_HTTP_FORMAT_DEPLOY.md`**. This repo’s **`src/C0TSWS.m`** and **`src/C0TSWSU.m`** stay in sync for image builds and review.

---

## 1. Current landscape (as relevant to BSTS)

### 1.1 Repositories and roles

| Repository | Role in terminology integration |
|------------|---------------------------------|
| **`bsts-vista`** (parallel) | Source of M routines: `BSTSAPI*`, `C0TSWS*`, `C0TSWSD`, `C0TSWSU`, `C0TSFM`, etc., and (often) OSEHRA BSTS KIDS builds. **No requirement to merge into the FHIR repo** if you version and deploy M separately. |
| **This project** (`VistA-FHIR-Server-Codex`) | Ships HTTP glue: web route registration (e.g. `SYNWEBRG` / `KBAIWS`), `C0TSWS` patches in `src/`, and **`POST /rehmp` → `C0RGWEB`** for JSON RPC to C0RG. |
| **rehmp** (sibling) | C0RG core (`HTTP^C0RGAPI`), `RequestEnvelope` / `ResponseEnvelope` contracts, and browser demos (`rehmp-rpc-demo`, `rehmp-fhir-demo`) that today focus on health, search, and FHIR bundles—not picklists—per regression docs. |

### 1.2 What rehmp already gives you (for integration design)

- **Single JSON gateway:** `POST /rehmp` with a top-level `operation` and structured payload, suitable for **adding** `operation`s such as `terminology.codesets`, `terminology.codelist`, or `valueset.expand` without inventing a second HTTP style for the UI.
- **Same-origin access:** Vite and production setups proxy `/rehmp` and `/fhir` to the M stack; **terminology** should be exposed on the **same origin** (e.g. under `/bsts/*` or under `/fhir/...$expand`) for browser demos to avoid CORS and split sessions.
- **HTTP semantics caveats:** `docs/M_WEBSERVER_HTTP_RESPONSE_ENHANCEMENTS.md` documents issues (e.g. default `201` on POST, error bodies) that matter if picklist APIs are added as **new POST** handlers. Prefer **GET** for read-only BSTS data where possible, or plan HTTP-layer fixes in parallel.
- **Kernel context:** `C0RGWEB` documents that `/rehmp` may need `ENVINIT^C0FHIR` (or equivalent) for `DUZ`/Kernel—**BSTS** calls may also need a valid VistA context for the same reasons when hitting Fileman or security-sensitive APIs.

### 1.3 What rehmp does *not* yet standardize (gap)

- **Picklists in the RPC demo** are not described as first-class in this project’s docs; the demos are oriented to **chart-style bundles** and **patient search**, not to configurable coded fields. Terminology for picklists is therefore a **new cross-cutting** concern: you need explicit **ValueSet- or BSTS-codeset–backed** contracts in both **UI** and **C0RG** (or a dedicated thin service).
- **Offline / cached lists** (for fast dropdowns) vs **live search** (typeahead) are not distinguished yet in-repo; both map naturally to BSTS **subset**, **codelist**, and **concepts** if you design parameters early.

---

## 2. Terminology and picklist requirements (conceptual)

Use these as integration requirements; refine with product owners and IHS/VA **SNOMED/terminology** policy.

- **Authoritative source:** BSTS in VistA is the on-box terminology store; HTTP `/bsts/*` exposes codesets, codelist, subset, code, and concept (see `docs/BSTS_C0TS_FORMAT_WEB_SERVICES.md`).
- **Picklist types:**
  - **Full enumeration** – bounded list: use `bsts/codelist` or `bsts/subset` with `format=json` and **`max`**, and optionally **pagination** in a later phase.
  - **Search / typeahead** – large vocabularies: need either **search API** (not always present in bare C0TS) or **FHIR** `$lookup` / `$validate-code` on a **CodeSystem** backed by the same data (longer path).
- **Interoperability:** If external systems must consume the same value sets, plan for **FHIR R4** `ValueSet` / `CodeSystem` (or Operations) in addition to `BstsCodesetList` JSON, as outlined in the BSTS format doc.
- **Licensing and audit:** SNOMED and related use may require **recorded** policy checks in deployment; not a code merge issue but a **governance** gate in the same release train as BSTS KIDS.

---

## 3. Integration options (where BSTS “plugs in”)

### Option A — **HTTP-only** (lowest change to rehmp)

- Deploy `bsts-vista` M into the VistA image; register **`GET bsts/*`** (already done in typical `KBAIWS^...` style configs).
- **rehmp UI** (Vite) calls **`/bsts/codeset`**, `/bsts/codelist`, etc. **directly** (same origin), with `format=json`.
- **Pros:** No C0RG change; fast to prove.
- **Cons:** Two client patterns (`/rehmp` for clinical RPC, `/bsts` for terms); may duplicate auth/context handling unless the gateway normalizes them.

### Option B — **C0RG operations** (single JSON API)

- In the **rehmp** repo, extend `C0RGAPI` (or a small `C0TSBRG` module) to implement operations such as:
  - `terminology.listCodesets` → `wsCDSETS^C0TSWS` (or call `^BSTSAPI` directly in-process).
  - `terminology.listCodes` with `{ "codesetId", "max", "offset" }` → codelist/subset.
- `POST /rehmp` only; follows existing `RequestEnvelope` and error mapping.
- **Pros:** One contract for the UI; can attach **DUZ** and **audit** in one place.
- **Cons:** Requires rehmp release coordination; must respect POST/HTTP body issues in `M_WEBSERVER` (see above).

### Option C — **FHIR layer** (best for long-term interoperability)

- Add read-only `CodeSystem` / `ValueSet` + `$expand` (or custom Operation) in **`C0FHIR`** (or a small extension package) that **uses BSTS** as the source of truth.
- **rehmp** and external clients use **`/fhir`**, not `/bsts`, for picklists.
- **Pros:** Standard FHIR; one protocol for in-house and partners.
- **Cons:** Higher implementation cost; must map BSTS internal IDs to canonical URIs.

**Recommendation:** Start with **Option A** for demos and **Option B** for anything that must sit behind the same `RequestEnvelope` and security as other C0RG work; use **Option C** when a stable external contract is required.

---

## 4. Phased plan

### Phase 0 — Prereqs and repository wiring

- [ ] **Pin versions:** Label which **bsts-vista** branch/commit and which **BSTS** KIDS build the stack expects.
- [ ] **Single deploy path:** Document copying `p/C0TSWS*.m` (and this repo’s `src/` updates if any) + `ZLINK` + smoke `curl` for `/bsts/codeset?format=json` (from `BSTS_C0TS` doc).
- [ ] **Proxy:** Ensure edge Caddy/Nginx includes **`/bsts`** (or a prefix) to the M listener, same as `/rehmp` and `/fhir`.
- [ ] **Inventory rehmp:** In the rehmp checkout, list `HTTP^C0RGAPI` **operation** dispatch and `C0RGRES` error shapes to avoid name collisions for new `terminology.*` operations.

### Phase 1 — Stable read surface

- [ ] Rely on **`GET`** `/bsts/*?format=json` (already implemented in `C0TSWS` after prior work); add **defaults for `max`** and document **truncation** if lists are large.
- [ ] Add **automation** in CI or a smoke script: `codeset` → one `codelist` for a known id; parse JSON in Python or `jq`.
- [ ] (Optional) Publish a **machine-readable** map: UI field id → BSTS `codeset` id and optional `subset` name.

### Phase 2 — rehmp and picklist UX

- [ ] **rehmp-rpc-demo (or product UI):** add a small **“Terminology”** or **per-field** picker component that:
  - loads **codesets** (or a fixed list from config) once;
  - loads **codelist** on demand with **debounced search** (client-side filter if `max` is small, or server filter if you add a search operation later);
  - shows **code + display** and stores the pair the chart model expects.
- [ ] If using **Option B**, add **C0RG operations** and have the UI call **only** `/rehmp` (no direct `/bsts` from the browser) for consistency.
- [ ] **Validation:** on save, optional `$validate-code` (FHIR) or BSTS `bsts/code` / `bsts/concept` to verify selection still exists (depending on product rules).

### Phase 3 — Performance and operations

- [ ] **Caching:** HTTP `Cache-Control` for static-ish codeset lists; in-process **^XTMP** buffers already used by `C0TSWSD` for codelist—document TTL and **clear** on terminology reload.
- [ ] **Pagination** or `offset` in API design before exposing large VANDF/SNOMED sets to the browser in one shot.
- [ ] **Observability:** log slow `codelist` calls; alert if BSTS or Fileman is unhealthy.

### Phase 4 — FHIR (optional, product-driven)

- [ ] Expose `ValueSet` / `$expand` backed by BSTS; point Synthea or **picklist** components at FHIR URLs if that matches your interoperability roadmap (see `codes/` and `Synthea_SNOMED` docs in this repo for value-set *examples*, not the live BSTS source).

---

## 5. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| **Divergent M sources** (bsts-vista vs this repo’s `src/C0TS*`) | Single **canonical** branch; release checklist: “copy from X, `ZLINK`, run smoke.” |
| **String size / 500s** on huge `codelist` | Use **`max`**, **streaming** JSON (already addressed for codelist), and **pagination** in design. |
| **POST /rehmp** transport quirks | Prefer **GET** for read-only BSTS; or fix M web per `M_WEBSERVER_HTTP_RESPONSE_ENHANCEMENTS.md`. |
| **Licensing (SNOMED, etc.)** | Governance review before production enablement. |
| **rehmp not yet picklist-aware** | Treat picklists as **new** feature set; do not assume existing C0RG operations return coded fields until inventory confirms. |

---

## 6. Deliverables checklist (definition of “integrated”)

- [ ] BSTS M routines deployed and **versioned** from the **parallel bsts-vista** (or your fork) process.
- [ ] `GET /bsts/*?format=json` (and csv/xml as needed) **smoke-tested** in each environment.
- [ ] **Documented** mapping from **UI field** → **BSTS codeset** (and subset, if any).
- [ ] rehmp path chosen: **direct `/bsts`**, **C0RG `terminology.*`**, and/or **FHIR `/fhir`**, with one diagram for the team.
- [ ] Picklist prototype in **rehmp** demo (or app) that loads live data from that path.

---

## 7. References in this repository

- `docs/BSTS_C0TS_FORMAT_WEB_SERVICES.md` — BSTS HTTP behavior, `format=`, and recommendations.
- `docs/RUNNING_DEMOS.md` — `/rehmp` regression and rehmp demo layout (sibling repo).
- `docs/M_WEBSERVER_HTTP_RESPONSE_ENHANCEMENTS.md` — HTTP layer constraints for `POST` JSON.
- `src/C0RGWEB.m` — `POST /rehmp` bridge to `$$HTTP^C0RGAPI`.
- `src/SYNWEBRG.m` — example `addService^%webutils` pattern for route registration.

---

*This is a working integration plan. Update Phase checkboxes and the “rehmp inventory” in Phase 0 after the sibling rehmp repo is available on the work machine.*
