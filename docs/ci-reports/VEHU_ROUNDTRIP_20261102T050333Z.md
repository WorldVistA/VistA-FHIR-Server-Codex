# VEHU round trip — 20261102T050333Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261102T050333Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@ea2c78a`, loader `vaready-wd-compat@85daa9b`, rehmp `refactoring-ehmp@6d50d63`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@49afbf9`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261101T050333Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=220 S=441 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1 ENCODER=PLUGIN; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 2/2, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 105/79 entries, 13/8 types  |
| L5 fixed | FAIL | dfn=101077 loadStatus=partial; ok/total: CarePlan 3/3, Condition 28/33, DocumentReference 33/33, Encounter 33/33, Immunization 13/13, Lab 257/263, Medication 9/9, Observation 79/79, Procedure 121/121, Smoking 11/11; readback 530/723 entries, 16/19 types FAIL Condition error rate 5/33 > 10%  |
| L5 random seed | INFO | seed=96081 Alva958_Kristan816_Schneider199_a5e946f1-dc12-f1ca-76a3-caa2a1784445.json |
| L5 random | FAIL | dfn=101078 loadStatus=partial; ok/total: CarePlan 9/9, Condition 44/64, DocumentReference 63/63, Encounter 63/63, Immunization 13/13, Lab 369/381, Medication 160/160, Observation 108/108, Procedure 295/295, Smoking 15/15; readback 706/1671 entries, 16/19 types FAIL Condition error rate 20/64 > 10%  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | FAIL | 20 patients, 0 HTTP failures, 285s; patients=20 loadStatus={'partial': 16, 'error': 3, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 80.7 (468/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.3 (3952/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249) FAIL Condition 80.7 < baseline 98.3 - 2.0  |

**VEHU ROUNDTRIP FAILED**
