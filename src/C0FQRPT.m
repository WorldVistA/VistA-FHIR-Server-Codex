C0FQRPT ; VAMC/GPL - Live DEQM Summary MeasureReport + reporting page ; 09-AUG-2026
 ;;1.0;C0FHIR PROJECT;;Aug 9, 2026;Build 1
 ;
 ; End-to-end quality reporting surface (QRDA Category III replacement):
 ;   GET /fhir-quality-report?measure=CMS165v14      live DEQM Summary MeasureReport
 ;   GET /fhir-quality-report?measure=...&bundle=1   transaction Bundle (Organization + report)
 ;   GET /fhir-quality-reporting                     reporting pipeline page (HTML)
 ;
 ; Counts come live from ^C0FQUAL("SUM",CMS)=N^IPP^DENOM^NUMER^DENEX^ASOF^COHORT —
 ; the same aggregates the dashboards display. The JSON shape mirrors
 ; HL7-FHIR-quality-testing/scripts/build-deqm-summary.py, which validates
 ; against DEQM STU5 and is accepted by the reference deqm-test-server.
 QUIT
 ;
WSRPT(RTN,FILTER) ; GET /fhir-quality-report?measure=&bundle=1
 NEW CMS,REP
 KILL RTN
 DO SEED^C0FQUAL
 SET CMS=$$FIND^C0FQUAL($GET(FILTER("measure")))
 IF CMS="" DO RPTERR(.RTN,"Unknown measure; use ?measure=CMS165v14") QUIT
 IF +$$SUM^C0FQUAL(CMS,1)<1 DO RPTERR(.RTN,"No aggregate summary stored for "_CMS) QUIT
 DO REPORTER(.REP)
 IF +$GET(FILTER("bundle")) DO BUNDLE(.RTN,CMS,.REP)
 ELSE  DO REPORT(.RTN,CMS,.REP)
 SET HTTPRSP("mime")="application/fhir+json"
 QUIT
 ;
RPTERR(RTN,MSG) ; OperationOutcome error (404)
 SET HTTPERR=404
 SET HTTPRSP("mime")="application/fhir+json"
 SET RTN(1)="{""resourceType"":""OperationOutcome"",""issue"":[{""severity"":""error"",""code"":""not-found"",""diagnostics"":"""_$$JS(MSG)_"""}]}"
 QUIT
 ;
REPORT(RTN,CMS,REP) ; Append live DEQM Summary MeasureReport JSON
 NEW N,IPP,DENOM,NUMER,DENEX,ASOF,COHORT,RID,SRC
 SET N=+$$SUM^C0FQUAL(CMS,1),IPP=+$$SUM^C0FQUAL(CMS,2),DENOM=+$$SUM^C0FQUAL(CMS,3)
 SET NUMER=+$$SUM^C0FQUAL(CMS,4),DENEX=+$$SUM^C0FQUAL(CMS,5)
 SET ASOF=$$SUM^C0FQUAL(CMS,6),COHORT=$$SUM^C0FQUAL(CMS,7)
 SET RID=$$RPTID(CMS,.REP)
 SET SRC=$EXTRACT("live SETSUM aggregate: "_COHORT_$SELECT(ASOF'="":" (as of "_ASOF_")",1:""),1,200)
 DO ADDLN^C0FHIR(.RTN,"{""resourceType"":""MeasureReport"",""id"":"""_RID_""",")
 DO ADDLN^C0FHIR(.RTN,"""meta"":{""profile"":[""http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/summary-measurereport-deqm""],""source"":""urn:vista:c0fqrpt-live"",""tag"":[")
 DO ADDLN^C0FHIR(.RTN,"{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-calc-mode"",""code"":""setsum-live"",""display"":""setsum-live""},")
 DO ADDLN^C0FHIR(.RTN,"{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-cohort-size"",""code"":"""_N_""",""display"":""cohort-size="_N_"""},")
 DO ADDLN^C0FHIR(.RTN,"{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-source"",""code"":""provenance"",""display"":"""_$$JS(SRC)_"""}]},")
 DO ADDLN^C0FHIR(.RTN,"""extension"":[{""url"":""http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/extension-measureScoring"",""valueCodeableConcept"":{""coding"":[{""system"":""http://terminology.hl7.org/CodeSystem/measure-scoring"",""code"":""proportion"",""display"":""Proportion""}]}}],")
 DO ADDLN^C0FHIR(.RTN,"""status"":""complete"",""type"":""summary"",")
 DO ADDLN^C0FHIR(.RTN,"""measure"":"""_$$MCANON(CMS)_""",""date"":"""_$$NOWISO()_""",")
 DO ADDLN^C0FHIR(.RTN,"""reporter"":{""reference"":""Organization/"_REP("id")_""",""display"":"""_$$JS(REP("display"))_"""},")
 DO ADDLN^C0FHIR(.RTN,"""period"":{""start"":"""_$$PYEAR(CMS)_"-01-01"",""end"":"""_$$PYEAR(CMS)_"-12-31""},")
 DO ADDLN^C0FHIR(.RTN,"""improvementNotation"":{""coding"":[{""system"":""http://terminology.hl7.org/CodeSystem/measure-improvement-notation"",""code"":""increase"",""display"":""Increased score indicates improvement""}]},")
 DO ADDLN^C0FHIR(.RTN,"""group"":[{""code"":{""coding"":[{""system"":""https://vistaplex.org/fhir/CodeSystem/measure-group"",""code"":""group-1"",""display"":""group-1""}],""text"":""group-1""},""population"":[")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("initial-population","Initial Population",IPP)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("denominator","Denominator",DENOM)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("numerator","Numerator",NUMER)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("denominator-exclusion","Denominator Exclusion",DENEX)_"],")
 DO ADDLN^C0FHIR(.RTN,"""measureScore"":{""value"":"_$$SCORE(NUMER,DENOM)_"}}]}")
 QUIT
 ;
BUNDLE(RTN,CMS,REP) ; Append transaction Bundle: Organization + live report
 NEW RID,TS
 SET RID=$$RPTID(CMS,.REP)
 SET TS=$$NOWISO()
 DO ADDLN^C0FHIR(.RTN,"{""resourceType"":""Bundle"",""id"":"""_RID_"-transaction"",""type"":""transaction"",""timestamp"":"""_TS_""",""entry"":[")
 DO ADDLN^C0FHIR(.RTN,"{""fullUrl"":""urn:uuid:"_REP("id")_""",""resource"":")
 DO ORG(.RTN,.REP)
 DO ADDLN^C0FHIR(.RTN,",""request"":{""method"":""PUT"",""url"":""Organization/"_REP("id")_"""}},")
 DO ADDLN^C0FHIR(.RTN,"{""fullUrl"":""urn:uuid:"_RID_""",""resource"":")
 DO REPORT(.RTN,CMS,.REP)
 DO ADDLN^C0FHIR(.RTN,",""request"":{""method"":""PUT"",""url"":""MeasureReport/"_RID_"""}}]}")
 QUIT
 ;
ORG(RTN,REP) ; Append reporter Organization JSON (QI-Core profile)
 DO ADDLN^C0FHIR(.RTN,"{""resourceType"":""Organization"",""id"":"""_REP("id")_""",")
 DO ADDLN^C0FHIR(.RTN,"""meta"":{""profile"":[""http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-organization""]},")
 DO ADDLN^C0FHIR(.RTN,"""identifier"":[{""system"":""https://vistaplex.org/fhir/sid/organization"",""value"":"""_REP("id")_"""}],")
 DO ADDLN^C0FHIR(.RTN,"""active"":true,""name"":"""_$$JS(REP("name"))_""",")
 DO ADDLN^C0FHIR(.RTN,"""telecom"":[{""system"":""url"",""value"":"""_REP("url")_"""}]}")
 QUIT
 ;
RPTID(CMS,REP) ; $$ - live report id (distinct from frozen artifact ids)
 QUIT CMS_"-"_$GET(REP("tag"))_"live-summary-deqm"
 ;
POPJ(CODE,DISP,CNT) ; $$ - one population JSON object
 QUIT "{""code"":{""coding"":[{""system"":""http://terminology.hl7.org/CodeSystem/measure-population"",""code"":"""_CODE_""",""display"":"""_DISP_"""}],""text"":"""_DISP_"""},""count"":"_+CNT_"}"
 ;
REPORTER(REP) ; Reporter Organization preset per lane (mirrors build-deqm-summary.py)
 NEW HOST
 KILL REP
 SET HOST=$$LOW^XLFSTR($$HTTPHOST^C0FQUAL())
 IF $$ISRPMS^C0FWPOL() DO  QUIT
 . SET REP("id")="vistaplex-rpms-demo",REP("tag")="rpms-"
 . SET REP("name")="VistaPlex RPMS FHIR Quality Demo (rpmsfhir)"
 . SET REP("display")="VistaPlex RPMS FHIR Quality Demo"
 . SET REP("url")="https://rpmsfhir.vistaplex.org/fhir"
 IF HOST="fhir.vistaplex.org" DO  QUIT
 . SET REP("id")="vistaplex-prod-demo",REP("tag")="fhirprod-"
 . SET REP("name")="VistaPlex FHIR Production Reference (fhir)"
 . SET REP("display")="VistaPlex FHIR Production Reference"
 . SET REP("url")="https://fhir.vistaplex.org/fhir"
 SET REP("id")="vistaplex-demo",REP("tag")=""
 SET REP("name")="VistaPlex FHIR Quality Demo (fhirdev)"
 SET REP("display")="VistaPlex FHIR Quality Demo"
 SET REP("url")="https://devfhir.vistaplex.org/fhir-quality-dashboards"
 QUIT
 ;
MCANON(CMS) ; $$ - measure canonical (placeholder until CMS FHIR dQM packages pinned)
 NEW TAIL,VER
 SET VER="0.0.1"
 SET TAIL=$PIECE(CMS,"v",$LENGTH(CMS,"v"))
 IF TAIL?1.N SET VER=+TAIL_".0.000"
 QUIT "https://ecqi.healthit.gov/ecqm/ec/"_CMS_"|"_VER
 ;
SCORE(NUMER,DENOM) ; $$ - proportion score as JSON decimal (leading zero kept)
 IF +$GET(DENOM)<1 QUIT 0
 QUIT $JUSTIFY(NUMER/DENOM,0,6)
 ;
PYEAR(CMS) ; $$ - measurement-period year from META text (default 2026)
 NEW I,P,W,Y
 SET P=$$META^C0FQUAL(CMS,2),Y=""
 FOR I=1:1:$LENGTH(P," ") SET W=$PIECE(P," ",I) IF W?4N SET Y=W QUIT
 IF Y="" SET Y=2026
 QUIT Y
 ;
NOWISO() ; $$ - current dateTime as FHIR instant (UTC-tagged)
 IF $TEXT(NOW^XLFDT)'="" QUIT $$FM2FHIR^C0FHIRBU($$NOW^XLFDT)
 QUIT "2026-01-01T00:00:00Z"
 ;
JS(X) ; $$ - escape a string for a JSON string literal
 NEW C,I,OUT
 SET X=$GET(X),OUT=""
 FOR I=1:1:$LENGTH(X) DO
 . SET C=$EXTRACT(X,I)
 . IF C="\" SET OUT=OUT_"\\" QUIT
 . IF C="""" SET OUT=OUT_"\""" QUIT
 . IF $ASCII(C)<32 SET OUT=OUT_" " QUIT
 . SET OUT=OUT_C
 QUIT OUT
 ;
WSRPTPG(RTN,FILTER) ; GET /fhir-quality-reporting — pipeline page (HTML)
 NEW ASOF,CMS,COHORT,DENEX,DENOM,IPP,LNK,N,NUMER,RATE,REP,ROW,TITLE
 KILL RTN
 DO SEED^C0FQUAL
 DO REPORTER(.REP)
 DO HDR^C0FQUAL(.RTN,"End-to-End Quality Reporting","DEQM Summary MeasureReport (QRDA Category III replacement) — live from this server's aggregates")
 DO ADDLN^C0FHIR(.RTN,"<div class=""links"">")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-dashboards"">Quality dashboards</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/filesystem/quality/measurereports/index.html"">Frozen MeasureReport artifacts</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""https://github.com/glilly/HL7-FHIR-quality-testing/tree/master/docs/deqm-summary"">DEQM builder docs (GitHub)</a>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">The pipeline</h2>")
 DO ADDLN^C0FHIR(.RTN,"<ol>")
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Calculate</strong> — the <em>Re-evaluate CQL</em> button on each measure dashboard runs official cqm-execution CQL on cds1 and stores per-patient flags and aggregates on this server.</li>")
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Build</strong> — the <em>live report</em> links below generate a DEQM STU5 Summary MeasureReport from those aggregates at the moment you click, on this server, in M.</li>")
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Validate</strong> — reports validate against the DEQM Summary profile (HL7 validator + davinci-deqm package). The frozen official-cql artifacts carry passing validation evidence; one-click validation from this page is next.</li>")
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Submit</strong> — the <em>submission Bundle</em> links below are the exact transaction payload (reporter Organization + MeasureReport) a DEQM receiver accepts; one-click submit from this page is next.</li>")
 DO ADDLN^C0FHIR(.RTN,"</ol>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">This replaces QRDA Category III aggregate reporting on the CMS FHIR dQM path. Live exports are tagged <code>setsum-live</code> with cohort provenance; frozen artifacts under the MeasureReport index hold the reviewed official-cql freeze used for exchange.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<h2>Active measures — live reports</h2>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Measure</th><th>IPP / DENOM / NUMER / DENEX</th><th>Rate</th><th>As of</th><th>Provenance</th><th>Live report</th><th>Frozen (official-cql)</th></tr>")
 SET CMS=""
 FOR  SET CMS=$ORDER(^C0FQUAL("MEAS",CMS)) QUIT:CMS=""  DO
 . IF '$$ISACTIVE^C0FQUAL(CMS) QUIT
 . SET TITLE=$$TITLE^C0FQUAL(CMS)
 . SET N=+$$SUM^C0FQUAL(CMS,1),IPP=+$$SUM^C0FQUAL(CMS,2),DENOM=+$$SUM^C0FQUAL(CMS,3)
 . SET NUMER=+$$SUM^C0FQUAL(CMS,4),DENEX=+$$SUM^C0FQUAL(CMS,5)
 . SET ASOF=$$SUM^C0FQUAL(CMS,6),COHORT=$$SUM^C0FQUAL(CMS,7)
 . SET RATE=$SELECT(DENOM>0:$JUSTIFY(NUMER/DENOM*100,0,1)_"%",1:"n/a")
 . SET ROW="<tr><td><a href=""/fhir-quality-dashboards/"_CMS_""">"_$$HTMLESC^C0FHIR(CMS)_"</a></td>"
 . SET ROW=ROW_"<td>"_$$HTMLESC^C0FHIR(TITLE)_"</td>"
 . IF N>0 SET ROW=ROW_"<td>"_IPP_" / "_DENOM_" / "_NUMER_" / "_DENEX_" <span class=""muted"">(n="_N_")</span></td>"
 . ELSE  SET ROW=ROW_"<td class=""muted"">not evaluated</td>"
 . SET ROW=ROW_"<td>"_RATE_"</td>"
 . SET ROW=ROW_"<td class=""muted"">"_$$HTMLESC^C0FHIR(ASOF)_"</td>"
 . SET ROW=ROW_"<td class=""muted"">"_$$HTMLESC^C0FHIR(COHORT)_"</td>"
 . IF N>0 DO
 . . SET LNK="<a href=""/fhir-quality-report?measure="_CMS_""">report</a>"
 . . SET LNK=LNK_" · <a href=""/fhir-quality-report?measure="_CMS_"&amp;bundle=1"">submission Bundle</a>"
 . . SET ROW=ROW_"<td>"_LNK_"</td>"
 . ELSE  SET ROW=ROW_"<td class=""muted"">—</td>"
 . SET LNK="<a href=""/filesystem/quality/measurereports/"_CMS_"/summary-deqm.json"">summary-deqm</a>"
 . SET LNK=LNK_" · <a href=""/filesystem/quality/measurereports/"_CMS_"/index.html"">index</a>"
 . SET ROW=ROW_"<td>"_LNK_"</td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 DO ADDLN^C0FHIR(.RTN,"</table>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Reporter for this server</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p>Live reports from this server are attributed to <strong>"_$$HTMLESC^C0FHIR(REP("name"))_"</strong> (<code>Organization/"_REP("id")_"</code>).</p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">The submission Bundle carries this Organization so the receiver can resolve MeasureReport.reporter.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO FTR^C0FQUAL(.RTN)
 SET HTTPRSP("mime")="text/html"
 QUIT
