C0FWAIS ; VEHU/Codex - AI Consult web service orchestration ;Jun 05, 2026
 ;;0.1;C0FHIR PROJECT;;Jun 05, 2026
 ;
 Q
 ;
WS(OUT,FILTER) ; GET /aiconsult?dfn=&file=0|1&mode=&measure=
 N AI,DFN,ERR,FILE,MEASURE,MODE,PAT,PATJSON,REQ,RESP,REPORTS,STAGE,TMP,UPD
 S U="^",HTTPRSP("mime")="application/fhir+json"
 K OUT
 S DFN=+$G(FILTER("dfn"))
 I DFN<1 D OO(.OUT,"error","exception","Missing or invalid dfn parameter") Q
 S FILE=$S($G(FILTER("file"))="0":0,1:1)
 S STAGE=$S($G(FILTER("stage"))="2":2,1:1)
 S MODE=$G(FILTER("mode")),MEASURE=$G(FILTER("measure"))
 D PATBNDL(DFN,.PAT,.PATJSON,.ERR,STAGE)
 I $G(ERR)'="" D OO(.OUT,"error","exception",ERR) Q
 D CALLCDS(.PATJSON,.AI,.ERR,MODE,MEASURE)
 I $G(ERR)'="" D OO(.OUT,"error","exception",ERR) Q
 D DECORATE(.PAT,.AI,.REPORTS)
 I STAGE=2,'$D(REPORTS("entry")) D FBACK(.PAT,.REPORTS)
 D RESP(.PAT,.REPORTS,.RESP)
 I FILE D
 . I '$D(REPORTS("entry")) D ADDOO(.RESP,"information","informational","cds1 returned no DiagnosticReport resources for this patient Bundle") Q
 . D LOADAI(.PAT,.REPORTS,DFN,.UPD,.ERR)
 . I $G(ERR)'="" D ADDOO(.RESP,"warning","exception",ERR) Q
 . D ADDOO(.RESP,"information","informational","AI Consult filing attempted through native /updatepatient; loadStatus="_$G(UPD("loadStatus"),"unknown"))
 E  D ADDOO(.RESP,"information","informational","AI Consult filing skipped because file=0")
 D TOJSON^C0FHIRBU(.RESP,.OUT,.ERR)
 Q
 ;
PATBNDL(DFN,OUT,JSON,ERR,STAGE) ; Build patient Bundle as native array and canonical JSON
 N FILTER
 K OUT,JSON,ERR
 S FILTER("dfn")=+DFN
 I +$G(STAGE)=2 S FILTER("domain")="Condition"
 D GETFHIR^C0FHIR(.JSON,.FILTER)
 D DECODE^XLFJSON("JSON","OUT","ERR")
 I $D(ERR) S ERR="Unable to decode generated patient FHIR Bundle JSON" Q
 I $G(OUT("resourceType"))'="Bundle" S ERR="Unable to build patient FHIR Bundle"
 I $G(ERR)="" D ADDEVID(+DFN,.OUT)
 I $G(ERR)="" D TOJSON^C0FHIRBU(.OUT,.JSON,.ERR)
 I $D(ERR) S ERR="Unable to encode patient FHIR Bundle with graph seed evidence"
 Q
 ;
ADDEVID(DFN,OUT) ; Include graph-only seed evidence resources for AI Consult
 N CNT,IEN,RIEN,ROOT
 S DFN=+$G(DFN)
 Q:DFN<1
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 S IEN=$$DFN2IEN^C0FWFUTL(DFN)
 Q:IEN<1
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  D
 . Q:'$$ISEVID(ROOT,IEN,RIEN)
 . S CNT=$O(OUT("entry",""),-1)+1
 . M OUT("entry",CNT)=@ROOT@(IEN,"json","entry",RIEN)
 Q
 ;
ISEVID(ROOT,IEN,RIEN) ; $$ - true if graph entry is Stage 1/2 seed evidence
 N CI,SYS
 S CI=0
 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI)) Q:+CI=0  D  Q:$G(SYS)=1
 . I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI,"system"))="https://github.com/glilly/cds-hooks-on-fhir/seed/stage1/evidence" S SYS=1
 S CI=0
 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","meta","tag",CI)) Q:+CI=0  D  Q:$G(SYS)=1
 . I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","meta","tag",CI,"system"))="https://github.com/glilly/cds-hooks-on-fhir/seed/stage2/evidence" S SYS=1
 Q +$G(SYS)
 ;
CALLCDS(JSON,AI,ERR,MODE,MEASURE) ; POST patient bundle JSON to cds1
 N HDR,OPT,PAYLOAD,RET,STATUS,URL
 K AI,ERR,PAYLOAD,RET,HDR
 D CHUNK(.JSON,.PAYLOAD)
 S OPT("header",1)="Expect:"
 S URL="https://cds1.vistaplex.org/analyze"
 I $G(MODE)'="" S URL=URL_"?mode="_$G(MODE)
 I $G(MEASURE)'="" S URL=URL_$S(URL["?":"&",1:"?")_"measure="_$G(MEASURE)
 S STATUS=$$%^%WC(.RET,"POST",URL,.PAYLOAD,"application/fhir+json",60,.HDR,.OPT)
 I +$G(STATUS)'=0 S ERR="cds1 curl exit status "_STATUS Q
 I $G(HDR("STATUS"))'="",($G(HDR("STATUS"))<200!($G(HDR("STATUS"))>299)) S ERR="cds1 HTTP status "_$G(HDR("STATUS")) Q
 D DECODE^XLFJSON("RET","AI","ERR")
 I $D(ERR) S ERR="Unable to decode cds1 response JSON"
 Q
 ;
CHUNK(IN,OUT) ; Re-chunk JSON so %WC-added newlines fall outside strings
 N BUF,ESC,I,QUOTE
 K OUT S BUF="",I=""
 S (ESC,QUOTE)=0
 F  S I=$O(IN(I)) Q:I=""  D CHUNK1($G(IN(I)),.OUT,.BUF,.QUOTE,.ESC)
 I BUF'="" S OUT($O(OUT(""),-1)+1)=BUF
 Q
 ;
CHUNK1(TXT,OUT,BUF,QUOTE,ESC) ; Append text and split at safe JSON separators
 N CH,J
 F J=1:1:$L(TXT) D
 . S CH=$E(TXT,J),BUF=BUF_CH
 . I CH="\",'ESC S ESC=1 Q
 . I ESC S ESC=0 Q
 . I CH="""" S QUOTE='QUOTE Q
 . I QUOTE Q
 . I $L(BUF)>3000,(",}]"[CH) S OUT($O(OUT(""),-1)+1)=BUF,BUF=""
 Q
 ;
DECORATE(PAT,AI,OUT) ; Keep and decorate returned DiagnosticReports
 N CNT,I,R
 K OUT
 S CNT=0,I=0
 FOR  S I=$O(AI("entry",I)) Q:+I=0  D
 . Q:$G(AI("entry",I,"resource","resourceType"))'="DiagnosticReport"
 . S CNT=CNT+1
 . M OUT("entry",CNT,"resource")=AI("entry",I,"resource")
 . D DECONE(.PAT,$NA(OUT("entry",CNT,"resource")))
 Q
 ;
DECONE(PAT,R) ; Decorate one DiagnosticReport for C0FWAIC filing
 N D,TITLE
 S D=+$G(PAT("entry",$$PATENT(.PAT),"resource","id"))
 I $G(@R@("subject","reference"))="",D>0 S @R@("subject","reference")="Patient/"_D
 S @R@("category",1,"coding",1,"system")="http://vistaplex.org/fhir/CodeSystem/report-category"
 S @R@("category",1,"coding",1,"code")="ai-consult"
 S @R@("category",1,"coding",1,"display")="AI Consult"
 S @R@("category",1,"text")="AI Consult"
 S TITLE=$G(@R@("code","text"))
 I TITLE="" S TITLE=$G(@R@("code","coding",1,"display"))
 I $$UPCASE^C0FHIR(TITLE)'["AI CONSULT" S TITLE="AI Consult - "_$S(TITLE'="":TITLE,1:"Diagnostic Report")
 S @R@("code","text")=TITLE
 I '$D(@R@("presentedForm")) D
 . S @R@("presentedForm",1,"contentType")="text/markdown"
 . S @R@("presentedForm",1,"title")=TITLE
 . S @R@("presentedForm",1,"data")=$$ENCODE64^SYNWEBUT($S($G(@R@("conclusion"))'="":$G(@R@("conclusion")),1:TITLE))
 Q
 ;
FBACK(PAT,OUT) ; Stage 2 fallback DiagnosticReport from problem-list Conditions
 N CNT,I,ICD,ICDD,N,R,SYS,CODE,DISP,TXT,VSNOM
 K OUT
 S R=$NA(OUT("entry",1,"resource"))
 S CNT=0,I=0
 F  S I=$O(PAT("entry",I)) Q:+I=0  D  Q:CNT'<5
 . Q:$G(PAT("entry",I,"resource","resourceType"))'="Condition"
 . D PRIMCOD($NA(PAT("entry",I,"resource","code")),.SYS,.CODE,.DISP,.TXT,.ICD,.ICDD)
 . Q:CODE=""
 . S CNT=CNT+1
 . S @R@("conclusionCode",CNT,"coding",1,"system")=SYS
 . S @R@("conclusionCode",CNT,"coding",1,"code")=CODE
 . I DISP'="" S @R@("conclusionCode",CNT,"coding",1,"display")=DISP
 . S @R@("conclusionCode",CNT,"text")=$S(DISP'="":DISP,TXT'="":TXT,1:CODE)
 . D PICKEXT(R,CNT,SYS,CODE,DISP,TXT,ICD,ICDD)
 I CNT<1 K OUT Q
 S @R@("resourceType")="DiagnosticReport"
 S @R@("id")="diagnostic-report-problem-list-pick-list"
 S @R@("status")="final"
 S @R@("code","text")="AI Consult - Problem List Pick List"
 S @R@("code","coding",1,"system")="https://github.com/glilly/cds-hooks-on-fhir/terminology-review/stage2"
 S @R@("code","coding",1,"code")="problem-list-pick-list"
 S @R@("code","coding",1,"display")="Problem-list AI Consult pick list"
 S @R@("subject","reference")="Patient/"_+$G(PAT("entry",$$PATENT(.PAT),"resource","id"))
 S @R@("issued")=$$FM2FHIR^C0FHIRBU($$NOW^XLFDT)
 S @R@("conclusion")="Submitted bundle was limited to Patient and problem-list Conditions. These candidates are normalized for provider review and note insertion; no whole-chart analysis was performed."
 S @R@("category",1,"coding",1,"system")="http://vistaplex.org/fhir/CodeSystem/report-category"
 S @R@("category",1,"coding",1,"code")="ai-consult"
 S @R@("category",1,"coding",1,"display")="AI Consult"
 S @R@("category",1,"text")="AI Consult"
 S @R@("presentedForm",1,"contentType")="text/markdown"
 S @R@("presentedForm",1,"title")="Problem-list AI Consult pick list"
 S @R@("presentedForm",1,"data")=$$ENCODE64^SYNWEBUT("# AI Consult Problem List Pick List"_$C(10)_$C(10)_"Selected "_CNT_" existing problem-list condition(s) as visit-purpose candidates."_$C(10)_$C(10)_"No automatic medical-record update was performed."_$C(10))
 Q
 ;
PRIMCOD(NODE,SYS,CODE,DISP,TXT,ICD,ICDD) ; Pick primary Condition code
 N I,TSYS,TCODE,TDISP
 S (SYS,CODE,DISP,ICD,ICDD)="",TXT=$G(@NODE@("text"))
 S I=0 F  S I=$O(@NODE@("coding",I)) Q:+I=0  D
 . S TSYS=$G(@NODE@("coding",I,"system")),TCODE=$G(@NODE@("coding",I,"code")),TDISP=$G(@NODE@("coding",I,"display"))
 . I TSYS["icd-10",ICD="" S ICD=TCODE,ICDD=TDISP
 . I CODE'="" Q
 . I TSYS="http://snomed.info/sct" S SYS=TSYS,CODE=TCODE,DISP=TDISP Q
 . I SYS="" S SYS=TSYS,CODE=TCODE,DISP=TDISP
 Q
 ;
PICKEXT(R,N,SYS,CODE,DISP,TXT,ICD,ICDD) ; Add advisory-pick-list extension
 N E,PL
 S E=$NA(@R@("extension",N))
 S @E@("url")="https://github.com/glilly/cds-hooks-on-fhir/StructureDefinition/advisory-pick-list"
 S @E@("extension",1,"url")="code"
 S @E@("extension",1,"valueCoding","system")=SYS
 S @E@("extension",1,"valueCoding","code")=CODE
 I DISP'="" S @E@("extension",1,"valueCoding","display")=DISP
 S PL=1
 I ICD'="" D
 . S @E@("extension",2,"url")="icd10"
 . S @E@("extension",2,"valueCoding","system")="http://hl7.org/fhir/sid/icd-10-cm"
 . S @E@("extension",2,"valueCoding","code")=ICD
 . I ICDD'="" S @E@("extension",2,"valueCoding","display")=ICDD
 S @E@("extension",3,"url")="role"
 S @E@("extension",3,"valueCode")="problem-list-candidate"
 S @E@("extension",4,"url")="display"
 S @E@("extension",4,"valueString")=$S(DISP'="":DISP,TXT'="":TXT,1:CODE)
 S @E@("extension",5,"url")="supportText"
 S @E@("extension",5,"valueString")="AI Consult selected existing problem-list condition: "_$S(DISP'="":DISP,TXT'="":TXT,1:CODE)_". Provider should edit the wording before inserting into the note."
 S @E@("extension",6,"url")="defaultPov"
 S @E@("extension",6,"valueBoolean")=$S(ICD'="":1,1:0)
 S @E@("extension",7,"url")="defaultProblemList"
 S @E@("extension",7,"valueBoolean")=$S((SYS="http://snomed.info/sct")&(CODE?1.N):1,1:0)
 Q
 ;
RESP(PAT,REPORTS,OUT) ; Build response Bundle
 N CNT,I,P
 K OUT
 S OUT("resourceType")="Bundle",OUT("type")="collection"
 S CNT=0
 S P=$$PATENT(.PAT)
 I P>0 S CNT=CNT+1 M OUT("entry",CNT,"resource")=PAT("entry",P,"resource")
 S I=0 F  S I=$O(REPORTS("entry",I)) Q:+I=0  S CNT=CNT+1 M OUT("entry",CNT)=REPORTS("entry",I)
 Q
 ;
LOADAI(PAT,REPORTS,DFN,UPD,ERR) ; File decorated reports through C0FW updatepatient path
 N BODY,BUNDLE,JSON,UPDLBL
 K BODY,BUNDLE,JSON,UPD,ERR
 S BUNDLE("resourceType")="Bundle",BUNDLE("type")="collection"
 M BUNDLE("entry",1)=PAT("entry",$$PATENT(.PAT))
 N BASE,I,IDX
 S BASE=$O(BUNDLE("entry",""),-1)
 S I=0,IDX=BASE
 F  S I=$O(REPORTS("entry",I)) Q:+I=0  D
 . S IDX=IDX+1
 . M BUNDLE("entry",IDX)=REPORTS("entry",I)
 D TOJSON^C0FHIRBU(.BUNDLE,.BODY,.ERR)
 I $D(ERR) S ERR="Unable to encode AI Consult filing Bundle" Q
 S JSON("dfn")=+DFN,JSON("load")=1,JSON("returngraph")=1
 S UPDLBL="wsUpdatePatient^C0FWUPD(.JSON,.BODY,.UPD)"
 D @UPDLBL
 K JSON D DECODE^XLFJSON("UPD","JSON","ERR")
 I $D(ERR) S ERR="Unable to decode native updatepatient response" Q
 K UPD M UPD=JSON
 Q
 ;
PATENT(PAT) ; Patient entry index
 N I
 S I=0 F  S I=$O(PAT("entry",I)) Q:+I=0  I $G(PAT("entry",I,"resource","resourceType"))="Patient" Q
 Q +I
 ;
NEWENC(PAT) ; Newest Encounter entry index
 N BEST,BVAL,I,V
 S (BEST,BVAL)=0,I=0
 F  S I=$O(PAT("entry",I)) Q:+I=0  D
 . Q:$G(PAT("entry",I,"resource","resourceType"))'="Encounter"
 . S V=$G(PAT("entry",I,"resource","period","start"))
 . I V]BVAL S BVAL=V,BEST=I
 Q +BEST
 ;
ADDOO(BUNDLE,SEV,CODE,MSG) ; Add OperationOutcome entry to response Bundle
 N N
 S N=$O(BUNDLE("entry",""),-1)+1
 S BUNDLE("entry",N,"resource","resourceType")="OperationOutcome"
 S BUNDLE("entry",N,"resource","issue",1,"severity")=$G(SEV)
 S BUNDLE("entry",N,"resource","issue",1,"code")=$G(CODE)
 S BUNDLE("entry",N,"resource","issue",1,"diagnostics")=$G(MSG)
 Q
 ;
OO(OUT,SEV,CODE,MSG) ; Error response
 ; %webreq RSPERROR replaces HTTPRSP when HTTPERR is set, so a custom
 ; OperationOutcome in OUT is discarded. Use SETERROR (HTTP 400) so the
 ; client gets diagnostics instead of HTTP 500 with body "{}".
 N TOP
 K OUT
 S TOP=$G(MSG)
 I TOP="" S TOP=$G(CODE)
 I $L($T(SETERROR^%webutils)) D SETERROR^%webutils(400,TOP) Q
 ; Fallback if %webutils missing: return OO on 200
 N TMP,ERR
 S TMP("resourceType")="OperationOutcome"
 S TMP("issue",1,"severity")=$G(SEV,"error")
 S TMP("issue",1,"code")=$G(CODE,"exception")
 S TMP("issue",1,"diagnostics")=TOP
 D TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 S HTTPRSP("mime")="application/fhir+json"
 Q
 ;
