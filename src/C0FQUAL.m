C0FQUAL ; VAMC/GPL - FHIR quality measure dashboards ; 23-JUL-2026
 ;;1.0;C0FHIR PROJECT;;Jul 23, 2026;Build 2
 ;
 ; Active-measure registry and HTML dashboards for:
 ;   GET /fhir-quality-dashboards
 ;   GET /fhir-quality-dashboards/{measure}
 ;
 ; ^C0FQUAL("MEAS",CMS)=TITLE^FOCUS^STATUS^NOTE
 ; ^C0FQUAL("META",CMS)=IPP^PERIOD^DOCS^TOOLS^MODE
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
 SET ^C0FQUAL(0)=2
 QUIT
 ;
SEEDMEAS ; Default measure catalog
 DO SETMEAS("CMS165v14","Controlling High Blood Pressure","Condition, Encounter, Blood Pressure Observation","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS122v14","Diabetes: Glycemic Status Assessment Greater Than 9%","Condition, Encounter, Observation HbA1c","A","First-wave; Quality AI Consult demo")
 DO SETMEAS("CMS130v14","Colorectal Cancer Screening","Procedure, Observation, DiagnosticReport","I","First-wave shortlist")
 DO SETMEAS("CMS125v14","Breast Cancer Screening","Procedure, DiagnosticReport","I","First-wave shortlist")
 DO SETMEAS("CMS22v14","Screening for High Blood Pressure and Follow-Up","Encounter, Blood Pressure, Follow-up","I","CMS147 substitute in 2026 EC ZIP")
 DO SETMEAS("CMS2v15","Screening for Depression and Follow-Up Plan","Observation, Procedure, CarePlan","I","First-wave shortlist")
 DO SETMEAS("CMS68v15","Documentation of Current Medications","MedicationRequest / medication review","I","First-wave shortlist")
 DO SETMEAS("CMS138v14","Tobacco Use: Screening and Cessation Intervention","Social-history Observation, Procedure/Medication","I","First-wave shortlist")
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
 DO SETSUM("CMS165v14",18,15,15,15,0,"2026-07-23","selected-18 CQL cohort (not full graph DFN list)")
 SET IPP="Adults with diabetes and qualifying encounter; glycemic status (HbA1c)"
 SET IPP=IPP_" assessment logic per CMS122v14"
 SET DOCS="https://github.com/glilly/HL7-FHIR-quality-testing/blob/master/docs/CMS_2026_QUALITY_MEASURES.md"
 SET TOOLS="Quality AI Consult / heuristic FHIR proxy until CQL package wired"
 DO SETMETA("CMS122v14",IPP,"Calendar year 2026",DOCS,TOOLS,"heuristic-proxy")
 DO SETSUM("CMS122v14",0,0,0,0,0,"","not yet CQL-evaluated on this host")
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
SETMETA(CMS,IPP,PERIOD,DOCS,TOOLS,MODE) ;
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 SET ^C0FQUAL("META",CMS)=$GET(IPP)_"^"_$GET(PERIOD)_"^"_$GET(DOCS)_"^"_$GET(TOOLS)_"^"_$GET(MODE)
 QUIT
 ;
SETSUM(CMS,N,IPP,DENOM,NUMER,DENEX,ASOF,COHORT) ;
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 SET ^C0FQUAL("SUM",CMS)=+$GET(N)_"^"_+$GET(IPP)_"^"_+$GET(DENOM)_"^"_+$GET(NUMER)_"^"_+$GET(DENEX)_"^"_$GET(ASOF)_"^"_$GET(COHORT)
 QUIT
 ;
SETPOP(CMS,DFN,IPP,DENOM,NUMER,DENEX,EVID,MODE) ; Store per-patient population flags
 SET CMS=$$FIND($GET(CMS)),DFN=+$GET(DFN)
 IF CMS=""!(DFN<1) QUIT 0
 SET ^C0FQUAL("POP",CMS,DFN)=+$GET(IPP)_"^"_+$GET(DENOM)_"^"_+$GET(NUMER)_"^"_+$GET(DENEX)_"^"_$GET(EVID)_"^"_$GET(MODE)
 QUIT 1
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
 DO ADDLN^C0FHIR(.RTN,"<a href=""/altfhir/metadata"">/altfhir metadata</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir/metadata"">/fhir metadata</a>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 SET N=$$COUNTAC()
 DO ADDLN^C0FHIR(.RTN,"<h2>Active measures ("_N_")</h2>")
 IF N<1 DO  GOTO SUMDONE
 . DO ADDLN^C0FHIR(.RTN,"<p>No active measures. Activate with ACTIVATE^C0FQUAL(""CMS165v14"").</p>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Measure</th><th>Summary (IPP/DENOM/NUMER)</th><th>Mode</th><th></th></tr>")
 SET CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  DO
 . IF '$$ISACTIVE(CMS) QUIT
 . SET TITLE=$$TITLE(CMS)
 . SET IPP=$$SUM(CMS,2),DENOM=$$SUM(CMS,3),NUMER=$$SUM(CMS,4)
 . SET URL="/fhir-quality-dashboards/"_CMS
 . DO ADDLN^C0FHIR(.RTN,"<tr><td><a href="""_URL_""">"_$$HTMLESC^C0FHIR(CMS)_"</a></td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(TITLE)_"</td>")
 . IF +$$SUM(CMS,1)>0 DO ADDLN^C0FHIR(.RTN,"<td>"_IPP_" / "_DENOM_" / "_NUMER_" <span class=""muted"">(n="_$$SUM(CMS,1)_")</span></td>")
 . ELSE  DO ADDLN^C0FHIR(.RTN,"<td class=""muted"">not evaluated</td>")
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
 NEW AURL,BURL,FURL,LURL,RURL,SURL
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
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO MHEAD(.RTN,CMS,STAT,FOCUS,NOTE)
 DO ADDLN^C0FHIR(.RTN,"<h2>Patients (graph source)</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">IPP/DENOM/NUMER/DENEX show Yes/No when stored in ^C0FQUAL(""POP""); otherwise — (not evaluated for this DFN). Aggregate CQL summary above may use a separate curated cohort.</p>")
 SET ROOT=$$GSROOT^C0FHIR()
 IF ROOT="" DO  GOTO MDONE
 . DO ADDLN^C0FHIR(.RTN,"<p>No fhir-intake graph root is available.</p>")
 DO ADDLN^C0FHIR(.RTN,"<table>")
 DO ADDLN^C0FHIR(.RTN,"<tr><th>DFN</th><th>Name</th><th>IPP</th><th>DENOM</th><th>NUMER</th><th>DENEX</th><th>Evidence</th><th>FHIR browser</th><th>rehmp</th><th>AI Consult</th><th>Bundle</th></tr>")
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
 . SET SURL="/fhir?dfn="_DFN_"&view=browser&source=showfhir&ien="_IEN
 . SET RURL="/demos/cprs/index.html?dfn="_DFN_"&autoload=dfn&rehmpBase=/rehmp"
 . SET AURL="/aiconsult?dfn="_DFN_"&measure="_CMS
 . SET ROW="<tr><td>"_DFN_"</td><td>"_$$HTMLESC^C0FHIR(NAME)_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(IPP)_""">"_IPP_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENOM)_""">"_DENOM_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(NUMER)_""">"_NUMER_"</td>"
 . SET ROW=ROW_"<td class="""_$$PCLS(DENEX)_""">"_DENEX_"</td>"
 . SET ROW=ROW_"<td>"_$$HTMLESC^C0FHIR(EVID)_"</td>"
 . SET ROW=ROW_"<td><a href="""_BURL_""">/fhir browser</a>"
 . SET ROW=ROW_" · <a href="""_SURL_""">source bundle</a></td>"
 . SET ROW=ROW_"<td><a href="""_RURL_""">rehmp</a></td>"
 . SET ROW=ROW_"<td><a href="""_AURL_""">aiconsult</a></td>"
 . SET ROW=ROW_"<td><a href=""/altfhir?ien="_IEN_""">altfhir</a></td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 IF CNT=0 DO ADDLN^C0FHIR(.RTN,"<tr><td colspan=""11"">No graph-linked patients found.</td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
MDONE ;
 DO FTR(.RTN)
 QUIT
 ;
MHEAD(RTN,CMS,STAT,FOCUS,NOTE) ; Measure header cards
 NEW IPP,PERIOD,DOCS,TOOLS,MODE,N,IPPC,DENOMC,NUMERC,DENEXC,ASOF,COHORT,RATE,LINE
 SET IPP=$$META(CMS,1),PERIOD=$$META(CMS,2),DOCS=$$META(CMS,3)
 SET TOOLS=$$META(CMS,4),MODE=$$META(CMS,5)
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
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Initial Population (brief)</h2>")
 IF IPP'="" DO ADDLN^C0FHIR(.RTN,"<p>"_$$HTMLESC^C0FHIR(IPP)_"</p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">IPP criteria not yet documented for this measure.</p>")
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
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Measure calculation</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>CQM tools:</strong> "_$$HTMLESC^C0FHIR(TOOLS)_"</p>")
 IF DOCS'="" DO ADDLN^C0FHIR(.RTN,"<p><a href="""_$$HTMLESC^C0FHIR(DOCS)_""">Documentation of measure calculation</a></p>")
 ELSE  DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">No calculation doc link configured.</p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Per-DFN flags: SETPOP^C0FQUAL(cms,dfn,ipp,denom,numer,denex,evidence,mode).</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 QUIT
 ;
PCLS(V) ; CSS class for Yes/No/—
 IF V="Yes" QUIT "yes"
 IF V="No" QUIT "no"
 QUIT "na"
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
 DO ADDLN^C0FHIR(.RTN,".btn{display:inline-block;padding:4px 10px;background:#0f766e;color:#fff;text-decoration:none;border-radius:4px}")
 DO ADDLN^C0FHIR(.RTN,".card{background:#fff;border:1px solid #cbd5e1;padding:14px 16px;margin:14px 0;border-radius:6px}")
 DO ADDLN^C0FHIR(.RTN,".stats .big{font-size:1.05rem} .yes{color:#047857;font-weight:600} .no{color:#b91c1c} .na{color:#94a3b8}")
 DO ADDLN^C0FHIR(.RTN,"code{background:#e2e8f0;padding:1px 4px;border-radius:3px}")
 DO ADDLN^C0FHIR(.RTN,"</style></head><body>")
 DO ADDLN^C0FHIR(.RTN,"<h1>"_$$HTMLESC^C0FHIR(TITLE)_"</h1>")
 IF $GET(SUB)'="" DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">"_$$HTMLESC^C0FHIR(SUB)_"</p>")
 QUIT
 ;
FTR(RTN) ;
 DO ADDLN^C0FHIR(.RTN,"</body></html>")
 QUIT
 ;
