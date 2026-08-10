C0FQUAL ; VAMC/GPL - FHIR quality measure dashboards ; 23-JUL-2026
 ;;1.0;C0FHIR PROJECT;;Jul 23, 2026;Build 2
 ;
 ; Active-measure registry and HTML dashboards for:
 ;   GET /fhir-quality-dashboards
 ;   GET /fhir-quality-dashboards/{measure}
 ;   POST /fhir-quality-cohort-delete?measure=
 ;   POST /fhir-quality-cohort-clean?measure=
 ;
 ; ^C0FQUAL("MEAS",CMS)=TITLE^FOCUS^STATUS^NOTE
 ; ^C0FQUAL("META",CMS)=IPP^PERIOD^DOCS^TOOLS^MODE^DENOM^NUMER
 ; ^C0FQUAL("SUM",CMS)=N^IPP^DENOM^NUMER^DENEX^ASOF^COHORT
 ; ^C0FQUAL("POP",CMS,DFN)=IPP^DENOM^NUMER^DENEX^EVIDENCE^MODE
 ;
 Q
 ;
SEED ; Ensure catalog + metadata exist (versioned)
 NEW VER
 SET VER=+$GET(^C0FQUAL(0))
 IF VER<1 DO SEEDMEAS
 IF VER<2 DO SEEDMETA
 IF VER<3 DO SEEDSUM25
 IF VER<4 DO SEED130
 IF VER<5 DO SEED138
 IF VER<6 DO SEED2
 IF VER<7 DO SEED125
 IF VER<8 DO SEEDC0X
 IF VER<9 DO SEED138L
 IF VER<10 DO SEED138A
 IF VER<11 DO SEEDCRIT
 SET ^C0FQUAL(0)=11
 QUIT
 ;
SEEDCRIT ; Brief IPP / DENOM / NUMER criteria (do not mix NUMER into IPP)
 NEW DOCS,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 ; CMS130 — colorectal
 DO SETMETA("CMS130v14","Adults 46-75 at end of MP with a qualifying outpatient encounter.","Calendar year 2026",DOCS,TOOLS,"official-cql","Same as Initial Population.","Appropriate colorectal screening: FOBT/FIT in MP, FIT-DNA within 3 years, flex sig or CT colonography within 5 years, or colonoscopy within 10 years.")
 ; CMS125 — breast
 DO SETMETA("CMS125v14","Female patients 42-74 at end of MP with a qualifying outpatient encounter.","Calendar year 2026",DOCS,TOOLS,"official-cql","Same as Initial Population.","Mammography performed in the lookback window ending at the measurement period.")
 ; CMS165 — BP control
 DO SETMETA("CMS165v14","Adults 18-85 with essential hypertension overlapping the first 6 months of the MP and a qualifying outpatient encounter.","Calendar year 2026",DOCS,TOOLS,"official-cql","Same as Initial Population.","Most recent BP in the MP is controlled (systolic <140 and diastolic <90).")
 ; CMS122 — glycemic (inverse)
 DO SETMETA("CMS122v14","Adults 18-75 with diabetes overlapping the MP and a qualifying encounter.","Calendar year 2026",DOCS,TOOLS,"official-cql","Same as Initial Population.","Most recent glycemic status is >9%, missing, or without a result (poor control; inverse measure).")
 ; CMS138 — tobacco (multi-rate; keep brief)
 DO SETMETA("CMS138v14","Age 12+ at start of MP with qualifying visits (2+ visits or 1 preventive visit).","Calendar year 2026",DOCS,TOOLS,"official-cql","Rate-specific: screened cohort (Denom 1/3) or tobacco users among screened (Denom 2).","Rate-specific: tobacco screening documented (Numer 1), cessation for users (Numer 2), or screening plus cessation when indicated (Numer 3).")
 ; CMS2 — depression
 DO SETMETA("CMS2v15","Age 12+ at start of MP with a qualifying encounter during the MP.","Calendar year 2026",DOCS,TOOLS,"official-cql","Same as Initial Population.","Depression screening with negative result, or positive result with documented follow-up/treatment.")
 QUIT
 ;
SEEDC0X ; 2026-07-26 C0X population IPP → CQL SETPOP aggregates
 DO SETSUM("CMS165v14",23,19,16,15,0,"2026-07-26","c0x IPP→CQL (19 IPP / 16 DENOM / 15 NUMER)")
 DO SETSUM("CMS122v14",9,5,4,0,0,"2026-07-26","c0x IPP→CQL")
 DO SETSUM("CMS130v14",17,13,9,1,0,"2026-07-26","c0x IPP→CQL")
 QUIT
 ;
SEED138L ; 2026-07-29 fhirdev live /fhir CQL for CMS138 curated DFNs
 DO SETSUM("CMS138v14",33,26,0,0,0,"2026-07-29","fhirdev live /fhir CQL (26 IPP / 0 DENOM / 0 NUMER)")
 QUIT
 ;
SEED138A ; 2026-07-29 AssessmentPerformed + Denominator 1 map
 DO SETSUM("CMS138v14",33,26,26,2,0,"2026-07-29","fhirdev live /fhir CQL (26 IPP / 26 DENOM / 2 NUMER; AssessmentPerformed)")
 QUIT
 ;
SEED130 ; Activate CMS130 + selected-18 CQL aggregates (2026-07-25)
 NEW DOCS,IPP,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 SET IPP="Adults 45-75 with qualifying encounter; colorectal cancer screening"
 SET IPP=IPP_" (FOBT/FIT, FIT-DNA, CT colonography, flex sig, colonoscopy) per CMS130v14"
 DO SETMEAS("CMS130v14","Colorectal Cancer Screening","Procedure, Observation, DiagnosticReport","A","First-wave; CQL/VSAC path ready")
 DO SETMETA("CMS130v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS130v14",17,13,9,1,0,"2026-07-26","c0x IPP→CQL")
 QUIT
 ;
SEED138 ; Activate CMS138 + selected-18 CQL aggregates (2026-07-25)
 NEW DOCS,IPP,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 SET IPP="Adults with qualifying encounter; tobacco use screening and cessation"
 SET IPP=IPP_" intervention per CMS138v14"
 DO SETMEAS("CMS138v14","Tobacco Use: Screening and Cessation Intervention","Social-history Observation, Procedure/Medication","A","First-wave; CQL/VSAC path ready")
 DO SETMETA("CMS138v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS138v14",33,26,0,0,0,"2026-07-29","fhirdev live /fhir CQL (26 IPP / 0 DENOM / 0 NUMER)")
 QUIT
 ;
SEED2 ; Activate CMS2 + selected-18 CQL aggregates (2026-07-25)
 NEW DOCS,IPP,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 SET IPP="Adults with qualifying encounter; depression screening (PHQ) and"
 SET IPP=IPP_" follow-up plan per CMS2v15"
 DO SETMEAS("CMS2v15","Screening for Depression and Follow-Up Plan","Observation, Procedure, CarePlan","A","First-wave; CQL/VSAC path ready")
 DO SETMETA("CMS2v15",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS2v15",18,6,6,0,0,"2026-07-25","selected-18 CQL (NUMER=0 in this cohort)")
 QUIT
 ;
SEED125 ; Activate CMS125 + selected-cohort CQL aggregates (2026-07-25)
 NEW DOCS,IPP,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 SET IPP="Women 50-74 with qualifying encounter; breast cancer screening"
 SET IPP=IPP_" (mammography) per CMS125v14"
 DO SETMEAS("CMS125v14","Breast Cancer Screening","Procedure, DiagnosticReport","A","First-wave; CQL/VSAC path ready")
 DO SETMETA("CMS125v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS125v14",9,0,0,0,0,"2026-07-25","selected-9 CQL (IPP/DENOM/NUMER=0 in this cohort)")
 QUIT
 ;
SEEDSUM25 ; Overnight 2026-07-24 CQL re-eval (selected-18) → dashboard aggregates
 NEW DOCS,IPP,TOOLS
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 SET IPP="Age 18-85 at end of MP; essential hypertension diagnosis overlapping"
 SET IPP=IPP_" first 6 months of MP; qualifying adult outpatient encounter during MP"
 DO SETMETA("CMS165v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS165v14",23,19,16,15,0,"2026-07-26","c0x IPP→CQL (19 IPP / 16 DENOM / 15 NUMER)")
 SET IPP="Adults with diabetes and qualifying encounter; glycemic status (HbA1c)"
 SET IPP=IPP_" assessment logic per CMS122v14"
 DO SETMETA("CMS122v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS122v14",9,5,4,0,0,"2026-07-26","c0x IPP→CQL")
 QUIT
 ;
SEEDMEAS ; Default measure catalog
 DO SETMEAS("CMS165v14","Controlling High Blood Pressure","Condition, Encounter, Blood Pressure Observation","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS122v14","Diabetes: Glycemic Status Assessment Greater Than 9%","Condition, Encounter, Observation HbA1c","A","First-wave; Quality AI Consult demo")
 DO SETMEAS("CMS130v14","Colorectal Cancer Screening","Procedure, Observation, DiagnosticReport","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS125v14","Breast Cancer Screening","Procedure, DiagnosticReport","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS22v14","Screening for High Blood Pressure and Follow-Up","Encounter, Blood Pressure, Follow-up","I","CMS147 substitute in 2026 EC ZIP")
 DO SETMEAS("CMS2v15","Screening for Depression and Follow-Up Plan","Observation, Procedure, CarePlan","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS68v15","Documentation of Current Medications","MedicationRequest / medication review","I","First-wave shortlist")
 DO SETMEAS("CMS138v14","Tobacco Use: Screening and Cessation Intervention","Social-history Observation, Procedure/Medication","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS131v14","Diabetes: Eye Exam","Condition, Procedure, Observation","I","First-wave shortlist")
 QUIT
 ;
SEEDMETA ; IPP text, tools, aggregate summary slots
 NEW DOCS,IPP,TOOLS
 SET IPP="Age 18-85 at end of MP; essential hypertension diagnosis overlapping"
 SET IPP=IPP_" first 6 months of MP; qualifying adult outpatient encounter during MP"
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/VSAC_CMS165_RUN_2026-07-23.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 DO SETMETA("CMS165v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS165v14",23,19,16,15,0,"2026-07-26","c0x IPP→CQL (19 IPP / 16 DENOM / 15 NUMER)")
 SET IPP="Adults with diabetes and qualifying encounter; glycemic status (HbA1c)"
 SET IPP=IPP_" assessment logic per CMS122v14"
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/SEPTEMBER_MEASURE_INFERNO_ELEMENT_MAPPING.md"
 SET TOOLS="cqm-execution 4.4.3 + cql-execution 3.3.2 (Project Tacoma);"
 SET TOOLS=TOOLS_" VSAC SVS expansions; FHIR→QDM via fhir-to-qdm-patient.js"
 DO SETMETA("CMS122v14",IPP,"Calendar year 2026",DOCS,TOOLS,"official-cql")
 DO SETSUM("CMS122v14",9,5,4,0,0,"2026-07-26","c0x IPP→CQL")
 QUIT
 ;
NORM(CMS) ;
 QUIT $TRANSLATE($GET(CMS)," ","")
 ;
FIND(CMS) ;
 NEW C,WANT
 DO SEED
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT ""
 IF $DATA(^C0FQUAL("MEAS",CMS)) QUIT CMS
 SET WANT=$$UPCASE^C0FHIR(CMS),C=""
 FOR  SET C=$ORDER(^C0FQUAL("MEAS",C)) QUIT:C=""  IF $$UPCASE^C0FHIR(C)=WANT QUIT
 QUIT C
 ;
SETMEAS(CMS,TITLE,FOCUS,STAT,NOTE) ;
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 ; Preserve Active/Inactive if measure already present
 IF $DATA(^C0FQUAL("MEAS",CMS)),$GET(STAT)="" SET STAT=$PIECE(^C0FQUAL("MEAS",CMS),"^",3)
 IF $GET(STAT)="" SET STAT="I"
 SET ^C0FQUAL("MEAS",CMS)=$GET(TITLE)_"^"_$GET(FOCUS)_"^"_STAT_"^"_$GET(NOTE)
 QUIT
 ;
SETMETA(CMS,IPP,PERIOD,DOCS,TOOLS,MODE,DENOM,NUMER) ;
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 SET ^C0FQUAL("META",CMS)=$GET(IPP)_"^"_$GET(PERIOD)_"^"_$GET(DOCS)_"^"_$GET(TOOLS)_"^"_$GET(MODE)_"^"_$GET(DENOM)_"^"_$GET(NUMER)
 QUIT
 ;
SETSUM(CMS,N,IPP,DENOM,NUMER,DENEX,ASOF,COHORT) ;
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 ; Population nesting: NUMER/DENEX only count inside DENOM (≤ IPP).
 DO NORMPOP(.IPP,.DENOM,.NUMER,.DENEX)
 SET ^C0FQUAL("SUM",CMS)=+$GET(N)_"^"_+IPP_"^"_+DENOM_"^"_+NUMER_"^"_+DENEX_"^"_$GET(ASOF)_"^"_$GET(COHORT)
 QUIT
 ;
SETPOP(CMS,DFN,IPP,DENOM,NUMER,DENEX,EVID,MODE) ; Store per-patient population flags
 SET CMS=$$FIND($GET(CMS)),DFN=+$GET(DFN)
 IF CMS=""!(DFN<1) QUIT 0
 DO NORMPOP(.IPP,.DENOM,.NUMER,.DENEX)
 SET ^C0FQUAL("POP",CMS,DFN)=+IPP_"^"_+DENOM_"^"_+NUMER_"^"_+DENEX_"^"_$GET(EVID)_"^"_$GET(MODE)
 QUIT 1
 ;
NORMPOP(IPP,DENOM,NUMER,DENEX) ; Clamp flags: NUMER/DENEX require DENOM; DENOM requires IPP
 SET IPP=+$GET(IPP),DENOM=+$GET(DENOM),NUMER=+$GET(NUMER),DENEX=+$GET(DENEX)
 IF DENOM,'IPP SET IPP=1
 IF 'IPP SET DENOM=0,NUMER=0,DENEX=0 QUIT
 IF 'DENOM SET NUMER=0,DENEX=0
 QUIT
 ;
ACTIVATE(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 SET $PIECE(^C0FQUAL("MEAS",KEY),"^",3)="A"
 QUIT 1
 ;
DEACTIVATE(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 SET $PIECE(^C0FQUAL("MEAS",KEY),"^",3)="I"
 QUIT 1
 ;
ISACTIVE(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 QUIT ($PIECE($GET(^C0FQUAL("MEAS",KEY)),"^",3)="A")
 ;
TITLE(CMS) ;
 QUIT $PIECE($GET(^C0FQUAL("MEAS",$$FIND($GET(CMS)))),"^",1)
 ;
FOCUS(CMS) ;
 QUIT $PIECE($GET(^C0FQUAL("MEAS",$$FIND($GET(CMS)))),"^",2)
 ;
NOTE(CMS) ;
 QUIT $PIECE($GET(^C0FQUAL("MEAS",$$FIND($GET(CMS)))),"^",4)
 ;
META(CMS,PI) ; Piece of META node
 QUIT $PIECE($GET(^C0FQUAL("META",$$FIND($GET(CMS)))),"^",+$GET(PI))
 ;
SUM(CMS,PI) ;
 QUIT $PIECE($GET(^C0FQUAL("SUM",$$FIND($GET(CMS)))),"^",+$GET(PI))
 ;
POP(CMS,DFN,PI) ;
 QUIT $PIECE($GET(^C0FQUAL("POP",$$FIND($GET(CMS)),+$GET(DFN))),"^",+$GET(PI))
 ;
HASPOP(CMS,DFN) ;
 QUIT $DATA(^C0FQUAL("POP",$$FIND($GET(CMS)),+$GET(DFN)))
 ;
YN(V) ; 1/0/empty → Yes/No/—
 IF $GET(V)="" QUIT "—"
 QUIT $SELECT(+V:"Yes",1:"No")
 ;
COUNTAC() ;
 NEW CMS,N
 DO SEED
 SET N=0,CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  IF $$ISACTIVE(CMS) SET N=N+1
 QUIT N
 ;
SUMMARY(RTN) ; HTML summary of active measures
 NEW CMS,FOCUS,N,NOTE,TITLE,URL,IPP,DENOM,NUMER,RATE
 DO SEED
 KILL RTN
 DO HDR(.RTN,"FHIR Quality Dashboards","Active quality measures for this system")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Each measure opens a dashboard with population flags, IPP criteria, CQM tooling, and patient links (FHIR browser, rehmp, AI Consult).</p>")
 DO ADDLN^C0FHIR(.RTN,"<div class=""links"">")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-dashboard"">FHIR dashboard</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-dashboards?view=all"">All catalog measures</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-reporting"">Quality reporting (DEQM)</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/altfhir/metadata"">/altfhir metadata</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir/metadata"">/fhir metadata</a>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 SET N=$$COUNTAC()
 DO ADDLN^C0FHIR(.RTN,"<h2>Active measures ("_N_")</h2>")
 IF N<1 DO  GOTO SUMDONE
 . DO ADDLN^C0FHIR(.RTN,"<p>No active measures. Activate with ACTIVATE^C0FQUAL(""CMS165v14"").</p>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Measure</th><th>Summary (IPP/DENOM/NUMER)</th><th>Rate</th><th>Mode</th><th></th></tr>")
 SET CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  DO
 . IF '$$ISACTIVE(CMS) QUIT
 . SET TITLE=$$TITLE(CMS)
 . SET IPP=$$SUM(CMS,2),DENOM=$$SUM(CMS,3),NUMER=$$SUM(CMS,4)
 . SET RATE=$SELECT(+DENOM>0:$JUSTIFY(NUMER/DENOM*100,0,1)_"%",1:"n/a")
 . SET URL="/fhir-quality-dashboards/"_CMS
 . DO ADDLN^C0FHIR(.RTN,"<tr><td><a href="""_URL_""">"_$$HTMLESC^C0FHIR(CMS)_"</a></td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(TITLE)_"</td>")
 . IF +$$SUM(CMS,1)>0 DO ADDLN^C0FHIR(.RTN,"<td>"_IPP_" / "_DENOM_" / "_NUMER_" <span class=""muted"">(n="_$$SUM(CMS,1)_")</span></td>")
 . ELSE  DO ADDLN^C0FHIR(.RTN,"<td class=""muted"">not evaluated</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(RATE)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR($$META(CMS,5))_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td><a class=""btn"" href="""_URL_""">Open</a></td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
SUMDONE ;
 DO FTR(.RTN)
 QUIT
 ;
CATALOG(RTN) ;
 NEW CMS,FOCUS,NOTE,STAT,TITLE,URL
 DO SEED
 KILL RTN
 DO HDR(.RTN,"FHIR Quality Measure Catalog","All measures registered for this system")
 DO ADDLN^C0FHIR(.RTN,"<div class=""links""><a href=""/fhir-quality-dashboards"">Active summary</a></div>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Status</th><th>Measure</th><th>Focus</th><th>Notes</th><th></th></tr>")
 SET CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  DO
 . SET TITLE=$$TITLE(CMS),FOCUS=$$FOCUS(CMS),NOTE=$$NOTE(CMS)
 . SET STAT=$PIECE($GET(^C0FQUAL("MEAS",CMS)),"^",3)
 . SET URL="/fhir-quality-dashboards/"_CMS
 . DO ADDLN^C0FHIR(.RTN,"<tr><td>"_$$HTMLESC^C0FHIR(CMS)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$SELECT(STAT="A":"Active",1:"Inactive")_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(TITLE)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(FOCUS)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(NOTE)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td><a href="""_URL_""">Open</a></td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
 DO FTR(.RTN)
 QUIT
 ;
MEASURE(RTN,CMS) ; HTML single-measure dashboard
 NEW CNT,DFN,FOCUS,IEN,NAME,NOTE,ROOT,ROW,STAT,TITLE,RAW
 NEW AURL,BURL,CURL,FURL,LURL,RURL
 NEW IPP,DENOM,NUMER,DENEX,EVID,MODE,FLAG
 DO SEED
 SET RAW=$$NORM($GET(CMS))
 SET CMS=$$FIND(RAW)
 KILL RTN
 IF RAW=""!($$UPCASE^C0FHIR(RAW)="ALL") DO SUMMARY(.RTN) QUIT
 IF CMS="" DO  QUIT
 . DO HDR(.RTN,"Measure not found",RAW)
 . DO ADDLN^C0FHIR(.RTN,"<p>Unknown measure <code>"_$$HTMLESC^C0FHIR(RAW)_"</code>.</p>")
 . DO ADDLN^C0FHIR(.RTN,"<p><a href=""/fhir-quality-dashboards"">Back to active measures</a></p>")
 . DO FTR(.RTN)
 SET TITLE=$$TITLE(CMS),FOCUS=$$FOCUS(CMS),NOTE=$$NOTE(CMS)
 SET STAT=$PIECE($GET(^C0FQUAL("MEAS",CMS)),"^",3)
 DO HDR(.RTN,CMS_" — "_TITLE,"Single-measure quality dashboard")
 DO ADDLN^C0FHIR(.RTN,"<div class=""links"">")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-dashboards"">All active measures</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-dashboard"">FHIR dashboard</a>")
 SET CURL="/filesystem/c0x/index.html?measure="_CMS
 DO ADDLN^C0FHIR(.RTN,"<a href="""_CURL_""">C0X population IPP</a>")
 SET CURL="/filesystem/quality/measurereports/"_CMS_"/summary-deqm.json"
 DO ADDLN^C0FHIR(.RTN,"<a href="""_CURL_""">DEQM Summary MeasureReport</a>")
 SET CURL="/filesystem/quality/measurereports/"_CMS_"/summary.json"
 DO ADDLN^C0FHIR(.RTN,"<a href="""_CURL_""">SETPOP Summary MeasureReport</a>")
 SET CURL="/filesystem/quality/measurereports/"_CMS_"/index.html"
 DO ADDLN^C0FHIR(.RTN,"<a href="""_CURL_""">MeasureReport index</a>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO MHEAD(.RTN,CMS,STAT,FOCUS,NOTE)
 ; Curated CQL cohort rows from ^C0FQUAL("POP") — always listed first
 DO ADDLN^C0FHIR(.RTN,"<h2>Curated CQL cohort</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Per-DFN flags from SETPOP^C0FQUAL (selected-18 / showcase CQL).</p>")
 DO ADDLN^C0FHIR(.RTN,"<p>")
 DO ADDLN^C0FHIR(.RTN,"<button type=""button"" class=""btn"" id=""cleanCohortBtn"" title=""Remove POP rows with IPP=No after CQL re-eval"">Clean non-IPP</button> ")
 DO ADDLN^C0FHIR(.RTN,"<button type=""button"" class=""btn btn-danger"" id=""deleteCohortBtn"" title=""Delete all curated POP rows for this measure"">Delete cohort</button> ")
 DO ADDLN^C0FHIR(.RTN,"<span id=""cohortActionStatus"" class=""muted""></span></p>")
 DO ADDLN^C0FHIR(.RTN,"<script>")
 DO ADDLN^C0FHIR(.RTN,"(function(){")
 DO ADDLN^C0FHIR(.RTN,"function go(path,confirmMsg){var s=document.getElementById('cohortActionStatus');")
 DO ADDLN^C0FHIR(.RTN,"if(!confirm(confirmMsg))return;")
 DO ADDLN^C0FHIR(.RTN,"s.textContent='working…';")
 DO ADDLN^C0FHIR(.RTN,"fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})")
 DO ADDLN^C0FHIR(.RTN,".then(function(r){return r.text().then(function(t){var j={};try{j=JSON.parse(t)}catch(e){j={status:'error',message:t.slice(0,200)}};")
 DO ADDLN^C0FHIR(.RTN,"if(!r.ok||j.status==='error'){s.textContent='error: '+(j.message||('HTTP '+r.status));return;}")
 DO ADDLN^C0FHIR(.RTN,"s.textContent=(j.message||j.status||'ok')+' — reloading…'; setTimeout(function(){location.reload();},600);});})")
 DO ADDLN^C0FHIR(.RTN,".catch(function(e){s.textContent='error: '+e;});}")
 DO ADDLN^C0FHIR(.RTN,"var c=document.getElementById('cleanCohortBtn');")
 DO ADDLN^C0FHIR(.RTN,"if(c)c.addEventListener('click',function(){go('/fhir-quality-cohort-clean?measure="_CMS_"','Remove patients not in IPP from the curated cohort for "_CMS_"?');});")
 DO ADDLN^C0FHIR(.RTN,"var d=document.getElementById('deleteCohortBtn');")
 DO ADDLN^C0FHIR(.RTN,"if(d)d.addEventListener('click',function(){go('/fhir-quality-cohort-delete?measure="_CMS_"','DELETE the entire curated POP cohort for "_CMS_"? This cannot be undone (rebuild via SETPOP / seed / re-eval).');});")
 DO ADDLN^C0FHIR(.RTN,"})();")
 DO ADDLN^C0FHIR(.RTN,"</script>")
 DO ADDLN^C0FHIR(.RTN,"<table>")
 DO ADDLN^C0FHIR(.RTN,"<tr><th>DFN</th><th>Name</th><th>IPP</th><th>DENOM</th><th>NUMER</th><th>DENEX</th><th>Evidence</th><th>MeasureReport</th><th>FHIR browser</th><th>rehmp</th><th>Quality AI Consult</th><th>Synthea bundle</th></tr>")
 SET ROOT=$$GSROOT^C0FHIR(),CNT=0,DFN=0
 FOR  SET DFN=$ORDER(^C0FQUAL("POP",CMS,DFN)) QUIT:+DFN<1  DO
 . SET CNT=CNT+1
 . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^") IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . SET IPP=$$YN($$POP(CMS,DFN,1)),DENOM=$$YN($$POP(CMS,DFN,2))
 . SET NUMER=$$YN($$POP(CMS,DFN,3)),DENEX=$$YN($$POP(CMS,DFN,4))
 . SET EVID=$PIECE($GET(^C0FQUAL("POP",CMS,DFN)),"^",5)
 . SET IEN=0 IF ROOT'="" SET IEN=+$ORDER(@ROOT@("DFN",DFN,""),-1)
 . SET BURL="/fhir?dfn="_DFN_"&view=browser"
 . SET RURL="/demos/cprs/index.html?dfn="_DFN_"&autoload=dfn&rehmpBase=/rehmp&measure="_CMS
 . SET AURL="/fhir?dfn="_DFN_"&view=browser&source=aiconsult&mode=quality&measure="_CMS
 . SET LURL="/filesystem/quality/measurereports/"_CMS_"/Patient-"_DFN_".json"
 . SET FURL=$SELECT(IEN>0:"/fhir?dfn="_DFN_"&view=browser&source=altfhir&ien="_IEN,1:"")
 . SET ROW="<tr><td>"_DFN_"</td><td>"_$$HTMLESC^C0FHIR(NAME)_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(IPP)_""">"_IPP_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENOM)_""">"_DENOM_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(NUMER)_""">"_NUMER_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENEX)_""">"_DENEX_"</td>"
 . SET ROW=ROW_"<td>"_$$HTMLESC^C0FHIR(EVID)_"</td>"
 . SET ROW=ROW_"<td><a href="""_LURL_""">individual</a></td>"
 . SET ROW=ROW_"<td>"_$$TJBTN(BURL,"fhir",1)_"</td>"
 . SET ROW=ROW_"<td><a href="""_RURL_""">rehmp</a></td>"
 . SET ROW=ROW_"<td>"_$$TJBTN(AURL,"quality ai",1)_"</td>"
 . IF FURL'="" SET ROW=ROW_"<td>"_$$TJBTN(FURL,"synthea",1)_"</td></tr>"
 . ELSE  SET ROW=ROW_"<td class=""muted"">—</td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 IF CNT=0 DO ADDLN^C0FHIR(.RTN,"<tr><td colspan=""12"">No curated POP rows yet. Use SETPOP^C0FQUAL.</td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<h2>Patients (graph source)</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Graph-linked patients (first 250). Flags show when POP is stored for that DFN.</p>")
 IF ROOT="" DO  GOTO MDONE
 . DO ADDLN^C0FHIR(.RTN,"<p>No fhir-intake graph root is available.</p>")
 DO ADDLN^C0FHIR(.RTN,"<table>")
 DO ADDLN^C0FHIR(.RTN,"<tr><th>DFN</th><th>Name</th><th>IPP</th><th>DENOM</th><th>NUMER</th><th>DENEX</th><th>Evidence</th><th>MeasureReport</th><th>FHIR browser</th><th>rehmp</th><th>Quality AI Consult</th><th>Synthea bundle</th></tr>")
 SET CNT=0,DFN=0
 FOR  SET DFN=$ORDER(@ROOT@("DFN",DFN)) QUIT:+DFN<1!(CNT>250)  DO
 . SET IEN=$ORDER(@ROOT@("DFN",DFN,""),-1) QUIT:+IEN<1
 . SET CNT=CNT+1
 . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^") IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . SET FLAG=$$HASPOP(CMS,DFN)
 . IF FLAG DO
 . . SET IPP=$$YN($$POP(CMS,DFN,1))
 . . SET DENOM=$$YN($$POP(CMS,DFN,2))
 . . SET NUMER=$$YN($$POP(CMS,DFN,3))
 . . SET DENEX=$$YN($$POP(CMS,DFN,4))
 . . SET EVID=$PIECE($GET(^C0FQUAL("POP",CMS,DFN)),"^",5)
 . ELSE  SET IPP="—",DENOM="—",NUMER="—",DENEX="—",EVID=""
 . SET BURL="/fhir?dfn="_DFN_"&view=browser"
 . SET RURL="/demos/cprs/index.html?dfn="_DFN_"&autoload=dfn&rehmpBase=/rehmp&measure="_CMS
 . SET AURL="/fhir?dfn="_DFN_"&view=browser&source=aiconsult&mode=quality&measure="_CMS
 . SET LURL="/filesystem/quality/measurereports/"_CMS_"/Patient-"_DFN_".json"
 . SET FURL="/fhir?dfn="_DFN_"&view=browser&source=altfhir&ien="_IEN
 . SET ROW="<tr><td>"_DFN_"</td><td>"_$$HTMLESC^C0FHIR(NAME)_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(IPP)_""">"_IPP_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENOM)_""">"_DENOM_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(NUMER)_""">"_NUMER_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENEX)_""">"_DENEX_"</td>"
 . SET ROW=ROW_"<td>"_$$HTMLESC^C0FHIR(EVID)_"</td>"
 . IF FLAG SET ROW=ROW_"<td><a href="""_LURL_""">individual</a></td>"
 . ELSE  SET ROW=ROW_"<td class=""muted"">—</td>"
 . SET ROW=ROW_"<td>"_$$TJBTN(BURL,"fhir",1)_"</td>"
 . SET ROW=ROW_"<td><a href="""_RURL_""">rehmp</a></td>"
 . SET ROW=ROW_"<td>"_$$TJBTN(AURL,"quality ai",1)_"</td>"
 . SET ROW=ROW_"<td>"_$$TJBTN(FURL,"synthea",1)_"</td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 IF CNT=0 DO ADDLN^C0FHIR(.RTN,"<tr><td colspan=""12"">No graph-linked patients found.</td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
MDONE ;
 DO FTR(.RTN)
 QUIT
 ;
MHEAD(RTN,CMS,STAT,FOCUS,NOTE) ; Measure header cards
 NEW IPP,PERIOD,DOCS,TOOLS,MODE,DENOMB,NUMERB,N,IPPC,DENOMC,NUMERC,DENEXC,ASOF,COHORT,RATE,LINE,MURL
 SET IPP=$$META(CMS,1),PERIOD=$$META(CMS,2),DOCS=$$META(CMS,3)
 SET TOOLS=$$META(CMS,4),MODE=$$META(CMS,5)
 SET DENOMB=$$META(CMS,6),NUMERB=$$META(CMS,7)
 SET N=+$$SUM(CMS,1),IPPC=+$$SUM(CMS,2),DENOMC=+$$SUM(CMS,3)
 SET NUMERC=+$$SUM(CMS,4),DENEXC=+$$SUM(CMS,5)
 SET ASOF=$$SUM(CMS,6),COHORT=$$SUM(CMS,7)
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Status:</strong> "_$SELECT(STAT="A":"Active",1:"Inactive")_"</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Calc mode:</strong> "_$$HTMLESC^C0FHIR(MODE)_"</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Measurement period:</strong> "_$$HTMLESC^C0FHIR(PERIOD)_"</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Primary FHIR focus:</strong> "_$$HTMLESC^C0FHIR(FOCUS)_"</p>")
 IF NOTE'="" DO ADDLN^C0FHIR(.RTN,"<p><strong>Notes:</strong> "_$$HTMLESC^C0FHIR(NOTE)_"</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Population criteria (brief)</h2>")
 IF IPP'="" DO ADDLN^C0FHIR(.RTN,"<p><strong>Initial Population:</strong> "_$$HTMLESC^C0FHIR(IPP)_"</p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">IPP criteria not yet documented for this measure.</p>")
 IF DENOMB'="" DO ADDLN^C0FHIR(.RTN,"<p><strong>Denominator:</strong> "_$$HTMLESC^C0FHIR(DENOMB)_"</p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted""><strong>Denominator:</strong> not yet documented.</p>")
 IF NUMERB'="" DO ADDLN^C0FHIR(.RTN,"<p><strong>Numerator:</strong> "_$$HTMLESC^C0FHIR(NUMERB)_"</p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted""><strong>Numerator:</strong> not yet documented.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card stats"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Current summary results</h2>")
 IF N>0 DO
 . SET RATE=$SELECT(DENOMC>0:$JUSTIFY(NUMERC/DENOMC*100,0,1)_"%",1:"n/a")
 . SET LINE="<p class=""big"">IPP <strong>"_IPPC_"</strong> · DENOM <strong>"_DENOMC_"</strong>"
 . SET LINE=LINE_" · NUMER <strong>"_NUMERC_"</strong> · DENEX <strong>"_DENEXC_"</strong>"
 . SET LINE=LINE_" · rate <strong>"_RATE_"</strong> (n="_N_")</p>"
 . DO ADDLN^C0FHIR(.RTN,LINE)
 . IF ASOF'="" DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">As of "_$$HTMLESC^C0FHIR(ASOF)_"</p>")
 . IF COHORT'="" DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Cohort: "_$$HTMLESC^C0FHIR(COHORT)_"</p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">No aggregate CQL/heuristic summary stored yet for this measure.</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><a href=""/fhir-quality-report?measure="_CMS_""">Live DEQM Summary MeasureReport (current counts)</a>")
 DO ADDLN^C0FHIR(.RTN," · <a href=""/fhir-quality-report?measure="_CMS_"&amp;bundle=1"">Live submission Bundle</a>")
 DO ADDLN^C0FHIR(.RTN," · <a href=""/fhir-quality-reporting"">Reporting pipeline</a></p>")
 SET MURL="/filesystem/quality/measurereports/"_CMS_"/summary-deqm.json"
 DO ADDLN^C0FHIR(.RTN,"<p><a href="""_MURL_""">DEQM Summary MeasureReport (official-cql freeze)</a>")
 SET MURL="/filesystem/quality/measurereports/"_CMS_"/summary.json"
 DO ADDLN^C0FHIR(.RTN," · <a href="""_MURL_""">SETPOP aggregate Summary (DEQM profile)</a>")
 SET MURL="/filesystem/quality/measurereports/"_CMS_"/Bundle-all.json"
 DO ADDLN^C0FHIR(.RTN," · <a href="""_MURL_""">All MeasureReports (Bundle)</a></p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">QRDA-III replacement path: Da Vinci DEQM Summary MeasureReport (STU5). Prefer the official-cql freeze for Connectathon exchange.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Measure calculation</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>CQM tools:</strong> "_$$HTMLESC^C0FHIR(TOOLS)_"</p>")
 IF DOCS'="" DO ADDLN^C0FHIR(.RTN,"<p><a href="""_$$HTMLESC^C0FHIR(DOCS)_""">Documentation of measure calculation</a></p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">No calculation doc link configured.</p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Per-DFN flags: SETPOP^C0FQUAL. MeasureReports from SETPOP_MANIFEST under <a href=""/filesystem/quality/measurereports/index.html"">/filesystem/quality/measurereports/index.html</a> (directory URLs are not listable).</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 ; Official CQL re-eval via cds1 /quality/evaluate-cohort (not AI Consult /analyze)
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Re-evaluate CQL</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Runs official cqm-execution on cds1 for this server's curated POP DFNs (cds1 fetches /fhir when public; updates SETPOP/SETSUM). Separate from AI Consult.</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><button type=""button"" class=""btn"" id=""reevalBtn"">Re-evaluate CQL</button> <span id=""reevalStatus"" class=""muted"">"_$$HTMLESC^C0FHIR($PIECE($GET(^C0FQUAL("REEVAL",CMS)),"^",1))_"</span></p>")
 DO ADDLN^C0FHIR(.RTN,"<script>")
 DO ADDLN^C0FHIR(.RTN,"(function(){var b=document.getElementById('reevalBtn'),s=document.getElementById('reevalStatus');")
 DO ADDLN^C0FHIR(.RTN,"if(!b)return;b.addEventListener('click',async function(){")
 DO ADDLN^C0FHIR(.RTN,"b.disabled=true;s.textContent='starting…';")
 DO ADDLN^C0FHIR(.RTN,"try{var r=await fetch('/fhir-quality-reeval?measure="_CMS_"',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});")
 DO ADDLN^C0FHIR(.RTN,"var t=await r.text(),j={}; try{j=JSON.parse(t)}catch(e){j={status:'error',message:t.slice(0,200)||('HTTP '+r.status)};}")
 DO ADDLN^C0FHIR(.RTN,"if(!r.ok||j.status==='error'){s.textContent='error: '+(j.message||('HTTP '+r.status));b.disabled=false;return;}")
 DO ADDLN^C0FHIR(.RTN,"s.textContent='running… (background)'; var n=0; var iv=setInterval(function(){n++; if(n>90){clearInterval(iv);s.textContent='still running — reload manually';b.disabled=false;return;} location.reload();},3000);")
 DO ADDLN^C0FHIR(.RTN,"}catch(e){s.textContent='error: '+e;b.disabled=false;}});")
 DO ADDLN^C0FHIR(.RTN,"if((s.textContent||'').indexOf('running')===0){b.disabled=true; setTimeout(function(){location.reload();},3000);}")
 DO ADDLN^C0FHIR(.RTN,"})();")
 DO ADDLN^C0FHIR(.RTN,"</script>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 QUIT
 ;
PCLS(V) ; CSS class for Yes/No/—
 IF V="Yes" QUIT "yes"
 IF V="No" QUIT "no"
 QUIT "na"
 ;
QMRHTML(RTN,FILTER) ; Serve MeasureReport index.html (directory URLs hit FILESYS EISDIR)
 NEW CMS,DIR,FILE,OK,TMP
 KILL RTN
 SET CMS=$$TRIM^C0FHIR($GET(FILTER("measure")))
 IF CMS="" SET CMS=$$QMRPATH($GET(HTTPREQ("path")))
 IF $EXTRACT(CMS,$LENGTH(CMS))="/" SET CMS=$EXTRACT(CMS,1,$LENGTH(CMS)-1)
 IF CMS="index.html"!(CMS="index.json") SET CMS=""
 SET DIR=$$QMRDIR()
 IF DIR="" DO  QUIT
 . SET HTTPERR=404
 . SET RTN(1)="MeasureReport filesystem root not found"
 SET FILE=$SELECT(CMS'="":CMS_"/index.html",1:"index.html")
 SET TMP=$NA(^TMP("C0FQMR",$J))
 KILL @TMP
 SET OK=$$FTGOK^C0FHIRWS(DIR,FILE,TMP)
 IF 'OK DO  QUIT
 . SET HTTPERR=404
 . SET RTN(1)="MeasureReport index not found: "_FILE
 MERGE RTN=@TMP
 KILL @TMP
 SET HTTPRSP("mime")="text/html"
 QUIT
 ;
QMRPATH(PATH) ; $$ - measure id from /filesystem/quality/measurereports/{measure}[/]
 NEW REST
 SET PATH=$PIECE($GET(PATH),"?",1)
 IF $EXTRACT(PATH)="/" SET PATH=$EXTRACT(PATH,2,$LENGTH(PATH))
 IF PATH'["filesystem/quality/measurereports" QUIT ""
 SET REST=$PIECE(PATH,"filesystem/quality/measurereports",2)
 IF $EXTRACT(REST)="/" SET REST=$EXTRACT(REST,2,$LENGTH(REST))
 IF $EXTRACT(REST,$LENGTH(REST))="/" SET REST=$EXTRACT(REST,1,$LENGTH(REST)-1)
 IF REST="" QUIT ""
 IF REST["/" QUIT $PIECE(REST,"/") ; measure only; ignore trailing file names
 QUIT REST
 ;
QMRDIR() ; $$ - filesystem root for published MeasureReports
 NEW DIR,HOME
 SET HOME=$ZTRNLNM("HOME")
 IF HOME'="" SET DIR=HOME_"/www/filesystem/quality/measurereports/" IF $$QMRDIRX(DIR) QUIT DIR
 SET DIR="/home/vehu/www/filesystem/quality/measurereports/" IF $$QMRDIRX(DIR) QUIT DIR
 SET DIR="/home/osehra/www/filesystem/quality/measurereports/" IF $$QMRDIRX(DIR) QUIT DIR
 QUIT ""
 ;
QMRDIRX(DIR) ; $$ - true when index.html exists in DIR
 NEW OK,TMP
 SET TMP=$NA(^TMP("C0FQMRX",$J))
 KILL @TMP
 SET OK=$$FTGOK^C0FHIRWS(DIR,"index.html",TMP)
 KILL @TMP
 QUIT +OK
 ;
HDR(RTN,TITLE,SUB) ;
 DO ADDLN^C0FHIR(.RTN,"<!DOCTYPE HTML>")
 DO ADDLN^C0FHIR(.RTN,"<html><head><meta charset=""utf-8""><title>"_$$HTMLESC^C0FHIR(TITLE)_"</title>")
 DO ADDLN^C0FHIR(.RTN,"<style>")
 DO ADDLN^C0FHIR(.RTN,"body{font-family:Arial,Helvetica,sans-serif;margin:24px;line-height:1.45;color:#0f172a;background:#f8fafc}")
 DO ADDLN^C0FHIR(.RTN,"h1{margin:0 0 8px 0;font-size:1.6rem}h2{margin-top:28px;font-size:1.15rem}")
 DO ADDLN^C0FHIR(.RTN,".muted{color:#64748b} .links a{margin-right:12px}")
 DO ADDLN^C0FHIR(.RTN,"table{border-collapse:collapse;width:100%;margin:14px 0;background:#fff}")
 DO ADDLN^C0FHIR(.RTN,"th,td{border:1px solid #cbd5e1;padding:8px;text-align:left;vertical-align:top}th{background:#e2e8f0}")
 DO ADDLN^C0FHIR(.RTN,".btn{display:inline-block;padding:4px 10px;background:#0f766e;color:#fff;text-decoration:none;border-radius:4px;border:0;cursor:pointer}")
 DO ADDLN^C0FHIR(.RTN,".btn-danger{background:#b91c1c}")
 DO ADDLN^C0FHIR(.RTN,".card{background:#fff;border:1px solid #cbd5e1;padding:14px 16px;margin:14px 0;border-radius:6px}")
 DO ADDLN^C0FHIR(.RTN,".stats .big{font-size:1.05rem} .yes{color:#047857;font-weight:600} .no{color:#b91c1c} .na{color:#94a3b8}")
 DO ADDLN^C0FHIR(.RTN,"code{background:#e2e8f0;padding:1px 4px;border-radius:3px}")
 DO ADDLN^C0FHIR(.RTN,"a.tjbtn{display:inline-block;padding:2px 10px;border-radius:999px;background:#0f766e;color:#fff;text-decoration:none;font-size:.8rem;font-weight:600;white-space:nowrap;border:1px solid #0f766e}")
 DO ADDLN^C0FHIR(.RTN,"a.tjbtn:hover{background:#115e59;border-color:#115e59}")
 DO ADDLN^C0FHIR(.RTN,"a.tjbtn .br{opacity:.7;margin-right:5px;font-weight:700}")
 DO ADDLN^C0FHIR(.RTN,"a.tjbtn.lite{background:transparent;color:#0f766e}")
 DO ADDLN^C0FHIR(.RTN,"a.tjbtn.lite:hover{background:#ccfbf1}")
 DO ADDLN^C0FHIR(.RTN,"</style></head><body>")
 DO ADDLN^C0FHIR(.RTN,"<h1>"_$$HTMLESC^C0FHIR(TITLE)_"</h1>")
 IF $GET(SUB)'="" DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">"_$$HTMLESC^C0FHIR(SUB)_"</p>")
 QUIT
 ;
FTR(RTN) ;
 DO ADDLN^C0FHIR(.RTN,"</body></html>")
 QUIT
 ;
TJBTN(URL,LABEL,LITE) ; $$ - pill button for links that open the TJSON browser
 ; Solid teal pill for standalone placement; LITE=1 outline variant for tables.
 NEW TIP
 SET LABEL=$GET(LABEL) IF LABEL="" SET LABEL="TJSON"
 SET TIP="Opens the C0FHIR Browser: resource list + TJSON rendering"
 QUIT "<a class=""tjbtn"_$SELECT(+$GET(LITE):" lite",1:"")_""" href="""_URL_""" title="""_TIP_"""><span class=""br"">{&hellip;}</span>"_$$HTMLESC^C0FHIR(LABEL)_"</a>"
 ;
 ;----- Curated cohort maintenance -----
WSDELCOH(ARGS,BODY,RESULT) ; POST /fhir-quality-cohort-delete?measure=
 IF '$DATA(RESULT) DO WSDELCOH2(.ARGS,.BODY) QUIT ""
 DO WSDELCOH2(.RESULT,.BODY)
 QUIT ""
 ;
WSDELCOH2(OUT,BODY) ; Delete all POP rows for measure (+ clear SUM)
 NEW CMS,N,TMP,ERR
 SET U="^",HTTPRSP("mime")="application/json"
 KILL OUT
 DO SEED
 SET CMS=$$FIND($GET(HTTPARGS("measure")))
 IF CMS="" DO OO^C0FWAIS(.OUT,"error","invalid","Missing or unknown measure") QUIT
 SET N=$$DELPOP(CMS)
 KILL TMP
 SET TMP("status")="ok",TMP("measure")=CMS,TMP("deleted")=+N
 SET TMP("message")="Deleted "_+N_" curated POP row(s) for "_CMS
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 IF $DATA(ERR) DO OO^C0FWAIS(.OUT,"error","exception","Unable to encode delete response") QUIT
 QUIT
 ;
WSCLEAN(ARGS,BODY,RESULT) ; POST /fhir-quality-cohort-clean?measure=
 IF '$DATA(RESULT) DO WSCLEAN2(.ARGS,.BODY) QUIT ""
 DO WSCLEAN2(.RESULT,.BODY)
 QUIT ""
 ;
WSCLEAN2(OUT,BODY) ; Remove POP rows that are not in IPP; RESUM
 NEW CMS,N,TMP,ERR,SUM
 SET U="^",HTTPRSP("mime")="application/json"
 KILL OUT
 DO SEED
 SET CMS=$$FIND($GET(HTTPARGS("measure")))
 IF CMS="" DO OO^C0FWAIS(.OUT,"error","invalid","Missing or unknown measure") QUIT
 SET N=$$CLEANPOP(CMS)
 KILL SUM
 SET SUM("cohort")=$PIECE($GET(^C0FQUAL("SUM",CMS)),"^",7)
 IF SUM("cohort")="" SET SUM("cohort")="clean non-IPP from curated cohort"
 DO RESUM(CMS,.SUM)
 KILL TMP
 SET TMP("status")="ok",TMP("measure")=CMS,TMP("removed")=+N
 SET TMP("n")=+$GET(SUM("n")),TMP("ipp")=+$GET(SUM("ipp"))
 SET TMP("denom")=+$GET(SUM("denom")),TMP("numer")=+$GET(SUM("numer"))
 SET TMP("message")="Removed "_+N_" non-IPP row(s); cohort n="_+$GET(SUM("n"))
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 IF $DATA(ERR) DO OO^C0FWAIS(.OUT,"error","exception","Unable to encode clean response") QUIT
 QUIT
 ;
DELPOP(CMS) ; $$ - kill all POP for measure; clear SUM; return deleted count
 NEW D,N
 SET CMS=$$FIND($GET(CMS))
 IF CMS="" QUIT 0
 SET (D,N)=0
 FOR  SET D=$ORDER(^C0FQUAL("POP",CMS,D)) QUIT:'D  SET N=N+1
 KILL ^C0FQUAL("POP",CMS)
 KILL ^C0FQUAL("SUM",CMS)
 KILL ^C0FQUAL("REEVAL",CMS)
 QUIT N
 ;
CLEANPOP(CMS) ; $$ - kill POP rows with IPP=0; return removed count
 NEW D,N,KILL
 SET CMS=$$FIND($GET(CMS))
 IF CMS="" QUIT 0
 SET D=0 KILL KILL
 FOR  SET D=$ORDER(^C0FQUAL("POP",CMS,D)) QUIT:'D  DO
 . IF +$PIECE($GET(^C0FQUAL("POP",CMS,D)),"^",1) QUIT
 . SET KILL(D)=""
 SET (D,N)=0
 FOR  SET D=$ORDER(KILL(D)) QUIT:'D  KILL ^C0FQUAL("POP",CMS,D) SET N=N+1
 QUIT N
 ;
 ;----- Official CQL re-eval via cds1 quality-eval (not AI Consult) -----
WSREEVAL(ARGS,BODY,RESULT) ; POST /fhir-quality-reeval?measure=
 IF '$DATA(RESULT) DO WSREEVAL2(.ARGS,.BODY) QUIT ""
 DO WSREEVAL2(.RESULT,.BODY)
 QUIT ""
 ;
WSREEVAL2(OUT,BODY) ; Accept reeval; JOB background work (avoids browser/proxy timeouts)
 NEW BASE,CMS,DFN,ERR,INLINE,N,TMP
 SET U="^",HTTPRSP("mime")="application/json"
 KILL OUT
 DO SEED
 SET CMS=$$FIND($GET(HTTPARGS("measure")))
 IF CMS="" DO OO^C0FWAIS(.OUT,"error","invalid","Missing or unknown measure") QUIT
 SET BASE=$$FHIRBASE(.BODY)
 SET INLINE=$$NEEDINLINE(BASE)
 IF $DATA(HTTPARGS("inline"))#2 DO
 . IF +$GET(HTTPARGS("inline")) SET INLINE=1
 . ELSE  SET INLINE=0
 ; Count POP only (do not build bundles on the request thread)
 SET N=0,DFN=0
 FOR  SET DFN=$ORDER(^C0FQUAL("POP",CMS,DFN)) QUIT:'DFN  SET N=N+1
 IF N<1 DO OO^C0FWAIS(.OUT,"error","invalid","No curated POP DFNs for "_CMS) QUIT
 SET ^C0FQUAL("REEVAL",CMS)="running^"_$$NOW^XLFDT_"^"_BASE_"^"_$SELECT(INLINE:1,1:0)_"^"_+N
 ; Background job: large cohorts exceed ~60s edge/proxy limits (Failed to fetch)
 ; DEFAULT=/tmp keeps JOB spawn independent of the listener's cwd (JOBFAIL)
 JOB REEVALJ^C0FQUAL(CMS):(DEFAULT="/tmp")
 KILL TMP
 SET TMP("status")="accepted"
 SET TMP("measure")=CMS
 SET TMP("fhirBase")=BASE
 SET TMP("inlineBundles")=$SELECT(INLINE:1,1:0)
 SET TMP("patients")=+N
 SET TMP("reeval")=$GET(^C0FQUAL("REEVAL",CMS))
 SET TMP("message")="Re-evaluate started in background; reload when status is done."
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 IF $DATA(ERR) DO OO^C0FWAIS(.OUT,"error","exception","Unable to encode reeval response") QUIT
 QUIT
 ;
REEVALJ(CMS) ; Background JOB: cds1 evaluate-cohort → SETPOP/SETSUM
 NEW BASE,DFN,ERR,INLINE,N,PAYLOAD,REQ,RESP,SLOT,SUM,PARTS
 SET CMS=$$FIND($GET(CMS)) QUIT:CMS=""
 SET PARTS=$GET(^C0FQUAL("REEVAL",CMS))
 SET BASE=$PIECE(PARTS,"^",3)
 SET INLINE=+$PIECE(PARTS,"^",4)
 IF BASE="" SET BASE=$$FHIRBASE(.REQ)
 KILL REQ
 SET REQ("measureId")=CMS
 SET REQ("fhirBase")=BASE
 ; Use 0/1 so XLFJSON emits JSON boolean/number — string "false" is truthy in cds1
 SET REQ("inlineBundles")=$SELECT(INLINE:1,1:0)
 IF INLINE DO LOADBND(.REQ,CMS,.N,.ERR)
 ELSE  DO LOADDFNS(.REQ,CMS,.N,.ERR)
 IF $GET(ERR)'="" SET ^C0FQUAL("REEVAL",CMS)="error^"_$$NOW^XLFDT_"^"_$EXTRACT(ERR,1,80) QUIT
 IF +$GET(N)<1 SET ^C0FQUAL("REEVAL",CMS)="error^"_$$NOW^XLFDT_"^no POP rows" QUIT
 DO TOJSON^C0FHIRBU(.REQ,.PAYLOAD,.ERR)
 IF $DATA(ERR) SET ^C0FQUAL("REEVAL",CMS)="error^"_$$NOW^XLFDT_"^encode" QUIT
 DO CALLEVAL(.PAYLOAD,.RESP,.ERR)
 IF $GET(ERR)'="" SET ^C0FQUAL("REEVAL",CMS)="error^"_$$NOW^XLFDT_"^"_$EXTRACT(ERR,1,80) QUIT
 SET SLOT=0
 FOR  SET SLOT=$ORDER(RESP("patients",SLOT)) QUIT:'SLOT  DO
 . SET DFN=+$GET(RESP("patients",SLOT,"dfn"))
 . QUIT:DFN<1
 . DO SETPOP(CMS,DFN,+$GET(RESP("patients",SLOT,"ipp")),+$GET(RESP("patients",SLOT,"denom")),+$GET(RESP("patients",SLOT,"numer")),+$GET(RESP("patients",SLOT,"denex")),"cds1-quality-eval","official-cql")
 ; Always RESUM from clamped POP rows — cds1 summary can count NUMER outside DENOM.
 KILL SUM
 SET SUM("cohort")="cds1 /quality/evaluate-cohort ("_BASE_")"
 DO RESUM(CMS,.SUM)
 SET ^C0FQUAL("REEVAL",CMS)="done^"_$$NOW^XLFDT_"^"_+$GET(SUM("ipp"))_"/"_+$GET(SUM("denom"))_"/"_+$GET(SUM("numer"))_"^"_BASE
 QUIT
 ;
FHIRBASE(BODY) ; $$ - FHIR base for THIS host (audit / override; remote cds1 fetch when public)
 NEW BASE,HOST,PROTO
 ; Explicit overrides first
 SET BASE=$GET(HTTPARGS("fhirBase"))
 IF BASE="" SET BASE=$GET(HTTPARGS("fhirbase"))
 IF BASE="",$DATA(BODY) SET BASE=$GET(BODY("fhirBase"))
 IF BASE="" SET BASE=$GET(^C0FQUAL("FHIRBASE"))
 IF BASE'="" Q $$TRIMSL(BASE)
 ; Derive from inbound request host (gateway / Caddy / direct)
 SET HOST=$$HTTPHOST
 SET PROTO=$GET(HTTPREQ("header","x-forwarded-proto"))
 IF PROTO="" SET PROTO=$GET(HTTPREQ("header","X-Forwarded-Proto"))
 IF PROTO="" SET PROTO=$S($$LOW^XLFSTR(HOST)["localhost":"http",$$LOW^XLFSTR(HOST)["127.0.0.1":"http",HOST[".vistaplex.org":"https",1:"http")
 IF HOST'="",$$LOW^XLFSTR(HOST)'["127.0.0.1",$$LOW^XLFSTR(HOST)'["localhost" Q PROTO_"://"_HOST_"/fhir"
 ; Last-resort defaults by profile / known public hosts
 IF $$ISRPMS^C0FWPOL() Q $S($G(^C0FQUAL("FHIRBASE"))'="":$$TRIMSL(^C0FQUAL("FHIRBASE")),1:"https://rpmsfhir.vistaplex.org/fhir")
 Q "https://devfhir.vistaplex.org/fhir"
 ;
HTTPHOST() ; $$ - Host / X-Forwarded-Host (case-tolerant)
 NEW HOST
 SET HOST=$GET(HTTPREQ("header","x-forwarded-host"))
 IF HOST="" SET HOST=$GET(HTTPREQ("header","X-Forwarded-Host"))
 IF HOST="" SET HOST=$GET(HTTPREQ("header","host"))
 IF HOST="" SET HOST=$GET(HTTPREQ("header","Host"))
 SET HOST=$P(HOST,",")
 QUIT $$TRIMSP(HOST)
 ;
NEEDINLINE(BASE) ; $$ - 1 when cds1 cannot fetch BASE (localhost / private)
 NEW B
 SET B=$$LOW^XLFSTR($$TRIMSL($GET(BASE)))
 IF B="" QUIT 1
 IF B["127.0.0.1" QUIT 1
 IF B["localhost" QUIT 1
 IF $EXTRACT(B,1,7)="http://" QUIT 1
 QUIT 0
 ;
LOADDFNS(REQ,CMS,N,ERR) ; patients[] only — cds1 fetches each DFN from fhirBase
 NEW DFN,SLOT
 KILL ERR
 SET (N,SLOT,DFN)=0
 FOR  SET DFN=$ORDER(^C0FQUAL("POP",CMS,DFN)) QUIT:'DFN  DO
 . SET SLOT=SLOT+1,N=SLOT
 . SET REQ("patients",SLOT)=DFN
 QUIT
 ;
LOADBND(REQ,CMS,N,ERR) ; Build patients[] + inline bundles[] for curated POP
 NEW BND,DFN,FIL,REF,SLOT
 KILL ERR
 ; Default: use C0FWCAC cache. ?refresh=1 rebuilds every patient and can hang the
 ; %web worker for minutes on large lab graphs (browser shows Failed to fetch).
 SET REF=+$GET(HTTPARGS("refresh"))
 SET (N,SLOT,DFN)=0
 FOR  SET DFN=$ORDER(^C0FQUAL("POP",CMS,DFN)) QUIT:'DFN  DO  QUIT:$GET(ERR)'=""
 . SET SLOT=SLOT+1,N=SLOT
 . SET REQ("patients",SLOT)=DFN
 . KILL BND,FIL
 . SET FIL("dfn")=+DFN,FIL("arrayOnly")=1
 . IF REF SET FIL("refresh")=1
 . DO GETFHIR^C0FHIR(.BND,.FIL)
 . IF '$DATA(BND) SET ERR="Unable to build FHIR bundle for DFN "_DFN QUIT
 . IF $GET(BND("resourceType"))'="Bundle" SET ERR="GETFHIR did not return a Bundle for DFN "_DFN QUIT
 . SET REQ("bundles",SLOT,"dfn")=+DFN
 . MERGE REQ("bundles",SLOT,"bundle")=BND
 QUIT
 ;
TRIMSL(X) ; $$ - trim and strip trailing slash
 SET X=$$TRIMSP($G(X))
 FOR  QUIT:$E(X,$L(X))'="/"  SET X=$E(X,1,$L(X)-1)
 Q X
 ;
TRIMSP(X) ; $$ - trim spaces
 SET X=$G(X)
 FOR  QUIT:$E(X,1)'=" "  SET X=$E(X,2,$L(X))
 FOR  QUIT:$E(X,$L(X))'=" "  SET X=$E(X,1,$L(X)-1)
 Q X
 ;
CALLEVAL(JSON,OUT,ERR) ; POST cohort eval request to cds1 quality-eval sidecar
 NEW HDR,OPT,PAYLOAD,RET,STATUS,URL
 KILL OUT,ERR,PAYLOAD,RET,HDR
 DO CHUNK^C0FWAIS(.JSON,.PAYLOAD)
 SET OPT("header",1)="Expect:"
 SET URL="https://cds1.vistaplex.org/quality/evaluate-cohort"
 ; Cohort eval can take several minutes
 SET STATUS=$$%^%WC(.RET,"POST",URL,.PAYLOAD,"application/json",600,.HDR,.OPT)
 IF +$GET(STATUS)'=0 SET ERR="cds1 quality-eval curl exit status "_STATUS QUIT
 IF $GET(HDR("STATUS"))'="",($GET(HDR("STATUS"))<200!($GET(HDR("STATUS"))>299)) SET ERR="cds1 quality-eval HTTP status "_$GET(HDR("STATUS")) QUIT
 DO DECODE^XLFJSON("RET","OUT","ERR")
 IF $DATA(ERR) SET ERR="Unable to decode cds1 quality-eval response JSON" QUIT
 IF $GET(OUT("status"))="error" SET ERR=$GET(OUT("message"),"cds1 quality-eval error") QUIT
 QUIT
 ;
 ;----- Post-writeback heuristic recompute (demo closed-loop) -----
WSRECOMP(ARGS,BODY,RESULT) ; POST /fhir-quality-recompute?dfn=&measure=
 IF '$DATA(RESULT) DO WSRECOMP2(.ARGS,.BODY) QUIT ""
 DO WSRECOMP2(.RESULT,.BODY)
 QUIT ""
 ;
WSRECOMP2(OUT,BODY) ; Apply accepted quality actions → SETPOP + SETSUM
 NEW CMS,DFN,ERR,REQ,TMP
 SET U="^",HTTPRSP("mime")="application/json"
 KILL OUT
 DO SEED
 SET DFN=+$GET(HTTPARGS("dfn"))
 SET CMS=$$FIND($GET(HTTPARGS("measure")))
 DO DECACT^C0FWAIS(.BODY,.REQ,.ERR)
 IF $GET(ERR)'="" DO OO^C0FWAIS(.OUT,"error","invalid",ERR) QUIT
 IF DFN<1 SET DFN=+$GET(REQ("dfn"))
 IF CMS="" SET CMS=$$MEASACT(.REQ)
 IF DFN<1 DO OO^C0FWAIS(.OUT,"error","invalid","Missing or invalid dfn") QUIT
 IF CMS="" DO OO^C0FWAIS(.OUT,"error","invalid","Unable to determine measure (pass measure= or cmsNNN-* actions)") QUIT
 DO APPLY(.TMP,CMS,DFN,.REQ)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 IF $DATA(ERR) DO OO^C0FWAIS(.OUT,"error","exception","Unable to encode recompute response") QUIT
 QUIT
 ;
MEASACT(REQ) ; Infer CMS id from first accepted action
 NEW A,I,X
 SET A="",I=0
 FOR  SET I=$ORDER(REQ("acceptedActions",I)) QUIT:'I  DO  QUIT:A'=""
 . SET X=$$UPCASE^C0FHIR($GET(REQ("acceptedActions",I)))
 . IF X["CMS165" SET A="CMS165v14" QUIT
 . IF X["CMS122" SET A="CMS122v14" QUIT
 . IF X["CMS130" SET A="CMS130v14" QUIT
 . IF X["CMS138" SET A="CMS138v14" QUIT
 . IF X["CMS2-"!(X["CMS2_") SET A="CMS2v15" QUIT
 . IF X["CMS125" SET A="CMS125v14" QUIT
 QUIT $$FIND(A)
 ;
APPLY(OUT,CMS,DFN,REQ) ; Heuristic POP update from acceptedActions/actionValues
 NEW CUR,IPP,DENOM,NUMER,DENEX,EVID,MODE,ACT,I,SBP,DBP,A1C,CHANGED
 SET CMS=$$FIND(CMS),DFN=+DFN
 SET CUR=$GET(^C0FQUAL("POP",CMS,DFN))
 SET IPP=+$PIECE(CUR,"^",1),DENOM=+$PIECE(CUR,"^",2)
 SET NUMER=+$PIECE(CUR,"^",3),DENEX=+$PIECE(CUR,"^",4)
 SET EVID=$PIECE(CUR,"^",5),MODE=$PIECE(CUR,"^",6)
 ; If never scored, assume DENOM candidate when we are closing a numerator gap
 IF CUR="" SET IPP=1,DENOM=1,NUMER=0,DENEX=0
 SET CHANGED=0,I=0
 FOR  SET I=$ORDER(REQ("acceptedActions",I)) QUIT:'I  DO
 . SET ACT=$$UPCASE^C0FHIR($GET(REQ("acceptedActions",I)))
 . IF ACT["CMS165-RECORD-BLOOD-PRESSURE" DO  QUIT
 . . SET SBP=+$GET(REQ("actionValues","cms165-record-blood-pressure","systolic"))
 . . IF SBP=0 SET SBP=+$GET(REQ("actionValues","CMS165-RECORD-BLOOD-PRESSURE","systolic"))
 . . SET DBP=+$GET(REQ("actionValues","cms165-record-blood-pressure","diastolic"))
 . . IF DBP=0 SET DBP=+$GET(REQ("actionValues","CMS165-RECORD-BLOOD-PRESSURE","diastolic"))
 . . IF SBP>0,DBP>0,SBP<140,DBP<90 DO
 . . . SET NUMER=1,IPP=1,DENOM=1,CHANGED=1
 . . . SET EVID="heuristic-recompute BP "_SBP_"/"_DBP_" controlled"
 . . . SET MODE="heuristic-closed-loop"
 . IF ACT["CMS122-IMPORT-HBA1C" DO  QUIT
 . . SET A1C=+$GET(REQ("actionValues","cms122-import-hba1c","value"))
 . . IF A1C=0 SET A1C=+$GET(REQ("actionValues","CMS122-IMPORT-HBA1C","value"))
 . . IF A1C>0 DO
 . . . SET IPP=1,DENOM=1,CHANGED=1
 . . . ; CMS122 poor-control style: NUMER when A1c > 9
 . . . SET NUMER=$SELECT(A1C>9:1,1:0)
 . . . SET EVID="heuristic-recompute HbA1c="_A1C_" numer="_NUMER
 . . . SET MODE="heuristic-closed-loop"
 IF 'CHANGED DO  QUIT
 . SET OUT("status")="noop"
 . SET OUT("dfn")=DFN,OUT("measure")=CMS
 . SET OUT("message")="No supported numerator-closing action/values recognized"
 . SET OUT("pop")=CUR
 DO SETPOP(CMS,DFN,IPP,DENOM,NUMER,DENEX,EVID,MODE)
 DO RESUM(CMS,.OUT)
 SET OUT("status")="ok"
 SET OUT("dfn")=DFN,OUT("measure")=CMS
 SET OUT("pop","ipp")=IPP,OUT("pop","denom")=DENOM
 SET OUT("pop","numer")=NUMER,OUT("pop","denex")=DENEX
 SET OUT("pop","evidence")=EVID,OUT("pop","mode")=MODE
 QUIT
 ;
RESUM(CMS,OUT) ; Rebuild SUM from POP rows for one measure
 NEW D,N,IPP,DENOM,NUMER,DENEX,ROW,ASOF,PIPP,PDEN,PNUM,PDEX,EVID,MODE,COHORT
 SET CMS=$$FIND(CMS)
 SET (N,IPP,DENOM,NUMER,DENEX)=0,D=0
 FOR  SET D=$ORDER(^C0FQUAL("POP",CMS,D)) QUIT:'D  DO
 . SET ROW=$GET(^C0FQUAL("POP",CMS,D)),N=N+1
 . SET PIPP=+$PIECE(ROW,"^",1),PDEN=+$PIECE(ROW,"^",2)
 . SET PNUM=+$PIECE(ROW,"^",3),PDEX=+$PIECE(ROW,"^",4)
 . SET EVID=$PIECE(ROW,"^",5),MODE=$PIECE(ROW,"^",6)
 . DO NORMPOP(.PIPP,.PDEN,.PNUM,.PDEX)
 . ; Heal stale rows where NUMER was set without DENOM/IPP
 . IF ROW'=(PIPP_"^"_PDEN_"^"_PNUM_"^"_PDEX_"^"_EVID_"^"_MODE) DO
 . . SET ^C0FQUAL("POP",CMS,D)=PIPP_"^"_PDEN_"^"_PNUM_"^"_PDEX_"^"_EVID_"^"_MODE
 . SET IPP=IPP+PIPP,DENOM=DENOM+PDEN,NUMER=NUMER+PNUM,DENEX=DENEX+PDEX
 SET ASOF=$PIECE($$NOW^XLFDT,".",1)
 SET ASOF=$$FMTE^XLFDT(ASOF,5)
 SET COHORT=$GET(OUT("cohort"))
 IF COHORT="" SET COHORT=$PIECE($GET(^C0FQUAL("SUM",CMS)),"^",7)
 IF COHORT="" SET COHORT="resum from POP (NUMER clamped to DENOM)"
 DO SETSUM(CMS,N,IPP,DENOM,NUMER,DENEX,ASOF,COHORT)
 SET OUT("n")=N,OUT("ipp")=IPP,OUT("denom")=DENOM
 SET OUT("numer")=NUMER,OUT("denex")=DENEX
 SET OUT("sum","n")=N,OUT("sum","ipp")=IPP,OUT("sum","denom")=DENOM
 SET OUT("sum","numer")=NUMER,OUT("sum","denex")=DENEX
 SET OUT("sum","rate")=$SELECT(DENOM>0:$JUSTIFY(NUMER/DENOM*100,0,1)_"%",1:"n/a")
 QUIT
 ;
