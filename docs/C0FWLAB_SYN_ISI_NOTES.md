# C0FWLAB SYN/ISI notes (2026-07-18)

## Intent

Restore lab writeback for C0FW `/updatepatient` and Quality AI Consult by reusing
the proven Synthea path instead of inventing a native accession engine.

## Call chain

```
Observation (category=laboratory)
  → DOMAIN^C0FWDOM = Lab
  → LOAD^C0FWLAB
  → DUZ^C0FWCTX / IO^C0FWCTX
  → LABADD^SYNDHP63
  → $$LAB^ISIIMP12
  → ^LR / #60
  → readback GETLAB^C0FHIRL / RR^LR7OR1
```

## Built-in LOINC aliases

| LOINC   | VistA #60 name   |
| ------- | ---------------- |
| 4548-4  | HEMOGLOBIN A1C   |
| 17856-6 | HEMOGLOBIN A1C   |
| 17855-8 | HEMOGLOBIN A1C   |
| 4549-2  | HEMOGLOBIN A1C   |

`SYNQLDM` in VistA-FHIR-Data-Loader was also updated for `4548-4` / `4549-2`.

## Out of scope for this slice

- DiagnosticReport lab panels (`SYNFPAN`)
- Medications
- Procedures
- RPMS Lab policy (still deferred / `off` on RPMS profile)

## Smoke evidence

Direct `LABADD^SYNDHP63` on `fhirdev22` for DFN `101090` with LOINC `4548-4`,
value `7.2`, location `GENERAL MEDICINE`, sample `BLOOD` returned `RETSTA=1` and
created `^DPT(101090,"LR")=809` (after setting `DUZ(2)=500`). Lab package printed
rollover warnings but accession still completed.

HTTP `updatepatient` / Quality AI Consult apply-review smoke should be confirmed
in the morning using the deployed `C0FWLAB` (ensures web DUZ/IO context path).
