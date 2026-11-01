# VEHU round trip — 20261101T050333Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261101T050333Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@9b60397`, loader `vaready-wd-compat@c3cd269`, rehmp `refactoring-ehmp@6d50d63`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@49afbf9`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261031T050340Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=220 S=441 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1 ENCODER=PLUGIN; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 2/2, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 105/79 entries, 13/8 types  |
| L5 fixed | FAIL | dfn=101077 loadStatus=partial; ok/total: CarePlan 3/3, Condition 28/33, DocumentReference 33/33, Encounter 33/33, Immunization 13/13, Lab 256/263, Medication 9/9, Observation 79/79, Procedure 121/121, Smoking 11/11; readback 530/723 entries, 16/19 types FAIL Condition error rate 5/33 > 10%  |
| L5 random seed | INFO | seed=9656 Lawrence741_Johnston597_f008e11c-6179-76d0-1e52-72651ef3bc75.json |
| L5 random | FAIL | dfn=101078 loadStatus=partial; ok/total: Allergy 4/4, CarePlan 4/4, Condition 26/29, DocumentReference 29/29, Encounter 29/29, Immunization 19/19, Lab 127/138, Medication 19/19, Observation 84/84, Procedure 110/110, Smoking 10/10; readback 437/596 entries, 17/20 types FAIL Condition error rate 3/29 > 10%  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | FAIL | 20 patients, 0 HTTP failures, 313s; patients=20 loadStatus={'partial': 16, 'error': 3, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 80.7 (468/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 84.8 (3926/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249) FAIL Condition 80.7 < baseline 98.3 - 2.0  |

**VEHU ROUNDTRIP FAILED**
