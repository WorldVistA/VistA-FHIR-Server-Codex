# VEHU round trip — 20261002T050433Z

Image `worldvista/vehu:latest`, container `ci-vehu-20261002T050433Z`, base `http://127.0.0.1:19091`, levels 0–6, encoder `PLUGIN`.

- sources: codex `master@985b6dc`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@f2b60af`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@af1b217`
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
| L5 fixed | PASS | dfn=101077 loadStatus=partial; ok/total: CarePlan 2/2, Condition 43/45, DocumentReference 35/35, Encounter 35/35, Immunization 14/14, Lab 260/264, Medication 11/11, Observation 78/78, Procedure 111/111, Smoking 11/11; readback 503/732 entries, 13/19 types  |
| L5 random seed | INFO | seed=17740 Del587_Reinger292_300a85bc-b7ee-a1fc-232c-7d465021dd30.json |
| L5 random | FAIL | dfn=101078 loadStatus=partial; ok/total: Allergy 1/1, CarePlan 1/1, Condition 8/9, DocumentReference 17/17, Encounter 17/17, Immunization 26/26, Lab 44/44, Medication 7/7, Observation 104/104, Procedure 13/13, Smoking 11/11; readback 207/306 entries, 15/18 types FAIL Condition error rate 1/9 > 10%  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | PASS | 20 patients in 284s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.7 (3971/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |

**VEHU ROUNDTRIP FAILED**
