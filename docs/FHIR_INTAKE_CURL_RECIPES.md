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

## Deploy Data-Loader routines (ICN, updatepatient, etc.)

Codex sync does **not** copy **VistA-FHIR-Data-Loader** `src/*.m`. Example for container **`fhir`**, user **`osehra`**, routines dir **`/home/osehra/p`**:

```bash
DL=/path/to/VistA-FHIR-Data-Loader/src
docker cp "$DL/SYNFPAT.m" fhir:/home/osehra/p/
docker cp "$DL/SYNFUTL.m" fhir:/home/osehra/p/
docker cp "$DL/SYNFHIRU.m" fhir:/home/osehra/p/
docker exec fhir chown osehra:osehra /home/osehra/p/SYNFPAT.m /home/osehra/p/SYNFUTL.m /home/osehra/p/SYNFHIRU.m
docker exec fhir su - osehra -c \
  '/home/osehra/lib/gtm/mumps -run %XCMD "zlink \"SYNFPAT\" zlink \"SYNFUTL\" zlink \"SYNFHIRU\" zlink \"SYNWEBRG\" d EN^SYNWEBRG d stop^%webreq d go^%webreq"'
```

---

## Pull a VEHU patient bundle (reference server)

```bash
curl -sS 'http://127.0.0.1:9085/fhir?dfn=75' -o /tmp/vehu-dfn75.json
curl -sS 'http://127.0.0.1:9085/fhir?dfn=101075' -o /tmp/vehu-dfn101075.json
```

---

## New patient: `POST /addpatient`

Routes are registered lowercase in **`SYNWEBRG`**: **`addpatient`**.

```bash
curl -sS -w '\nHTTP %{http_code}\n' -H 'Expect:' -H 'Content-Type: application/json' \
  --data-binary @/tmp/vehu-dfn75.json \
  'http://127.0.0.1:9081/addpatient?load=1'
```

- **`load=1`** (default for domain loaders in many paths): run labs, vitals, encounters, etc. after patient file.
- **`load=0`**: tend to **patient / graph only**; use when you want to avoid duplicate domain work or work around loader errors.

Successful JSON often includes **`ien`**, **`dfn`**, **`icn`** (full string with **`V`**), and per-domain status.

---

## Existing patient: `POST /updatepatient`

Use when the patient **already** exists on file and **`addpatient`** would hit **duplicate SSN**, or when merging a **new bundle slice** into an **existing** graph row.

Query keys (use at least one):

| Query | Meaning |
|--------|---------|
| **`ien=`** | Graph store IEN (integer). |
| **`dfn=`** | VistA **DFN** → resolved to graph IEN via **`dfn2ien^SYNFUTL`**. |
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
- **`load=1`**: run domain importers (labs, vitals, …). **`updatepatient`** does **not** call the **panels** path used by **`addpatient`**, so behavior can differ from a full **`addpatient?load=1`** until panels are aligned.

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
