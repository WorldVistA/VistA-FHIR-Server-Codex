# Encounter-linked clinical notes: export vs FHIR-intake import

## Export (`/fhir` / Codex `C0FHIR`)

Visit-linked progress note text is placed on the **`Encounter`** resource as **FHIR R4-style annotations**: repeated **`Encounter.note[].text`** (plain text strings), assembled in `SETENOTE^C0FHIR` → `ADDNOTE^C0FHIRBU`. Each note carries optional `time` / `authorString` when populated.

TIU bodies are **not** emitted as separate **`DocumentReference`** resources with **base64** `attachment.data` on this export path—they are flattened into **`Encounter.note`**.

Referenced implementation:

```232:250:src/C0FHIR.m
SETENOTE(RTN,IDX,ENC,VIEN) ; Add encounter-linked TIU note text when available
 ; VPRDVSIT TIU^VPRDVSIT skips docs when $$INFO^VPRDTIU<1 (status outside 7-13, etc.).
 ; Merge any visit-linked ^TIU(8925) not already in ENC so /fhir round-trips intake notes.
 ; VIEN = ^AUPNVSIT ien from GETENC (use for TIU "V" index; ENC("id") may be 0 or "E" prefixed).
 NEW CONT,DOC,I,J,TXT,VST,DA
 SET VST=$$VISITIEN^C0FHIR(.ENC,+$GET(VIEN))
 IF VST>0 DO TIUVPRFILL^C0FHIR(VST,.ENC)
 SET J=0
 FOR  SET J=$ORDER(ENC("document",J)) Q:J<1  DO
 . SET DA=+$GET(ENC("document",J))
 . QUIT:DA<1
 . SET ENC("document",J,"content")=$$TIUNOTETX^C0FHIR(DA)
 SET I=0
 FOR  SET I=$ORDER(ENC("document",I)) Q:I<1  DO
 . SET DOC=$GET(ENC("document",I))
 . SET CONT=$GET(ENC("document",I,"content"))
 . SET TXT=$$DOCNOTE^C0FHIRBU(DOC,CONT)
 . IF TXT'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT)
QUIT
```

```151:160:src/C0FHIRBU.m
ADDNOTE(RTN,IDX,TXT,DT,AUTHOR) ; Append one Annotation note to a resource
 NEW N
 SET IDX=+$GET(IDX)
 SET TXT=$GET(TXT)
 IF IDX<1!(TXT="") QUIT
 SET N=$ORDER(RTN("entry",IDX,"resource","note",""),-1)+1
 SET RTN("entry",IDX,"resource","note",N,"text")=TXT
 IF +$GET(DT)>0 SET RTN("entry",IDX,"resource","note",N,"time")=$$FM2FHIR($GET(DT))
 IF $GET(AUTHOR)'="" SET RTN("entry",IDX,"resource","note",N,"authorString")=$GET(AUTHOR)
 QUIT
```

On **import** into graph store / FileMan (VistA-FHIR-Data-Loader **`INGESTFHIR^SYNFTIU`**), **`Encounter.note` text is the primary path** for filing visit-linked TIU via `MAKE^TIUSRVP`. **`DocumentReference`** entries with **`text/plain`** base64 attachments are **also** accepted when appropriately encounter-linked (**`DOCREF1^SYNFTIU`**)—either shape can be handled on ingest.

## Repair: encounters loaded but encounter notes missing in TIU

**Cause:** `wsIntakeEncounters^SYNFENC` exits early when `load.encounters,zi,status,loadstatus` is already **`loaded`**, so a full **`replayIntake`** never re-invokes **`INGESTFHIR^SYNFTIU`** even though the intake bundle still carries **`Encounter.note`** in `%wd`/graph JSON.

**Non-destructive fix:** Issue a **replay** restricted to encounter-note filing (does not drop patients, encounters, or graph JSON):

```text
GET /replayIntake?dfn=<DFN>&retryEncounterTiuNotes=1
```

(`replayImport` is an alias route—same handler.)

Requirements:

1. Deploy routine updates: **`SYNFENC`**, **`SYNFHIR`**, and **`SYNFTIU`** including `retryEncounterTiuNotes^SYNFENC`, the `replayIntakeDomains^SYNFHIR` branch, and the idempotent skip inside **`INGESTFHIR^SYNFTIU`** (skip note indices that already have a stored TIU IEN).
2. Resolve **`<DFN>`** for the patient (e.g. name **`SIX,PATIENT`**) via your site tools or `GET /gtree/DPT(%22B%22)` patterns—see **`docs/TEST_SERVER_VALIDATION.md`**.
3. **Success criteria:** `/tiustats?dfn=<DFN>` or chart review shows encounter-linked notes; JSON response reports **`retryEncounterTiuNotes.encountersNotesFiled`** `>0` when notes were filed.

Example:

```bash
curl -sS "http://fhir.vistaplex.org:9080/replayIntake?dfn=REPLACE_DFN&retryEncounterTiuNotes=1"
```

If the bundle lives at a graph **IEN** that is **not** the latest for that DFN, pass **`ien=`** explicitly alongside **`dfn=`**.
