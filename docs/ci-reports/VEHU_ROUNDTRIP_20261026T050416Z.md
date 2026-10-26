# VEHU round trip — 20261026T050416Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261026T050416Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@a6bae31+dirty`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@91bd253`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@835b4c7`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261025T050353Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=220 S=441 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1 ENCODER=PLUGIN; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 2/2, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 105/79 entries, 13/8 types  |
| L5 fixed | FAIL | dfn=101077 loadStatus=loaded; ok/total: CarePlan 4/4, Condition 43/50, DocumentReference 75/75, Encounter 75/75, Immunization 13/13, Lab 181/188, Medication 30/30, Observation 100/100, Procedure 155/155, Smoking 14/14; readback 619/967 entries, 16/19 types FAIL Condition error rate 7/50 > 10%  |
| L5 random seed | INFO | seed=91306 Margarito178_Senger904_51097012-8c43-4154-b464-8492373221d8.json |
| L5 random | FAIL | dfn=101078 loadStatus=partial; ok/total: CarePlan 1/1, Condition 20/28, DocumentReference 28/28, Encounter 28/28, Immunization 13/13, Lab 236/243, Medication 6/6, Observation 70/70, Procedure 97/97, Smoking 10/10; readback 437/625 entries, 14/17 types FAIL Condition error rate 8/28 > 10%  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | FAIL | 20 patients, 0 HTTP failures, 321s; patients=20 loadStatus={'partial': 16, 'error': 3, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 80.7 (468/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 84.8 (3926/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249) FAIL Condition 80.7 < baseline 98.3 - 2.0  |

**VEHU ROUNDTRIP FAILED**
