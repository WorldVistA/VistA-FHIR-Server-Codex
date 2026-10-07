# VEHU round trip — 20261007T050925Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261007T050925Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@5572eca`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@3ffe72d`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@835b4c7`
- image `worldvista/vehu:latest` digest `sha256:022a783490d9`, `YottaDB r2.06 Linux x86_64`

| Stage | Result | Detail |
|---|---|---|
| L0 boot | PASS | YottaDB r2.06 Linux x86_64, image sha256:022a783490d9 |
| L1 web listener | PASS | vendored M-Web-Server 0.1.4, ^%webhome=/home/vehu/www/;image init starts %webreq on container start (_webreq.m in p/);running; /ping 200 |
| L1 restart | PASS | docker restart -> listener running, /fhir/metadata 200 (image init) |
| L2 code install | PASS | 164 routine files copied+touched;162 routines linked, 0 stale, 124 routes; /fhir/metadata 200 |
| L2 XINDEX | PASS | XINDEX 129 routines with findings: F=83 E=0 W=221 S=438 I=3; F baseline=83 new=0 |
| L3 encoder | PASS | $&c0rgenc.ping=1; SMOKE^C0RGFENCT PATH=PLUGIN, ORACLE OK |
| L4 maps + flags | PASS | OS5=1041 GRAPHLABS=1 ENCODER=PLUGIN; 10 SCT->OS5 probes match |
| L5 john | PASS | dfn=101076 loadStatus=error; ok/total: Allergy 2/2, Condition 15/15, DocumentReference 2/2, Encounter 1/1, Lab 19/22, Medication 14/14, Observation 16/16, Procedure 5/5; readback 102/78 entries, 13/8 types  |
| L5 fixed | PASS | dfn=101077 loadStatus=loaded; ok/total: CarePlan 2/2, Condition 36/36, DocumentReference 35/35, Encounter 35/35, Immunization 13/13, Lab 145/149, Medication 6/6, Observation 77/77, Procedure 125/125, Smoking 11/11; readback 419/604 entries, 14/17 types  |
| L5 random seed | INFO | seed=50036 Tosha401_Dooley940_4c22f4eb-c621-b9dc-83e0-275d1d40cda9.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: Allergy 10/10, CarePlan 4/4, Condition 20/21, DocumentReference 100/100, Encounter 100/100, Immunization 18/18, Lab 172/173, Medication 37/37, Observation 89/89, Procedure 149/150, Smoking 11/11; readback 553/1024 entries, 15/20 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | PASS | 20 patients in 292s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.7 (3971/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |

**VEHU ROUNDTRIP OK (L0–L6)**
