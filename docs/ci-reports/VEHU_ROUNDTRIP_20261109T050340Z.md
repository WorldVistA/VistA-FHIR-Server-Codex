# VEHU round trip — 20261109T050340Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261109T050340Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@31488a9`, loader `vaready-wd-compat@85daa9b`, rehmp `refactoring-ehmp@6d50d63`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@49afbf9`
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
| L5 fixed | PASS | dfn=101077 loadStatus=partial; ok/total: CarePlan 3/3, Condition 31/31, DocumentReference 45/45, Encounter 45/45, Immunization 13/13, Lab 441/460, Medication 15/15, Observation 73/73, Procedure 137/137, Smoking 10/10; readback 583/1009 entries, 16/19 types  |
| L5 random seed | INFO | seed=859 Arnulfo253_Ondricka197_b3fee293-801e-308c-e3ba-667d2ef93e2c.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: CarePlan 1/1, Condition 19/19, DocumentReference 16/16, Encounter 16/16, Immunization 11/11, Lab 137/140, Observation 43/43, Procedure 45/45, Smoking 6/6; readback 332/350 entries, 15/16 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L5 PCE ICD date | PASS | 0 conditions rejected as an inactive ICD code |
| L6 cohort load | PASS | 20 patients in 299s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.3 (3952/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |
| L6 PCE ICD date | PASS | 0 conditions rejected as an inactive ICD code |

**VEHU ROUNDTRIP OK (L0–L6)**
