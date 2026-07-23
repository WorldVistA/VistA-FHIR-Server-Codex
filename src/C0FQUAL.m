C0FQUAL ; VAMC/GPL - FHIR quality measure dashboards ; 23-JUL-2026
 ;;1.0;C0FHIR PROJECT;;Jul 23, 2026;Build 1
 ;
 ; Active-measure registry and HTML dashboards for:
 ;   GET /fhir-quality-dashboards
 ;   GET /fhir-quality-dashboards/{measure}
 ;   GET /fhir-quality-dashboards?measure=CMS165v14
 ;
 Q
 ;
SEED ; Ensure catalog + default active measures exist
 IF $GET(^C0FQUAL(0))'="" QUIT
 DO SETMEAS("CMS165v14","Controlling High Blood Pressure","Condition, Encounter, Blood Pressure Observation","A","First-wave; CQL/VSAC path ready")
 DO SETMEAS("CMS122v14","Diabetes: Glycemic Status Assessment Greater Than 9%","Condition, Encounter, Observation HbA1c","A","First-wave; Quality AI Consult demo")
 DO SETMEAS("CMS130v14","Colorectal Cancer Screening","Procedure, Observation, DiagnosticReport","I","First-wave shortlist")
 DO SETMEAS("CMS125v14","Breast Cancer Screening","Procedure, DiagnosticReport","I","First-wave shortlist")
 DO SETMEAS("CMS22v14","Screening for High Blood Pressure and Follow-Up","Encounter, Blood Pressure, Follow-up","I","CMS147 substitute in 2026 EC ZIP")
 DO SETMEAS("CMS2v15","Screening for Depression and Follow-Up Plan","Observation, Procedure, CarePlan","I","First-wave shortlist")
 DO SETMEAS("CMS68v15","Documentation of Current Medications","MedicationRequest / medication review","I","First-wave shortlist")
 DO SETMEAS("CMS138v14","Tobacco Use: Screening and Cessation Intervention","Social-history Observation, Procedure/Medication","I","First-wave shortlist")
 DO SETMEAS("CMS131v14","Diabetes: Eye Exam","Condition, Procedure, Observation","I","First-wave shortlist")
 SET ^C0FQUAL(0)=1
 QUIT
 ;
NORM(CMS) ; Trim CMS id; preserve CMS165v14-style casing
 QUIT $TRANSLATE($GET(CMS)," ","")
 ;
FIND(CMS) ; Resolve catalog key (case-insensitive)
 NEW C,WANT
 DO SEED
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT ""
 IF $DATA(^C0FQUAL("MEAS",CMS)) QUIT CMS
 SET WANT=$$UPCASE^C0FHIR(CMS),C=""
 FOR  SET C=$ORDER(^C0FQUAL("MEAS",C)) QUIT:C=""  IF $$UPCASE^C0FHIR(C)=WANT QUIT
 QUIT C
 ;
SETMEAS(CMS,TITLE,FOCUS,STAT,NOTE) ; Store one measure definition
 SET CMS=$$NORM($GET(CMS))
 IF CMS="" QUIT
 SET ^C0FQUAL("MEAS",CMS)=$GET(TITLE)_"^"_$GET(FOCUS)_"^"_$GET(STAT)_"^"_$GET(NOTE)
 QUIT
 ;
ACTIVATE(CMS) ; Mark measure active
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 SET $PIECE(^C0FQUAL("MEAS",KEY),"^",3)="A"
 QUIT 1
 ;
DEACTIVATE(CMS) ; Mark measure inactive
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 SET $PIECE(^C0FQUAL("MEAS",KEY),"^",3)="I"
 QUIT 1
 ;
ISACTIVE(CMS) ; True when measure is active
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 IF KEY="" QUIT 0
 QUIT ($PIECE($GET(^C0FQUAL("MEAS",KEY)),"^",3)="A")
 ;
TITLE(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 QUIT $PIECE($GET(^C0FQUAL("MEAS",KEY)),"^",1)
 ;
FOCUS(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 QUIT $PIECE($GET(^C0FQUAL("MEAS",KEY)),"^",2)
 ;
NOTE(CMS) ;
 NEW KEY
 DO SEED
 SET KEY=$$FIND($GET(CMS))
 QUIT $PIECE($GET(^C0FQUAL("MEAS",KEY)),"^",4)
 ;
COUNTAC() ; Count active measures
 NEW CMS,N
 DO SEED
 SET N=0,CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  IF $$ISACTIVE(CMS) SET N=N+1
 QUIT N
 ;
SUMMARY(RTN) ; HTML summary of active measures
 NEW CMS,FOCUS,N,NOTE,TITLE,URL
 DO SEED
 KILL RTN
 DO HDR(.RTN,"FHIR Quality Dashboards","Active quality measures for this system")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Open a measure dashboard for cohort links, AI Consult, and FHIR tooling. Active set is stored in ^C0FQUAL.</p>")
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
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Measure</th><th>Primary FHIR focus</th><th>Notes</th><th></th></tr>")
 SET CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  DO
 . IF '$$ISACTIVE(CMS) QUIT
 . SET TITLE=$$TITLE(CMS),FOCUS=$$FOCUS(CMS),NOTE=$$NOTE(CMS)
 . SET URL="/fhir-quality-dashboards/"_CMS
 . DO ADDLN^C0FHIR(.RTN,"<tr><td><a href="""_URL_""">"_$$HTMLESC^C0FHIR(CMS)_"</a></td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(TITLE)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(FOCUS)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td>"_$$HTMLESC^C0FHIR(NOTE)_"</td>")
 . DO ADDLN^C0FHIR(.RTN,"<td><a class=""btn"" href="""_URL_""">Open</a></td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
SUMDONE ;
 DO FTR(.RTN)
 QUIT
 ;
CATALOG(RTN) ; HTML catalog of all known measures (active + inactive)
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
 NEW CNT,DFN,FOCUS,IEN,NAME,NOTE,ROOT,ROW,STAT,TITLE,AURL,BURL,FURL,LURL,RAW
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
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Status:</strong> "_$SELECT(STAT="A":"Active",1:"Inactive")_"</p>")
 DO ADDLN^C0FHIR(.RTN,"<p><strong>Primary FHIR focus:</strong> "_$$HTMLESC^C0FHIR(FOCUS)_"</p>")
 IF NOTE'="" DO ADDLN^C0FHIR(.RTN,"<p><strong>Notes:</strong> "_$$HTMLESC^C0FHIR(NOTE)_"</p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">AI Consult uses <code>measure="_$$HTMLESC^C0FHIR(CMS)_"</code>. CQL/VSAC evaluation lives in HL7-FHIR-quality-testing.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO ADDLN^C0FHIR(.RTN,"<h2>Graph-source patients</h2>")
 SET ROOT=$$GSROOT^C0FHIR()
 IF ROOT="" DO  GOTO MDONE
 . DO ADDLN^C0FHIR(.RTN,"<p>No fhir-intake graph root is available.</p>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>DFN</th><th>IEN</th><th>Name</th><th>AI Consult</th><th>FHIR browser</th><th>/fhir</th><th>Source bundle</th><th>Load log</th></tr>")
 SET CNT=0,DFN=0
 FOR  SET DFN=$ORDER(@ROOT@("DFN",DFN)) QUIT:+DFN<1!(CNT>250)  DO
 . SET IEN=$ORDER(@ROOT@("DFN",DFN,""),-1) QUIT:+IEN<1
 . SET CNT=CNT+1
 . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^") IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . SET AURL="/aiconsult?dfn="_DFN_"&measure="_CMS
 . SET BURL="/fhir?dfn="_DFN_"&view=browser&source=aiconsult"
 . SET FURL="/fhir?dfn="_DFN
 . SET LURL=$$LOADLOGURL^C0FHIR(ROOT,IEN)
 . SET ROW="<tr><td>"_DFN_"</td><td>"_IEN_"</td><td>"_$$HTMLESC^C0FHIR(NAME)_"</td>"
 . SET ROW=ROW_"<td><a href="""_AURL_""">aiconsult</a></td>"
 . SET ROW=ROW_"<td><a href="""_BURL_""">browser</a></td>"
 . SET ROW=ROW_"<td><a href="""_FURL_""">/fhir</a></td>"
 . SET ROW=ROW_"<td><a href=""/altfhir?ien="_IEN_""">bundle</a></td>"
 . SET ROW=ROW_"<td><a href="""_LURL_""">load</a></td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 IF CNT=0 DO ADDLN^C0FHIR(.RTN,"<tr><td colspan=""8"">No graph-linked patients found.</td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
 IF CMS="CMS165v14" DO CMS165N(.RTN)
MDONE ;
 DO FTR(.RTN)
 QUIT
 ;
CMS165N(RTN) ; CMS165-specific validation note
 DO ADDLN^C0FHIR(.RTN,"<h2>CMS165 CQL status</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p>Official <code>cqm-execution</code> on the curated selected-18 cohort")
 DO ADDLN^C0FHIR(.RTN," reports IPP/DENOM/NUMER <strong>15/15/15</strong> after VSAC expand")
 DO ADDLN^C0FHIR(.RTN," + FHIR→QDM converter fixes (2026-07-23). Broader preclassifier")
 DO ADDLN^C0FHIR(.RTN," cohorts remain heuristic proxy until a wider CQL pass.</p>")
 QUIT
 ;
HDR(RTN,TITLE,SUB) ; Shared HTML header
 DO ADDLN^C0FHIR(.RTN,"<!DOCTYPE HTML>")
 DO ADDLN^C0FHIR(.RTN,"<html><head><meta charset=""utf-8""><title>"_$$HTMLESC^C0FHIR(TITLE)_"</title>")
 DO ADDLN^C0FHIR(.RTN,"<style>")
 DO ADDLN^C0FHIR(.RTN,"body{font-family:Arial,Helvetica,sans-serif;margin:24px;line-height:1.45;color:#0f172a;background:#f8fafc}")
 DO ADDLN^C0FHIR(.RTN,"h1{margin:0 0 8px 0;font-size:1.6rem}h2{margin-top:28px;font-size:1.15rem}")
 DO ADDLN^C0FHIR(.RTN,".muted{color:#64748b} .links a{margin-right:12px}")
 DO ADDLN^C0FHIR(.RTN,"table{border-collapse:collapse;width:100%;margin:14px 0;background:#fff}")
 DO ADDLN^C0FHIR(.RTN,"th,td{border:1px solid #cbd5e1;padding:8px;text-align:left}th{background:#e2e8f0}")
 DO ADDLN^C0FHIR(.RTN,".btn{display:inline-block;padding:4px 10px;background:#0f766e;color:#fff;text-decoration:none;border-radius:4px}")
 DO ADDLN^C0FHIR(.RTN,".card{background:#fff;border:1px solid #cbd5e1;padding:14px 16px;margin:14px 0;border-radius:6px}")
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
