# VEHU round trip — 20260930T054452Z

Image `worldvista/vehu:latest`, container `ci-vehu-20260930T054452Z`, base `http://127.0.0.1:19091`, levels 0–10, encoder `PLUGIN`.

- sources: codex `master@a11c1db+dirty`, loader `vaready-wd-compat@666bda6`, rehmp `refactoring-ehmp@a20ff4c`, CPRS-on-FHIR `docs/arch-synthesis-harness-specs-20260510@af1b217`
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
| L5 fixed | PASS | dfn=101077 loadStatus=partial; ok/total: CarePlan 3/3, Condition 38/41, DocumentReference 37/37, Encounter 37/37, Immunization 13/13, Lab 261/266, Medication 14/14, Observation 84/84, Procedure 132/132, Smoking 12/12; readback 540/794 entries, 13/19 types  |
| L5 random seed | INFO | seed=47373 Shelton25_Beatty507_a24574d4-1511-82da-d885-d081f2af873f.json |
| L5 random | PASS | dfn=101078 loadStatus=partial; ok/total: Condition 9/9, DocumentReference 9/9, Encounter 9/9, Immunization 4/4, Lab 54/56, Observation 22/22, Procedure 13/13, Smoking 3/3; readback 126/145 entries, 13/11 types  |
| L5 CFH-WRITE-001 | PASS | 13 assertions green (dfn=101077) |
| L6 cohort load | PASS | 20 patients in 282s; patients=20 loadStatus={'partial': 18, 'error': 1, 'loaded': 1} ok%: Allergy 100.0 (27/27), CarePlan 100.0 (54/54), Condition 98.3 (570/580), DocumentReference 100.0 (745/745), Encounter 100.0 (745/745), Immunization 100.0 (341/341), Lab 85.7 (3971/4631), Medication 100.0 (417/417), Observation 100.0 (2008/2008), Procedure 100.0 (2390/2391), Smoking 100.0 (249/249)  |
| L7 UI | PASS | 5 UI paths 200; CPRS demo serves 9b486e8-dirty (= local dist) |
| L7 CPRS dist age | INFO | local dist built from 9b486e8-dirty; rehmp demo HEAD is aeecc17 (rebuild: cd rehmp/ehmp-ui/rehmp-cprs-demo && npm run build) |
| L7 rehmp-smoke | PASS | rehmp smoke complete |
| L8 population (C0X) | PASS | populationIndexed=23; SPARQL IPP: CMS165v14=4 CMS122v14=0 CMS130v14=7 CMS125v14=5 CMS138v14=16 CMS2v15=16  |
| L8 smoke-quality-host | PASS | 28 checks |
| L9 quality (cds1 CQL, JSNE) | PASS | 5/6 measures evaluated by cds1; golden table not frozen yet (awaiting cohort review) |
| L9 DEQM summary | PASS | 5 DEQM Summary MeasureReports built from L9 counts pass check-deqm-summary.py |
| L10 restart | PASS | back after docker restart; fixed dfn=101077 reads back 545 entries (strict JSON) |
| L10 reinstall | PASS | full reinstall OK, 124 routes (unchanged), populationIndexed 23 kept |

## L9 measures (cds1 official CQL over the C0X IPP cohort)

| Measure | C0X IPP DFNs | IPP | DENOM | NUMER | DENEX | Reeval |
|---|---:|---:|---:|---:|---:|---|
| CMS165v14 | 4 | 3 | 3 | 2 | 0 | accept=200 status=done |
| CMS122v14 | 0 | - | - | - | - | empty C0X IPP |
| CMS130v14 | 7 | 5 | 5 | 4 | 0 | accept=200 status=done |
| CMS125v14 | 5 | 4 | 4 | 0 | 0 | accept=200 status=done |
| CMS138v14 | 16 | 8 | 8 | 8 | 0 | accept=200 status=done |
| CMS2v15 | 16 | 10 | 10 | 0 | 0 | accept=200 status=done |

**VEHU ROUNDTRIP OK (L0–L10)**
