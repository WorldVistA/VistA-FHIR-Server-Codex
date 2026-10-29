# VEHU round trip — 20261029T050345Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261029T050345Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@9b60397`, loader `vaready-wd-compat@c3cd269`, rehmp `refactoring-ehmp@6d50d63`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@49afbf9`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261028T050344Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=220 S=441 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1 ENCODER=PLUGIN; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 2/2, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 105/79 entries, 13/8 types  |
| L5 fixed | FAIL | dfn=101077 loadStatus=loaded; ok/total: CarePlan 5/5, Condition 42/49, DocumentReference 32/32, Encounter 32/32, Immunization 13/13, Lab 133/138, Medication 6/6, Observation 77/77, Procedure 134/134, Smoking 10/10; readback 466/606 entries, 17/19 types FAIL Condition error rate 7/49 > 10%  |
| L5 random seed | INFO | seed=50474 Carmen818_Leiva147_417329b0-2499-6309-4619-bf0237f704a2.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: CarePlan 5/5, Condition 23/25, DocumentReference 48/48, Encounter 48/48, Immunization 8/8, Lab 158/163, Medication 8/8, Observation 29/29, Procedure 110/110, Smoking 4/4; readback 487/584 entries, 17/19 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | FAIL | 20 patients, 0 HTTP failures, 319s; patients=20 loadStatus={'partial': 16, 'error': 3, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 80.7 (468/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 84.8 (3926/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249) FAIL Condition 80.7 < baseline 98.3 - 2.0  |

**VEHU ROUNDTRIP FAILED**
