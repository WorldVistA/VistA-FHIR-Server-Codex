# OS5 Codes

## What OS5 Means

**OS5** stands for **Open Source 5-digit codes**. In VistA and the Patient Care Encounter (PCE) context, OS5 refers to the procedure code system (or code format) that PCE accepts when recording procedures—typically **CPT/HCPCS**-style codes stored in VistA file **#81** (CPT Procedure Codes). The “5-digit” aspect aligns with the common length of CPT procedure codes.

## OS5 and SNOMED

OS5 codes are mapped to SNOMED codes. The **text (display name) of the SNOMED code is the text of the OS5 code**—that is, the human-readable description for an OS5 procedure code comes from its associated SNOMED concept. So each OS5 code has a corresponding SNOMED code, and that SNOMED code’s display text is used as the OS5 code’s text.

## Role in VistA PCE

When ingesting procedures (e.g., from Synthea FHIR or other external sources), the data loader must supply a procedure code that PCE recognizes. That target code is what the loader and mapping logic treat as the **OS5** value:

- **PCE procedure storage:** Procedures are filed in the **V CPT** file (#9000010.18). The procedure field is populated with a value that references the CPT/HCPCS file (#81)—i.e., an OS5 (5-digit–style) procedure code or its IEN.
- **SNOMED → OS5 mapping:** External data often uses **SNOMED CT** for procedures. The loader uses a mapping named **`sct2os5`** (SNOMED CT to OS5) stored in `^SYN(2002.030,"sct2os5",...)` to convert a SNOMED procedure code to the corresponding OS5 (CPT) code. If no mapping exists, the procedure cannot be filed and the loader returns “Code not mapped.”
- **End-to-end flow:** SNOMED procedure code → `$$MAP^SYNDHPMP("sct2os5", DHPSCT)` → OS5 code → `PROCDATA("PROCEDURE",1,"PROCEDURE")` → `DATA2PCE^PXAI` → V CPT (#9000010.18).

## Summary

| Term    | Meaning |
|--------|---------|
| **OS5** | Open Source 5-digit codes: the procedure code system/format used by PCE (effectively CPT/file 81). |
| **OS5 ↔ SNOMED** | OS5 codes are mapped to SNOMED codes; the SNOMED code’s display text is the text used for the OS5 code. |
| **sct2os5** | Mapping from SNOMED CT procedure codes to OS5 (CPT) codes for PCE ingest. |
| **Why it matters** | Without an sct2os5 entry for a given SNOMED code, that procedure will not load into VistA (e.g., “Code X not mapped”). |

For Synthea and other SNOMED-based feeds, expanding the **sct2os5** mapping (and maintaining it in `^SYN(2002.030,"sct2os5",...)`) is what allows more procedure codes to file successfully into PCE as OS5/CPT procedures.
