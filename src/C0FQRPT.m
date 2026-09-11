C0FQRPT ; VAMC/GPL - Live DEQM Summary/Individual MeasureReport + reporting page ; 10-AUG-2026
 ;;1.0;C0FHIR PROJECT;;Aug 10, 2026;Build 2
 ;
 ; End-to-end quality reporting surface (QRDA Category III + I analogues):
 ;   GET  /fhir-quality-report?measure=CMS165v14           live DEQM Summary MeasureReport
 ;   GET  /fhir-quality-report?measure=...&dfn=101115      live DEQM Individual MeasureReport
 ;   GET  /fhir-quality-report?measure=...&bundle=1        transaction Bundle (Organization + report)
 ;   GET  /fhir-quality-reporting                          reporting pipeline page (HTML)
 ;   POST /fhir-quality-report-validate?measure=[&dfn=]    HL7 validator via cds1 (TaskMan task)
 ;   POST /fhir-quality-report-submit?measure=[&dfn=]      DEQM receiver via cds1 (TaskMan task)
 ;   GET  /fhir-quality-report-outcome?measure=&op=[&dfn=] full cds1 response for latest run
 ;
 ; TJSON browser view of the live submission Bundle:
 ;   /fhir?view=browser&source=qualityreport&measure=CMS165v14
 ;   /fhir?view=browser&source=qualityreport&measure=CMS165v14&dfn=101115
 ;
 ; Summary run status: ^C0FQUAL("REPORT",CMS,op)=status^fmts^detail
 ; Individual:         ^C0FQUAL("REPORT",CMS,"INDV",DFN,op)=status^fmts^detail
 ; Full outcome: ... ,"json",n = raw cds1 response lines
 ; Evidence log: ^C0FQUAL("REPORT","LOG",n)=fmts^CMS^op^status^detail[^DFN]
 ;
 ; Summary counts from ^C0FQUAL("SUM",CMS); Individual from ^C0FQUAL("POP",CMS,DFN).
 ; JSON shapes mirror HL7-FHIR-quality-testing build-deqm-summary.py /
 ; build-deqm-individual.py (DEQM STU5; accepted by deqm-test-server).
 QUIT
 ;
WSRPT(RTN,FILTER) ; GET /fhir-quality-report?measure=&dfn=&bundle=1
 NEW CMS,DFN,REP
 KILL RTN
 DO SEED^C0FQUAL
 SET CMS=$$FIND^C0FQUAL($GET(FILTER("measure")))
 SET DFN=+$GET(FILTER("dfn"))
 IF CMS="" DO RPTERR(.RTN,"Unknown measure; use ?measure=CMS165v14") QUIT
 IF DFN>0 DO  QUIT
 . IF '$$HASPOP^C0FQUAL(CMS,DFN) DO RPTERR(.RTN,"No SETPOP row for "_CMS_" DFN "_DFN) QUIT
 . DO REPORTER(.REP)
 . ; Avoid ELSE after BUNDLE — BUNDLE's IF DFN>0 can leave $TEST false (M ELSE pitfall).
 . IF +$GET(FILTER("bundle")) DO BUNDLE(.RTN,CMS,.REP,DFN)
 . IF '+$GET(FILTER("bundle")) DO INDVREP(.RTN,CMS,DFN,.REP)
 . SET HTTPRSP("mime")="application/fhir+json"
 IF +$$SUM^C0FQUAL(CMS,1)<1 DO RPTERR(.RTN,"No aggregate summary stored for "_CMS) QUIT
 DO REPORTER(.REP)
 IF +$GET(FILTER("bundle")) DO BUNDLE(.RTN,CMS,.REP,0)
 IF '+$GET(FILTER("bundle")) DO REPORT(.RTN,CMS,.REP)
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
INDVREP(RTN,CMS,DFN,REP) ; Append live DEQM Individual MeasureReport JSON (QRDA-I analogue)
 NEW IPP,DENOM,NUMER,DENEX,EVID,MODE,RID,SRC,TAG
 SET IPP=+$$POP^C0FQUAL(CMS,DFN,1),DENOM=+$$POP^C0FQUAL(CMS,DFN,2)
 SET NUMER=+$$POP^C0FQUAL(CMS,DFN,3),DENEX=+$$POP^C0FQUAL(CMS,DFN,4)
 SET EVID=$PIECE($GET(^C0FQUAL("POP",CMS,DFN)),"^",5)
 SET MODE=$PIECE($GET(^C0FQUAL("POP",CMS,DFN)),"^",6) IF MODE="" SET MODE="setpop"
 SET RID=$$RPTID(CMS,.REP,DFN)
 SET SRC=$EXTRACT("live SETPOP: "_EVID,1,200)
 SET TAG=$SELECT(MODE'="":MODE,1:"setpop")
 DO ADDLN^C0FHIR(.RTN,"{""resourceType"":""MeasureReport"",""id"":"""_RID_""",")
 DO ADDLN^C0FHIR(.RTN,"""meta"":{""profile"":[""http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/indv-measurereport-deqm""],")
 DO ADDLN^C0FHIR(.RTN,"""source"":""urn:vista:c0fqrpt-live-indv"",""tag"":[")
 DO ADDLN^C0FHIR(.RTN,"{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-calc-mode"",""code"":"""_$$JS(TAG)_""",""display"":"""_$$JS(TAG)_"""},")
 DO ADDLN^C0FHIR(.RTN,"{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-source"",""code"":""setpop-live"",""display"":""setpop-live""}")
 IF EVID'="" DO ADDLN^C0FHIR(.RTN,",{""system"":""https://vistaplex.org/fhir/CodeSystem/quality-evidence"",""code"":""evidence"",""display"":"""_$$JS(SRC)_"""}")
 DO ADDLN^C0FHIR(.RTN,"]},")
 DO ADDLN^C0FHIR(.RTN,"""extension"":[{""url"":""http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/extension-measureScoring"",")
 DO ADDLN^C0FHIR(.RTN,"""valueCodeableConcept"":{""coding"":[{""system"":""http://terminology.hl7.org/CodeSystem/measure-scoring"",""code"":""proportion"",""display"":""Proportion""}]}}],")
 DO ADDLN^C0FHIR(.RTN,"""status"":""complete"",""type"":""individual"",")
 DO ADDLN^C0FHIR(.RTN,"""measure"":"""_$$MCANON(CMS)_""",""subject"":{""reference"":""Patient/"_DFN_"""},""date"":"""_$$NOWISO()_""",")
 DO ADDLN^C0FHIR(.RTN,"""reporter"":{""reference"":""Organization/"_REP("id")_""",""display"":"""_$$JS(REP("display"))_"""},")
 DO ADDLN^C0FHIR(.RTN,"""period"":{""start"":"""_$$PYEAR(CMS)_"-01-01"",""end"":"""_$$PYEAR(CMS)_"-12-31""},")
 DO ADDLN^C0FHIR(.RTN,"""improvementNotation"":{""coding"":[{""system"":""http://terminology.hl7.org/CodeSystem/measure-improvement-notation"",")
 DO ADDLN^C0FHIR(.RTN,"""code"":""increase"",""display"":""Increased score indicates improvement""}]},")
 DO ADDLN^C0FHIR(.RTN,"""group"":[{""population"":[")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("initial-population","Initial Population",IPP)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("denominator","Denominator",DENOM)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("numerator","Numerator",NUMER)_",")
 DO ADDLN^C0FHIR(.RTN,$$POPJ("denominator-exclusion","Denominator Exclusion",DENEX)_"]}]}")
 QUIT
 ;
BUNDLE(RTN,CMS,REP,DFN) ; Append transaction Bundle: Organization + live report
 NEW RID,TS
 SET DFN=+$GET(DFN)
 SET RID=$$RPTID(CMS,.REP,DFN)
 SET TS=$$NOWISO()
 DO ADDLN^C0FHIR(.RTN,"{""resourceType"":""Bundle"",""id"":"""_RID_"-transaction"",""type"":""transaction"",""timestamp"":"""_TS_""",""entry"":[")
 DO ADDLN^C0FHIR(.RTN,"{""fullUrl"":""urn:uuid:"_REP("id")_""",""resource"":")
 DO ORG(.RTN,.REP)
 DO ADDLN^C0FHIR(.RTN,",""request"":{""method"":""PUT"",""url"":""Organization/"_REP("id")_"""}},")
 DO ADDLN^C0FHIR(.RTN,"{""fullUrl"":""urn:uuid:"_RID_""",""resource"":")
 ; Use paired IFs (not ELSE) so $TEST does not leak to the caller's ELSE.
 IF DFN>0 DO INDVREP(.RTN,CMS,DFN,.REP)
 IF DFN<1 DO REPORT(.RTN,CMS,.REP)
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
RPTID(CMS,REP,DFN) ; $$ - live report id (distinct from frozen artifact ids)
 IF +$GET(DFN)>0 QUIT CMS_"-"_$GET(REP("tag"))_"Patient-"_+DFN_"-live-indv-deqm"
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
 ;----- One-click validate / submit (accept, queue TaskMan task, poll) -----
WSVAL(ARGS,BODY,RESULT) ; POST /fhir-quality-report-validate?measure=
 IF '$DATA(RESULT) DO WSGO2(.ARGS,.BODY,"validate") QUIT ""
 DO WSGO2(.RESULT,.BODY,"validate")
 QUIT ""
 ;
WSSUB(ARGS,BODY,RESULT) ; POST /fhir-quality-report-submit?measure=
 IF '$DATA(RESULT) DO WSGO2(.ARGS,.BODY,"submit") QUIT ""
 DO WSGO2(.RESULT,.BODY,"submit")
 QUIT ""
 ;
WSGO2(OUT,BODY,OP) ; Accept request; queue TaskMan worker (avoids proxy timeouts)
 NEW CMS,DFN,ERR,TMP
 SET U="^",HTTPRSP("mime")="application/json"
 KILL OUT
 DO SEED^C0FQUAL
 SET CMS=$$FIND^C0FQUAL($GET(HTTPARGS("measure")))
 SET DFN=+$GET(HTTPARGS("dfn"))
 IF CMS="" DO OO^C0FWAIS(.OUT,"error","invalid","Missing or unknown measure") QUIT
 IF DFN>0 DO  QUIT:$GET(ERR)'=""
 . IF '$$HASPOP^C0FQUAL(CMS,DFN) SET ERR=1 DO OO^C0FWAIS(.OUT,"error","invalid","No SETPOP row for "_CMS_" DFN "_DFN) QUIT
 . SET ^C0FQUAL("REPORT",CMS,"INDV",DFN,OP)="running^"_$$NOW^XLFDT
 ELSE  DO  QUIT:$GET(ERR)'=""
 . IF +$$SUM^C0FQUAL(CMS,1)<1 SET ERR=1 DO OO^C0FWAIS(.OUT,"error","invalid","No aggregate summary stored for "_CMS) QUIT
 . SET ^C0FQUAL("REPORT",CMS,OP)="running^"_$$NOW^XLFDT
 ; Queue via TaskMan (SAC): VALT/SUBT restore CMS/DFN from the task symbol table
 NEW ZTRTN,ZTDESC,ZTDTH,ZTIO,ZTSAVE,ZTSK
 SET ZTRTN=$SELECT(OP="validate":"VALT^C0FQRPT",1:"SUBT^C0FQRPT")
 SET ZTDESC="C0F quality report "_OP_" "_CMS_$SELECT(DFN>0:"/"_DFN,1:"")
 SET ZTIO="",ZTDTH=$H
 SET ZTSAVE("CMS")="",ZTSAVE("DFN")=""
 DO ^%ZTLOAD
 IF '$GET(ZTSK) DO  QUIT
 . IF DFN>0 SET ^C0FQUAL("REPORT",CMS,"INDV",DFN,OP)="error^"_$$NOW^XLFDT_"^TaskMan queue failed"
 . ELSE  SET ^C0FQUAL("REPORT",CMS,OP)="error^"_$$NOW^XLFDT_"^TaskMan queue failed"
 . DO OO^C0FWAIS(.OUT,"error","exception","TaskMan queue failed for "_OP)
 KILL TMP
 SET TMP("status")="accepted",TMP("measure")=CMS,TMP("op")=OP,TMP("task")=+ZTSK
 IF DFN>0 SET TMP("dfn")=DFN
 SET TMP("message")="Queued as TaskMan task "_+ZTSK_"; reload for status."
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 IF $DATA(ERR) DO OO^C0FWAIS(.OUT,"error","exception","Unable to encode response") QUIT
 QUIT
 ;
VALT ; TaskMan entry: validate live report; CMS/DFN restored via ZTSAVE
 SET ZTREQ="@"
 DO VALJ($GET(CMS),+$GET(DFN))
 QUIT
 ;
SUBT ; TaskMan entry: submit live Bundle; CMS/DFN restored via ZTSAVE
 SET ZTREQ="@"
 DO SUBJ($GET(CMS),+$GET(DFN))
 QUIT
 ;
VALJ(CMS,DFN) ; Background worker: live report -> cds1 /quality/validate-report
 NEW DET,ERR,FIRST,KN,LINES,NA,PROF,RAW,REP,RESP,ST
 SET CMS=$$FIND^C0FQUAL($GET(CMS)) QUIT:CMS=""
 SET DFN=+$GET(DFN)
 DO REPORTER(.REP)
 KILL LINES
 DO ADDLN^C0FHIR(.LINES,"{""report"":")
 IF DFN>0 DO INDVREP(.LINES,CMS,DFN,.REP)
 ELSE  DO REPORT(.LINES,CMS,.REP)
 IF DFN>0 DO
 . SET PROF="http://hl7.org/fhir/us/davinci-deqm/StructureDefinition/indv-measurereport-deqm"
 . DO ADDLN^C0FHIR(.LINES,",""profile"":"""_PROF_"""}")
 ELSE  DO ADDLN^C0FHIR(.LINES,"}")
 DO CALLCDS1("/quality/validate-report",.LINES,.RESP,.ERR,.RAW)
 DO SAVERAW(CMS,"validate",.RAW,DFN)
 IF $GET(ERR)'="" DO LOGRUN(CMS,"validate","error",ERR,DFN) QUIT
 SET ST=$GET(RESP("status")) IF ST="" SET ST="error"
 SET NA=$$NCOUNT(.RESP,"actionableErrors"),KN=$$NCOUNT(.RESP,"knownIgNoise")
 SET DET="errors="_+$GET(RESP("severityCounts","error"))_" warnings="_+$GET(RESP("severityCounts","warning"))_" actionable="_NA_" knownNoise="_KN
 IF ST="fail" SET FIRST=$GET(RESP("actionableErrors",1,"text")) IF FIRST'="" SET DET=DET_"; "_$EXTRACT(FIRST,1,80)
 DO LOGRUN(CMS,"validate",ST,DET,DFN)
 QUIT
 ;
SUBJ(CMS,DFN) ; Background worker: live Bundle -> cds1 /quality/submit-report -> receiver
 NEW DET,ENT,ERR,I,LINES,RAW,REP,RESP,ST
 SET CMS=$$FIND^C0FQUAL($GET(CMS)) QUIT:CMS=""
 SET DFN=+$GET(DFN)
 DO REPORTER(.REP)
 KILL LINES
 DO ADDLN^C0FHIR(.LINES,"{""bundle"":")
 DO BUNDLE(.LINES,CMS,.REP,DFN)
 DO ADDLN^C0FHIR(.LINES,"}")
 DO CALLCDS1("/quality/submit-report",.LINES,.RESP,.ERR,.RAW)
 DO SAVERAW(CMS,"submit",.RAW,DFN)
 IF $GET(ERR)'="" DO LOGRUN(CMS,"submit","error",ERR,DFN) QUIT
 SET ST=$GET(RESP("status")) IF ST="" SET ST="error"
 SET ENT="",I=0
 FOR  SET I=$ORDER(RESP("entryStatuses",I)) QUIT:'I  SET ENT=ENT_$SELECT(ENT="":"",1:", ")_$GET(RESP("entryStatuses",I))
 SET DET="HTTP "_+$GET(RESP("httpStatus"))_$SELECT(ENT'="":"; "_ENT,1:"")_"; receiver "_$GET(RESP("receiver"))
 DO LOGRUN(CMS,"submit",ST,DET,DFN)
 QUIT
 ;
NCOUNT(ARR,KEY) ; $$ - count numeric child nodes under ARR(KEY)
 NEW I,N
 SET (I,N)=0
 FOR  SET I=$ORDER(ARR(KEY,I)) QUIT:'I  SET N=N+1
 QUIT N
 ;
CALLCDS1(PATH,JSON,OUT,ERR,RAW) ; POST chunked JSON lines to the cds1 quality sidecar
 NEW HDR,OPT,PAYLOAD,RET,STATUS,URL
 KILL OUT,ERR,RAW,PAYLOAD,RET,HDR
 DO CHUNK^C0FWAIS(.JSON,.PAYLOAD)
 SET OPT("header",1)="Expect:"
 SET URL="https://cds1.vistaplex.org"_PATH
 SET STATUS=$$%^%WC(.RET,"POST",URL,.PAYLOAD,"application/json",300,.HDR,.OPT)
 IF +$GET(STATUS)'=0 SET ERR="cds1 curl exit status "_STATUS QUIT
 IF $GET(HDR("STATUS"))'="",($GET(HDR("STATUS"))<200!($GET(HDR("STATUS"))>299)) SET ERR="cds1 HTTP status "_$GET(HDR("STATUS")) QUIT
 MERGE RAW=RET
 DO DECODE^XLFJSON("RET","OUT","ERR")
 IF $DATA(ERR) SET ERR="Unable to decode cds1 response JSON" QUIT
 IF $GET(OUT("status"))="error" SET ERR=$GET(OUT("message"),"cds1 error") QUIT
 QUIT
 ;
SAVERAW(CMS,OP,RAW,DFN) ; Keep full cds1 response for the latest run of CMS/op[/dfn]
 SET DFN=+$GET(DFN)
 IF DFN>0 DO  QUIT
 . KILL ^C0FQUAL("REPORT",CMS,"INDV",DFN,OP,"json")
 . IF $DATA(RAW) MERGE ^C0FQUAL("REPORT",CMS,"INDV",DFN,OP,"json")=RAW
 KILL ^C0FQUAL("REPORT",CMS,OP,"json")
 IF $DATA(RAW) MERGE ^C0FQUAL("REPORT",CMS,OP,"json")=RAW
 QUIT
 ;
WSOUT(RTN,FILTER) ; GET /fhir-quality-report-outcome?measure=&op=[&dfn=][&view=html]
 NEW CMS,DFN,OP
 KILL RTN
 DO SEED^C0FQUAL
 SET CMS=$$FIND^C0FQUAL($GET(FILTER("measure")))
 SET DFN=+$GET(FILTER("dfn"))
 SET OP=$GET(FILTER("op")) IF OP'="submit" SET OP="validate"
 IF CMS="" DO RPTERR(.RTN,"Unknown measure; use ?measure=CMS165v14&op=validate|submit") QUIT
 IF DFN>0,'$DATA(^C0FQUAL("REPORT",CMS,"INDV",DFN,OP,"json")) DO RPTERR(.RTN,"No stored "_OP_" outcome for "_CMS_" DFN "_DFN_"; run "_OP_" from the measure dashboard first") QUIT
 IF DFN<1,'$DATA(^C0FQUAL("REPORT",CMS,OP,"json")) DO RPTERR(.RTN,"No stored "_OP_" outcome for "_CMS_"; run "_OP_" from /fhir-quality-reporting first") QUIT
 IF $$UPCASE^C0FHIR($GET(FILTER("view")))="HTML" DO OUTPAGE(.RTN,CMS,OP,DFN) QUIT
 IF DFN>0 MERGE RTN=^C0FQUAL("REPORT",CMS,"INDV",DFN,OP,"json")
 ELSE  MERGE RTN=^C0FQUAL("REPORT",CMS,OP,"json")
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
OUTPAGE(RTN,CMS,OP,DFN) ; Human-readable rendering of the stored outcome
 NEW QDFN,SUB,TITLE,TJURL
 SET DFN=+$GET(DFN)
 SET TITLE=$SELECT(OP="validate":"Validation outcome",1:"Submission outcome")
 IF DFN>0 DO
 . IF OP="validate" SET SUB="HL7 validator (davinci-deqm 5.0.0) — live Individual MeasureReport (Patient/"_DFN_")"
 . ELSE  SET SUB="DEQM receiver (deqm-test-server) — live Individual Bundle (Patient/"_DFN_")"
 ELSE  DO
 . IF OP="validate" SET SUB="HL7 validator (davinci-deqm 5.0.0, hosted on cds1) — live DEQM Summary MeasureReport"
 . ELSE  SET SUB="Reference DEQM receiver (deqm-test-server on cds1) — live submission Bundle"
 DO HDR^C0FQUAL(.RTN,CMS_$SELECT(DFN>0:" / Patient/"_DFN,1:"")_" — "_TITLE,SUB)
 DO ADDLN^C0FHIR(.RTN,"<div class=""links"">")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-reporting"">Reporting pipeline</a>")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-dashboards/"_CMS_""">"_CMS_" dashboard</a>")
 SET TJURL="/fhir?view=browser&amp;source=qualityreport&amp;measure="_CMS
 IF DFN>0 SET TJURL=TJURL_"&amp;dfn="_DFN
 DO ADDLN^C0FHIR(.RTN,$$TJBTN^C0FQUAL(TJURL,"TJSON"))
 SET QDFN=$SELECT(DFN>0:"&amp;dfn="_DFN,1:"")
 DO ADDLN^C0FHIR(.RTN,"<a href=""/fhir-quality-report-outcome?measure="_CMS_"&amp;op="_OP_QDFN_""">raw JSON</a>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO ADDLN^C0FHIR(.RTN,"<div id=""out"" class=""card"">Loading outcome&hellip;</div>")
 DO ADDLN^C0FHIR(.RTN,"<script>")
 DO ADDLN^C0FHIR(.RTN,"(async function(){")
 DO ADDLN^C0FHIR(.RTN,"var el=document.getElementById('out');")
 DO ADDLN^C0FHIR(.RTN,"function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}")
 DO ADDLN^C0FHIR(.RTN,"function chip(st){var c=(st==='pass'||st==='accepted')?'yes':(st==='running'?'na':'no');return '<span class=""'+c+'"">'+esc(st)+'</span>';}")
 DO ADDLN^C0FHIR(.RTN,"try{")
 DO ADDLN^C0FHIR(.RTN,"var r=await fetch('/fhir-quality-report-outcome?measure="_CMS_"&op="_OP_$SELECT(DFN>0:"&dfn="_DFN,1:"")_"');")
 DO ADDLN^C0FHIR(.RTN,"if(!r.ok)throw new Error('HTTP '+r.status);")
 DO ADDLN^C0FHIR(.RTN,"var d=await r.json();")
 DO ADDLN^C0FHIR(.RTN,"var h='<h2 style=""margin-top:0"">Status: '+chip(d.status)+'</h2>';")
 DO ADDLN^C0FHIR(.RTN,"if(d.profile)h+='<p class=""muted"">Validated against <code>'+esc(d.profile)+'</code></p>';")
 DO ADDLN^C0FHIR(.RTN,"if(d.severityCounts){var ks=Object.keys(d.severityCounts);h+='<p>'+ks.map(function(k){return '<strong>'+esc(k)+':</strong> '+d.severityCounts[k];}).join(' &middot; ')+'</p>';}")
 DO ADDLN^C0FHIR(.RTN,"if(d.actionableErrors){h+='<h3>Actionable errors</h3>';h+=d.actionableErrors.length?'<ul>'+d.actionableErrors.map(function(e){return '<li class=""no"">'+esc(e)+'</li>';}).join('')+'</ul>':'<p class=""yes"">None &mdash; every reported error is known IG noise.</p>';}")
 DO ADDLN^C0FHIR(.RTN,"if(d.knownIgNoise&&d.knownIgNoise.length)h+='<h3>Known IG noise (ignored)</h3><ul class=""muted"">'+d.knownIgNoise.map(function(e){return '<li>'+esc(e)+'</li>';}).join('')+'</ul>';")
 DO ADDLN^C0FHIR(.RTN,"var oo=d.operationOutcome;")
 DO ADDLN^C0FHIR(.RTN,"if(oo&&oo.issue){")
 DO ADDLN^C0FHIR(.RTN,"h+='<h3>All validator issues</h3><table><tr><th>Severity</th><th>Location</th><th>Message</th></tr>';")
 DO ADDLN^C0FHIR(.RTN,"oo.issue.forEach(function(is){")
 DO ADDLN^C0FHIR(.RTN,"var sev=is.severity||'';var cls=sev==='error'?'no':(sev==='warning'?'':'muted');")
 DO ADDLN^C0FHIR(.RTN,"var line='';(is.extension||[]).forEach(function(x){if(String(x.url||'').indexOf('issue-line')>-1)line='line '+x.valueInteger;});")
 DO ADDLN^C0FHIR(.RTN,"var loc=(is.expression&&is.expression.join(', '))||(is.location&&is.location.join(', '))||'';")
 DO ADDLN^C0FHIR(.RTN,"if(line)loc=loc?loc+' ('+line+')':line;")
 DO ADDLN^C0FHIR(.RTN,"var msg=(is.details&&is.details.text)||is.diagnostics||'';")
 DO ADDLN^C0FHIR(.RTN,"h+='<tr><td class=""'+cls+'"">'+esc(sev)+'</td><td class=""muted"">'+esc(loc)+'</td><td>'+esc(msg)+'</td></tr>';});")
 DO ADDLN^C0FHIR(.RTN,"h+='</table>';")
 DO ADDLN^C0FHIR(.RTN,"if(oo.text&&oo.text.div)h+='<details><summary class=""muted"">Validator narrative (HL7 validator rendering)</summary><div>'+oo.text.div+'</div></details>';")
 DO ADDLN^C0FHIR(.RTN,"}")
 DO ADDLN^C0FHIR(.RTN,"if(d.receiver)h+='<p><strong>Receiver:</strong> <code>'+esc(d.receiver)+'</code> &mdash; HTTP '+esc(d.httpStatus)+'</p>';")
 DO ADDLN^C0FHIR(.RTN,"if(d.entryStatuses){h+='<h3>Receiver entry results</h3><table><tr><th>Entry</th><th>Status</th></tr>';")
 DO ADDLN^C0FHIR(.RTN,"var names=['Organization (reporter)','MeasureReport ("_$SELECT(DFN>0:"individual",1:"summary")_")'];")
 DO ADDLN^C0FHIR(.RTN,"d.entryStatuses.forEach(function(s,i){h+='<tr><td>'+esc(names[i]||('entry '+(i+1)))+'</td><td class=""'+(String(s).charAt(0)==='2'?'yes':'no')+'"">'+esc(s)+'</td></tr>';});h+='</table>';}")
 DO ADDLN^C0FHIR(.RTN,"if(d.response)h+='<details><summary class=""muted"">Full receiver response Bundle (JSON)</summary><pre style=""white-space:pre-wrap"">'+esc(JSON.stringify(d.response,null,2))+'</pre></details>';")
 DO ADDLN^C0FHIR(.RTN,"el.innerHTML=h;")
 DO ADDLN^C0FHIR(.RTN,"}catch(e){el.innerHTML='<span class=""no"">Failed to load outcome: '+esc(e)+'</span>';}")
 DO ADDLN^C0FHIR(.RTN,"})();")
 DO ADDLN^C0FHIR(.RTN,"</script>")
 DO FTR^C0FQUAL(.RTN)
 SET HTTPRSP("mime")="text/html"
 QUIT
 ;
LOGRUN(CMS,OP,ST,DET,DFN) ; Store run status + append evidence-log row
 NEW N,TS
 SET DFN=+$GET(DFN),TS=$$NOW^XLFDT,DET=$EXTRACT($GET(DET),1,180)
 IF DFN>0 SET ^C0FQUAL("REPORT",CMS,"INDV",DFN,OP)=ST_"^"_TS_"^"_DET
 ELSE  SET ^C0FQUAL("REPORT",CMS,OP)=ST_"^"_TS_"^"_DET
 SET N=$ORDER(^C0FQUAL("REPORT","LOG",""),-1)+1
 SET ^C0FQUAL("REPORT","LOG",N)=TS_"^"_CMS_"^"_OP_"^"_ST_"^"_DET_$SELECT(DFN>0:"^"_DFN,1:"")
 QUIT
 ;
OUTLNK(CMS,OP,DFN) ; $$ - details link when a full outcome is stored
 SET DFN=+$GET(DFN)
 IF DFN>0,'$DATA(^C0FQUAL("REPORT",CMS,"INDV",DFN,OP,"json")) QUIT ""
 IF DFN<1,'$DATA(^C0FQUAL("REPORT",CMS,OP,"json")) QUIT ""
 QUIT "<br><a href=""/fhir-quality-report-outcome?measure="_CMS_"&amp;op="_OP_$SELECT(DFN>0:"&amp;dfn="_DFN,1:"")_"&amp;view=html"">details (full "_$SELECT(OP="validate":"OperationOutcome",1:"receiver response")_")</a>"
 ;
OPSTAT(CMS,OP,DFN) ; $$ - short status line for page display
 NEW DET,ROW,ST,TS
 SET DFN=+$GET(DFN)
 IF DFN>0 SET ROW=$GET(^C0FQUAL("REPORT",CMS,"INDV",DFN,OP))
 ELSE  SET ROW=$GET(^C0FQUAL("REPORT",CMS,OP))
 IF ROW="" QUIT ""
 SET ST=$PIECE(ROW,"^",1),TS=$PIECE(ROW,"^",2),DET=$PIECE(ROW,"^",3)
 IF TS'="" SET TS=$$FMTE^XLFDT($PIECE(TS,"."),5)
 QUIT ST_$SELECT(TS'="":" "_TS,1:"")_$SELECT(DET'="":" — "_$EXTRACT(DET,1,80),1:"")
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
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Validate</strong> — the <em>Validate</em> button sends the live report to the HL7 validator (davinci-deqm 5.0.0 package, hosted on cds1) and records the outcome below.</li>")
 DO ADDLN^C0FHIR(.RTN,"<li><strong>Submit</strong> — the <em>Submit</em> button sends the transaction Bundle (reporter Organization + MeasureReport) to the hosted reference DEQM receiver (deqm-test-server on cds1) and records the receiver response below.</li>")
 DO ADDLN^C0FHIR(.RTN,"</ol>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">This replaces QRDA Category III aggregate reporting on the CMS FHIR dQM path. Live exports are tagged <code>setsum-live</code> with cohort provenance; frozen artifacts under the MeasureReport index hold the reviewed official-cql freeze used for exchange.</p>")
 DO ADDLN^C0FHIR(.RTN,"<p>Per-patient <strong>Individual</strong> MeasureReports (QRDA Category I analogue) live on each")
 DO ADDLN^C0FHIR(.RTN," measure dashboard's curated cohort table — open a measure below, then use the live indv report /")
 DO ADDLN^C0FHIR(.RTN," Validate / Submit controls on a patient row.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 ;
 DO ADDLN^C0FHIR(.RTN,"<h2>Active measures — live reports</h2>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>CMS ID</th><th>Measure</th><th>IPP / DENOM / NUMER / DENEX</th><th>Rate</th><th>As of</th><th>Provenance</th><th>Live report</th><th>Validate</th><th>Submit</th><th>Frozen (official-cql)</th></tr>")
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
 . . SET LNK=LNK_" "_$$TJBTN^C0FQUAL("/fhir?view=browser&amp;source=qualityreport&amp;measure="_CMS)
 . . SET ROW=ROW_"<td>"_LNK_"</td>"
 . . SET ROW=ROW_"<td><button type=""button"" class=""btn rptop"" data-m="""_CMS_""" data-op=""validate"">Validate</button><br><span class=""muted"" id=""st-validate-"_CMS_""">"_$$HTMLESC^C0FHIR($$OPSTAT(CMS,"validate"))_"</span>"_$$OUTLNK(CMS,"validate")_"</td>"
 . . SET ROW=ROW_"<td><button type=""button"" class=""btn rptop"" data-m="""_CMS_""" data-op=""submit"">Submit</button><br><span class=""muted"" id=""st-submit-"_CMS_""">"_$$HTMLESC^C0FHIR($$OPSTAT(CMS,"submit"))_"</span>"_$$OUTLNK(CMS,"submit")_"</td>"
 . ELSE  SET ROW=ROW_"<td class=""muted"">—</td><td class=""muted"">—</td><td class=""muted"">—</td>"
 . SET LNK="<a href=""/filesystem/quality/measurereports/"_CMS_"/summary-deqm.json"">summary-deqm</a>"
 . SET LNK=LNK_" · <a href=""/filesystem/quality/measurereports/"_CMS_"/index.html"">index</a>"
 . SET ROW=ROW_"<td>"_LNK_"</td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 DO ADDLN^C0FHIR(.RTN,"</table>")
 DO ADDLN^C0FHIR(.RTN,"<script>")
 DO ADDLN^C0FHIR(.RTN,"(function(){")
 DO ADDLN^C0FHIR(.RTN,"function wire(b){b.addEventListener('click',async function(){")
 DO ADDLN^C0FHIR(.RTN,"var m=b.getAttribute('data-m'),op=b.getAttribute('data-op');")
 DO ADDLN^C0FHIR(.RTN,"var s=document.getElementById('st-'+op+'-'+m);")
 DO ADDLN^C0FHIR(.RTN,"b.disabled=true;if(s)s.textContent='starting…';")
 DO ADDLN^C0FHIR(.RTN,"try{var r=await fetch('/fhir-quality-report-'+op+'?measure='+m,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});")
 DO ADDLN^C0FHIR(.RTN,"var t=await r.text(),j={};try{j=JSON.parse(t)}catch(e){j={status:'error',message:t.slice(0,120)||('HTTP '+r.status)};}")
 DO ADDLN^C0FHIR(.RTN,"if(!r.ok||j.status==='error'){if(s)s.textContent='error: '+(j.message||('HTTP '+r.status));b.disabled=false;return;}")
 DO ADDLN^C0FHIR(.RTN,"if(s)s.textContent='running… (page reloads)';setTimeout(function(){location.reload();},5000);")
 DO ADDLN^C0FHIR(.RTN,"}catch(e){if(s)s.textContent='error: '+e;b.disabled=false;}});}")
 DO ADDLN^C0FHIR(.RTN,"var bs=document.querySelectorAll('.rptop');for(var i=0;i<bs.length;i++)wire(bs[i]);")
 DO ADDLN^C0FHIR(.RTN,"})();")
 DO ADDLN^C0FHIR(.RTN,"</script>")
 DO RPTLOG(.RTN)
 ;
 DO ADDLN^C0FHIR(.RTN,"<div class=""card"">")
 DO ADDLN^C0FHIR(.RTN,"<h2 style=""margin-top:0"">Reporter for this server</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p>Live reports from this server are attributed to <strong>"_$$HTMLESC^C0FHIR(REP("name"))_"</strong> (<code>Organization/"_REP("id")_"</code>).</p>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">The submission Bundle carries this Organization so the receiver can resolve MeasureReport.reporter.</p>")
 DO ADDLN^C0FHIR(.RTN,"</div>")
 DO FTR^C0FQUAL(.RTN)
 SET HTTPRSP("mime")="text/html"
 QUIT
 ;
RPTLOG(RTN) ; Evidence log: last 20 validate/submit runs (newest first)
 NEW CNT,DET,LDFN,LCMS,LBL,N,OP,ROW,ST,STC,TS
 ; ROW reused for HTML table rows
 DO ADDLN^C0FHIR(.RTN,"<h2>Evidence log</h2>")
 DO ADDLN^C0FHIR(.RTN,"<p class=""muted"">Each validate/submit run (summary or individual) is recorded here (newest first). The latest run per measure/step[/patient] links to its full outcome.</p>")
 DO ADDLN^C0FHIR(.RTN,"<table><tr><th>When</th><th>Measure</th><th>Step</th><th>Outcome</th><th>Detail</th></tr>")
 SET CNT=0,N=""
 FOR  SET N=$ORDER(^C0FQUAL("REPORT","LOG",N),-1) QUIT:'N!(CNT'<20)  DO
 . SET ROW=$GET(^C0FQUAL("REPORT","LOG",N)) QUIT:ROW=""
 . SET CNT=CNT+1
 . SET TS=$$FMTE^XLFDT($PIECE(ROW,"^",1),1),LCMS=$PIECE(ROW,"^",2),OP=$PIECE(ROW,"^",3)
 . SET ST=$PIECE(ROW,"^",4),DET=$PIECE(ROW,"^",5),LDFN=+$PIECE(ROW,"^",6)
 . SET LBL=LCMS_$SELECT(LDFN>0:" / Patient/"_LDFN,1:"")
 . SET STC=$$HTMLESC^C0FHIR(ST)
 . ; Link the outcome when this row is the latest run for its measure/step[/dfn]
 . ; Paired IFs (not ELSE) — avoid $TEST leak from nested IF inside DO.
 . IF LDFN>0,$PIECE(ROW,"^",1)=$PIECE($GET(^C0FQUAL("REPORT",LCMS,"INDV",LDFN,OP)),"^",2),$DATA(^C0FQUAL("REPORT",LCMS,"INDV",LDFN,OP,"json")) DO
 . . SET STC="<a href=""/fhir-quality-report-outcome?measure="_LCMS_"&amp;op="_OP_"&amp;dfn="_LDFN_"&amp;view=html"">"_STC_"</a>"
 . IF LDFN<1,$PIECE(ROW,"^",1)=$PIECE($GET(^C0FQUAL("REPORT",LCMS,OP)),"^",2),$DATA(^C0FQUAL("REPORT",LCMS,OP,"json")) DO
 . . SET STC="<a href=""/fhir-quality-report-outcome?measure="_LCMS_"&amp;op="_OP_"&amp;view=html"">"_STC_"</a>"
 . SET ROW="<tr><td>"_$$HTMLESC^C0FHIR(TS)_"</td><td>"_$$HTMLESC^C0FHIR(LBL)_"</td><td>"_$$HTMLESC^C0FHIR(OP)_"</td>"
 . SET ROW=ROW_"<td class="""_$SELECT(ST="pass"!(ST="accepted"):"yes",ST="running":"na",1:"no")_""">"_STC_"</td>"
 . SET ROW=ROW_"<td class=""muted"">"_$$HTMLESC^C0FHIR(DET)_"</td></tr>"
 . DO ADDLN^C0FHIR(.RTN,ROW)
 IF CNT=0 DO ADDLN^C0FHIR(.RTN,"<tr><td colspan=""5"" class=""muted"">No runs recorded yet — use Validate / Submit above or on a measure dashboard.</td></tr>")
 DO ADDLN^C0FHIR(.RTN,"</table>")
 QUIT
