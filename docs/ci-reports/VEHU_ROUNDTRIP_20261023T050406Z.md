# VEHU round trip — 20261023T050406Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261023T050406Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@18ade63+dirty`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@91bd253`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@835b4c7`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261022T050404Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=221 S=442 I=3; F baseline=83 new=0 |
| L3 encoder | FAIL | SMOKE: PLUGIN=1 PATH=JSNE WHY=encoder=JSNE JSNE=196 FENC=196 ORACLE OK (joined strings match)  |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | FAIL | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 0/15, DocumentReference 2/2, Encounter 0/1, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 73/78 entries, 12/8 types FAIL Condition error rate 15/15 > 10% FAIL core types missing on readback: Condition  |
| L5 fixed | FAIL | dfn=101077 loadStatus=error; ok/total: CarePlan 3/3, Condition 21/28, DocumentReference 40/40, Encounter 5/40, Immunization 13/13, Lab 441/462, Medication 38/38, Observation 70/70, Procedure 86/86, Smoking 10/10; readback 527/982 entries, 16/19 types FAIL Condition error rate 7/28 > 10% FAIL Encounter error rate 35/40 > 10%  |
| L5 random seed | INFO | seed=32106 Elise948_Hodkiewicz467_007a7a79-b0f9-4fe7-0f0c-4473fbfd7bf8.json |
| L5 random | PASS | dfn=101078 loadStatus=loaded; ok/total: CarePlan 2/2, Condition 29/30, DocumentReference 44/44, Encounter 43/44, Immunization 14/14, Lab 125/136, Medication 13/13, Observation 59/59, Procedure 141/141, Smoking 7/7; readback 509/627 entries, 16/19 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | FAIL | 20 patients, 0 HTTP failures, 323s; patients=20 loadStatus={'partial': 15, 'error': 4, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 80.7 (468/580), DocumentReference 100.0 (745/745), Encounter 98.3 (732/745), Immunization 100.0 (341/341), Lab 84.2 (3897/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249) FAIL Condition 80.7 < baseline 98.3 - 2.0  |

**VEHU ROUNDTRIP FAILED**
