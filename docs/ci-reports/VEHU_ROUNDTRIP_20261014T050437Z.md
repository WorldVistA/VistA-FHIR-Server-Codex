# VEHU round trip — 20261014T050437Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261014T050437Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@7d0abd3`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@d359113`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@835b4c7`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 cleanup | INFO | removed previous lane container(s): ci-vehu-20261013T050821Z  |
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 165 routine files copied+touched;163 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 130 routines with findings: F=83 E=0 W=221 S=442 I=3; F baseline=83 new=0 |
| L3 encoder | FAIL | SMOKE: PLUGIN=1 PATH=JSNE WHY=encoder=JSNE JSNE=196 FENC=196 ORACLE OK (joined strings match)  |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 1/1, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 104/78 entries, 13/8 types  |
| L5 fixed | PASS | dfn=101077 loadStatus=partial; ok/total: CarePlan 6/6, Condition 47/48, DocumentReference 58/58, Encounter 58/58, Immunization 13/13, Lab 560/581, Medication 58/58, Observation 102/102, Procedure 135/135, Smoking 12/12; readback 681/1339 entries, 16/19 types  |
| L5 random seed | INFO | seed=54597 Eliseo499_Weissnat378_9eabf966-86e9-8c0e-4059-cb2f3820b704.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: CarePlan 5/5, Condition 39/39, DocumentReference 70/70, Encounter 70/70, Immunization 13/13, Lab 174/183, Medication 22/22, Observation 76/76, Procedure 140/140, Smoking 7/7; readback 605/832 entries, 16/19 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | PASS | 20 patients in 374s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.7 (3971/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |

**VEHU ROUNDTRIP FAILED**
