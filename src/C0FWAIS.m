C0FWAIS ; VEHU/Codex - AI Consult web service orchestration ;Jun 05, 2026
 ;;0.1;C0FHIR PROJECT;;Jun 05, 2026
 ;
 Q
 ;
WS(OUT,FILTER) ; GET /aiconsult?dfn=&file=0|1
 N AI,DFN,ERR,FILE,PAT,PATJSON,REQ,RESP,REPORTS,TMP,UPD
 S U="^",HTTPRSP("mime")="application/fhir+json"
 K OUT
 S DFN=+$G(FILTER("dfn"))
 I DFN<1 D OO(.OUT,"error","exception","Missing or invalid dfn parameter") Q
 S FILE=$S($G(FILTER("file"))="0":0,1:1)
 D PATBNDL(DFN,.PAT,.PATJSON,.ERR)
 I $G(ERR)'="" D OO(.OUT,"error","exception",ERR) Q
 D CALLCDS(.PATJSON,.AI,.ERR)
 I $G(ERR)'="" D OO(.OUT,"error","exception",ERR) Q
 D DECORATE(.PAT,.AI,.REPORTS)
 D RESP(.PAT,.REPORTS,.RESP)
 I FILE D
 . I '$D(REPORTS("entry")) D ADDOO(.RESP,"information","informational","cds1 returned no DiagnosticReport resources for this patient Bundle") Q
 . D FILE(.PAT,.REPORTS,DFN,.UPD,.ERR)
 . I $G(ERR)'="" D ADDOO(.RESP,"warning","exception",ERR) Q
 . D ADDOO(.RESP,"information","informational","AI Consult filing attempted through native /updatepatient; loadStatus="_$G(UPD("loadStatus"),"unknown"))
 E  D ADDOO(.RESP,"information","informational","AI Consult filing skipped because file=0")
 D TOJSON^C0FHIRBU(.RESP,.OUT,.ERR)
 Q
 ;
PATBNDL(DFN,OUT,JSON,ERR) ; Build patient Bundle as native array and canonical JSON
 N FILTER
 K OUT,JSON,ERR
 S FILTER("dfn")=+DFN
 D GETFHIR^C0FHIR(.JSON,.FILTER)
 D DECODE^XLFJSON("JSON","OUT","ERR")
 I $D(ERR) S ERR="Unable to decode generated patient FHIR Bundle JSON" Q
 I $G(OUT("resourceType"))'="Bundle" S ERR="Unable to build patient FHIR Bundle"
 Q
 ;
CALLCDS(JSON,AI,ERR) ; POST patient bundle JSON to cds1
 N HDR,PAYLOAD,RET,STATUS
 K AI,ERR,PAYLOAD,RET,HDR
 D CHUNK(.JSON,.PAYLOAD)
 S STATUS=$$%^%WC(.RET,"POST","https://cds1.vistaplex.org/analyze",.PAYLOAD,"application/fhir+json",60,.HDR)
 I +$G(STATUS)'=0 S ERR="cds1 curl exit status "_STATUS Q
 I $G(HDR("STATUS"))<200!($G(HDR("STATUS"))>299) S ERR="cds1 HTTP status "_$G(HDR("STATUS")) Q
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
 N D,ENC,TITLE
 S D=+$G(PAT("entry",$$PATENT(.PAT),"resource","id"))
 S ENC=$$NEWESTENC(.PAT)
 I $G(@R@("subject","reference"))="",D>0 S @R@("subject","reference")="Patient/"_D
 I $G(@R@("encounter","reference"))="",ENC>0 S @R@("encounter","reference")="Encounter/"_$G(PAT("entry",ENC,"resource","id"))
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
FILE(PAT,REPORTS,DFN,UPD,ERR) ; File decorated reports through C0FW updatepatient path
 N BODY,BUNDLE,JSON
 K BODY,BUNDLE,JSON,UPD,ERR
 S BUNDLE("resourceType")="Bundle",BUNDLE("type")="collection"
 M BUNDLE("entry",1)=PAT("entry",$$PATENT(.PAT))
 I $$NEWESTENC(.PAT)>0 M BUNDLE("entry",2)=PAT("entry",$$NEWESTENC(.PAT))
 N BASE,I,IDX S BASE=$O(BUNDLE("entry",""),-1),I=0,IDX=BASE
 F  S I=$O(REPORTS("entry",I)) Q:+I=0  S IDX=IDX+1 M BUNDLE("entry",IDX)=REPORTS("entry",I)
 D TOJSON^C0FHIRBU(.BUNDLE,.BODY,.ERR)
 I $D(ERR) S ERR="Unable to encode AI Consult filing Bundle" Q
 S JSON("dfn")=+DFN,JSON("load")=1,JSON("returngraph")=1
 D wsUpdatePatient^C0FWUPD(.JSON,.BODY,.UPD)
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
NEWESTENC(PAT) ; Newest Encounter entry index
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
 N TMP,ERR
 K TMP,OUT
 S HTTPERR=$S($G(SEV)="error":502,1:400)
 S TMP("resourceType")="OperationOutcome"
 S TMP("issue",1,"severity")=$G(SEV)
 S TMP("issue",1,"code")=$G(CODE)
 S TMP("issue",1,"diagnostics")=$G(MSG)
 D TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 S HTTPRSP("mime")="application/fhir+json"
 Q
 ;
