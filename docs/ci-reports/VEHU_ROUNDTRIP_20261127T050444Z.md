# VEHU round trip — 20261127T050444Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261127T050444Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@de9e7e9+dirty`, loader `vaready-wd-compat@85daa9b`, rehmp `refactoring-ehmp@515db2c`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@49afbf9`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=220 S=441 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1 ENCODER=PLUGIN; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 2/2, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 105/79 entries, 13/8 types  |
| L5 fixed | PASS | dfn=101077 loadStatus=partial; ok/total: CarePlan 5/5, Condition 42/44, DocumentReference 62/62, Encounter 62/62, Immunization 13/13, Lab 559/581, Medication 67/67, Observation 92/92, Procedure 187/187, Smoking 10/10; readback 722/1430 entries, 16/19 types  |
| L5 random seed | INFO | seed=56129 Buena501_Nienow652_d978b61a-ba78-1df6-bcda-e96b3f9fc8bc.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: CarePlan 2/2, Condition 41/43, DocumentReference 42/42, Encounter 42/42, Immunization 13/13, Lab 131/137, Medication 13/13, Observation 71/71, Procedure 123/123, Smoking 10/10; readback 451/647 entries, 17/19 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L5 PCE ICD date | PASS | 0 conditions rejected as an inactive ICD code |
| L6 cohort load | PASS | 20 patients in 290s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.3 (3952/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |
| L6 PCE ICD date | PASS | 0 conditions rejected as an inactive ICD code |

**VEHU ROUNDTRIP OK (L0–L6)**
