# FHIR intake — curl recipes

Host defaults used below: **minimal FHIR** container **`http://127.0.0.1:9081`**, **VEHU** **`http://127.0.0.1:9085`**. Adjust ports and hosts if yours differ.

Use **`-H 'Expect:'`** on **`POST`** to avoid some clients stalling on `100 Continue`.

---

## Deploy Codex routines to `fhir` (9081)

From the **VistA-FHIR-Server-Codex** repo root:

```bash
./scripts/local-fhir-container-sync.sh
```

Optional: pass a **DFN** for extra smoke (`/fhir?dfn=…`, `/tiustats?dfn=…`).

---

## C0FW `/addpatient` runtime assumptions

Codex owns the `/addpatient` and `/updatepatient` HTTP handlers when `C0FWADD`
and `C0FWUPD` are installed. C0FW no longer requires SYN or ISI routines for
`/addpatient`.

Required runtime pieces:

- `%webutils` / `%webreq` or compatible route registration and listener.
- `XLFJSON` for JSON decode/encode.
- Kernel/FileMan APIs used by the web job: `UPDATE^DIE`, `FIND1^DIC`, `%ZOSF`,
  `XLFDT`.
- A supported C0FW graph backend for `fhir-intake`: `SYNGRAF`/`^SYNGRAPH` or
  legacy `%wd`.
- Patient file `#2` / `^DPT` with standard fields for name, sex, DOB, SSN,
  address, and phone.

Optional runtime piece:

- `MPIFSPC` for `$$CHECKDG^MPIFSPC`, if you want C0FW to file MPI ICN fields
  `991.01`, `991.02`, and `991.1`. Without it, patient creation still succeeds,
  but `icn` is omitted and the response includes `patient.icnMessage`.

---

## Pull a VEHU patient bundle (reference server)

```bash
curl -sS 'http://127.0.0.1:9085/fhir?dfn=75' -o /tmp/vehu-dfn75.json
curl -sS 'http://127.0.0.1:9085/fhir?dfn=101075' -o /tmp/vehu-dfn101075.json
```

---

## New patient: `POST /addpatient`

Routes are registered lowercase in **`SYNWEBRG`**: **`addpatient`**. When
`C0FWADD` is installed, route registration prefers `WSPAT^C0FWADD`; older stacks
without C0FW fall back to `wsPostFHIR^SYNFHIR`.

```bash
curl -sS -w '\nHTTP %{http_code}\n' -H 'Expect:' -H 'Content-Type: application/json' \
  --data-binary @/tmp/vehu-dfn75.json \
  'http://127.0.0.1:9081/addpatient?load=1'
```

- **`load=1`** (default after a DFN is resolved): run C0FW domain loaders after
  patient filing or patient linking.
- **`load=0`**: graph/patient-link only; use when you want to avoid duplicate
  domain work or work around loader errors.

Successful JSON includes **`ien`** for the graph row and **`dfn`** when C0FW
creates or links the VistA patient. It includes **`icn`** when an ICN is supplied
or when `MPIFSPC` is installed and C0FW can derive/file an ICN base.

---

## Existing patient: `POST /updatepatient`

Use when the patient **already** exists on file and **`addpatient`** would hit **duplicate SSN**, or when merging a **new bundle slice** into an **existing** graph row.

Query keys (use at least one):

| Query | Meaning |
|--------|---------|
| **`ien=`** | Graph store IEN (integer). |
| **`dfn=`** | VistA **DFN** → resolved to graph IEN via C0FW graph indexes. |
| **`icn=`** or **`id=`** | Full ICN string (same as in **`addpatient`** response), resolved via **`POS("ICN",…)`**. |

```bash
curl -sS -w '\nHTTP %{http_code}\n' -H 'Expect:' -H 'Content-Type: application/json' \
  --data-binary @/tmp/vehu-dfn75.json \
  'http://127.0.0.1:9081/updatepatient?dfn=75&load=0'
```

```bash
# Example when you only have the full ICN (URL-encode if your client strips or breaks the V)
curl -sS -w '\nHTTP %{http_code}\n' -H 'Expect:' -H 'Content-Type: application/json' \
  --data-binary @/tmp/vehu-dfn75.json \
  'http://127.0.0.1:9081/updatepatient?icn=8666110043V436128&load=0'
```

- **`load=0`**: merge JSON and re-index; skip domain imports (or set explicitly).
- **`load=1`**: run C0FW domain loaders for the appended bundle slice.

---

## Smoke: listener and TIU sample (Codex sync script)

```bash
curl -sS -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1:9081/fhir'
curl -sS 'http://127.0.0.1:9081/tiuvpatients?limit=2' | head -c 400
```

---

## Graph / load debugging (optional)

Examples (if routes are registered on your image):

```bash
curl -sS 'http://127.0.0.1:9081/showfhir?dfn=75' | head -c 400
curl -sS 'http://127.0.0.1:9081/loadstatus?dfn=75' | head -c 400
```

`gtree` URLs for **`^%wd`** load logs are described in **`docs/STEPS_TAKEN.md`** and **`docs/TEST_SERVER_VALIDATION.md`**.

---

## ICN behavior (pointer)

See **`docs/ICN_GENERATION_FHIR_INTAKE.md`** for resolution order (Synthea UUID, FHIR ICN, SSN pseudo-base, sequential fallback) and file locations.
