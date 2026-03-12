C0FHIR ; VAMC/JS - VistA FHIR Server entry points
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 ; Namespace convention:
 ; - All project MUMPS routines use the C0FHIR prefix.
 ; - New DDE entities defined for this project use the C0FHIR namespace.
 ; - Bundle requests return one multi-domain FHIR Bundle per request.
 ; - JSON encoding standard is ENCODE^XLFJSON.
 ;
 QUIT  ; No default action
 ;
GETPAT(RTN,DFN) ; Add Patient resource to the passed bundle array
 ; RTN is the in-flight Bundle structure
 ; This first version maps core demographic fields from file #2.
 NEW DOB,FAM,GIV,IDX,NAME,SEX,SSN,X0
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Patient",DFN,.IDX)
 SET X0=$GET(^DPT(DFN,0))
 SET NAME=$PIECE(X0,"^")
 SET RTN("entry",IDX,"resource","resourceType")="Patient"
 SET RTN("entry",IDX,"resource","id")=DFN
 IF NAME'="" DO
 . SET RTN("entry",IDX,"resource","name",1,"text")=NAME
 . SET FAM=$$TRIM($PIECE(NAME,",",1))
 . SET GIV=$$TRIM($PIECE(NAME,",",2,99))
 . IF FAM'="" SET RTN("entry",IDX,"resource","name",1,"family")=FAM
 . IF GIV'="" SET RTN("entry",IDX,"resource","name",1,"given",1)=GIV
 SET SEX=$PIECE(X0,"^",2)
 IF SEX'="" SET RTN("entry",IDX,"resource","gender")=$$GENDER(SEX)
 SET DOB=+$PIECE(X0,"^",3)
 IF DOB>0 SET RTN("entry",IDX,"resource","birthDate")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 SET SSN=$PIECE(X0,"^",9)
 IF SSN?9N DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-ssn"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=SSN
 . ; Force JSON string type for SSN (FHIR identifier.value is string)
 . SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 QUIT
 ;
GETENC(RTN,ENCIEN,DFN) ; Add Encounter resource to the passed bundle array
 ; ENCIEN is expected to be a visit ien from ^AUPNVSIT
 NEW CLASS,ENC,IDX,TYPE
 DO ENVINIT
 SET ENCIEN=+ENCIEN
 IF ENCIEN<1 QUIT
 DO EN1^VPRDVSIT(ENCIEN,.ENC)
 DO ADDRES^C0FHIRBU(.RTN,"Encounter","E"_ENCIEN,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Encounter"
 SET RTN("entry",IDX,"resource","id")="E"_ENCIEN
 SET RTN("entry",IDX,"resource","status")="finished"
 SET CLASS=$SELECT($GET(ENC("patientClass"))="IMP":"IMP",1:"AMB")
 SET RTN("entry",IDX,"resource","class","system")="http://terminology.hl7.org/CodeSystem/v3-ActCode"
 SET RTN("entry",IDX,"resource","class","code")=CLASS
 IF +$GET(DFN)>0 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 IF +$GET(ENC("dateTime"))>0 SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(ENC("dateTime"))
 IF +$GET(ENC("departureDateTime"))>0 SET RTN("entry",IDX,"resource","period","end")=$$FM2FHIR^C0FHIRBU(ENC("departureDateTime"))
 SET TYPE=$PIECE($GET(ENC("type")),"^",2)
 IF TYPE'="" SET RTN("entry",IDX,"resource","type",1,"text")=TYPE
 QUIT
 ;
GETCOND(RTN,DFN,BEG,END,MAX) ; Add Condition resources for patient/date range
 DO GETCOND^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETCOND(RTN,PROB,DFN) ; Map one VPR problem to a FHIR Condition resource
 DO SETCOND^C0FHIRD(.RTN,.PROB,$GET(DFN))
 QUIT
 ;
CONDSYS(X) ; Map VPR coding system token to FHIR system URL
 QUIT $$CONDSYS^C0FHIRD($GET(X))
 ;
GETOBS(RTN,DFN,BEG,END,MAX) ; Add Observation resources (vitals) for patient/date range
 DO GETOBS^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETOBS(RTN,VIT,DFN) ; Map one VPR vital entry to a FHIR Observation resource
 DO SETOBS^C0FHIRD(.RTN,.VIT,$GET(DFN))
 QUIT
 ;
ISNUM(X) ; True if X is numeric
 QUIT $$ISNUM^C0FHIRD($GET(X))
 ;
GETALGY(RTN,DFN,BEG,END,MAX) ; Add AllergyIntolerance resources
 DO GETALGY^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETALGY(RTN,REAC,DFN) ; Map one VPR allergy entry to FHIR AllergyIntolerance
 DO SETALGY^C0FHIRD(.RTN,.REAC,$GET(DFN))
 QUIT
 ;
ALGREAC(RTN,REAC,IDX,SEV) ; Add reaction manifestations
 DO ALGREAC^C0FHIRD(.RTN,.REAC,$GET(IDX),$GET(SEV))
 QUIT
 ;
ALGNOTE(RTN,REAC,IDX) ; Add allergy comments as note entries
 DO ALGNOTE^C0FHIRD(.RTN,.REAC,$GET(IDX))
 QUIT
 ;
ALGSEV(X) ; Map allergy severity to FHIR reaction severity
 QUIT $$ALGSEV^C0FHIRD($GET(X))
 ;
GETMED(RTN,DFN,BEG,END,MAX) ; Add MedicationRequest resources
 DO GETMED^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETMED(RTN,MED,DFN) ; Map one VPR medication entry to FHIR MedicationRequest
 DO SETMED^C0FHIRD(.RTN,.MED,$GET(DFN))
 QUIT
 ;
MEDCODE(RTN,MED,IDX) ; Add medication coding details when available
 DO MEDCODE^C0FHIRD(.RTN,.MED,$GET(IDX))
 QUIT
 ;
MEDSTAT(X) ; Map VPR medication status to FHIR MedicationRequest status
 QUIT $$MEDSTAT^C0FHIRD($GET(X))
 ;
GETIMM(RTN,DFN,BEG,END,MAX) ; Add Immunization resources
 DO GETIMM^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETIMM(RTN,IMM,DFN) ; Map one VPR immunization entry to FHIR Immunization
 DO SETIMM^C0FHIRD(.RTN,.IMM,$GET(DFN))
 QUIT
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations (chemistry + micro)
 DO GETLAB^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN) ; Extract one lab subdomain
 DO GETLBSUB^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX),$GET(SUB),.CNT,$GET(LRDFN))
 QUIT
 ;
LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP) ; Build normalized line from ^TMP("LRRR")
 QUIT $$LABLINE^C0FHIRD($GET(SUB),+$GET(DFN),+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP))
 ;
CHLINE(LRDFN,VPRIDT,VPRP,X0) ; Return normalized chemistry line
 QUIT $$CHLINE^C0FHIRD(+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
MILINE(VPRIDT,VPRP,X0) ; Return normalized microbiology line
 QUIT $$MILINE^C0FHIRD(+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
SETLAB(RTN,LINE,SUB,DFN,ORD) ; Map one VPR lab line to FHIR Observation
 DO SETLAB^C0FHIRD(.RTN,$GET(LINE),$GET(SUB),$GET(DFN),$GET(ORD))
 QUIT
 ;
LABMETA(RTN,IDX,LINE,ORD) ; Add lab interpretation/range/order metadata
 DO LABMETA^C0FHIRD(.RTN,$GET(IDX),$GET(LINE),$GET(ORD))
 QUIT
 ;
LABDT(X) ; Convert inverse FM date piece from lab id to FHIR dateTime
 QUIT $$LABDT^C0FHIRD($GET(X))
 ;
LABID(X) ; Normalize lab id to FHIR-safe id
 QUIT $$LABID^C0FHIRD($GET(X))
 ;
RPCFHIR(RTN,DFN,ENC,START,END,MAX,MODE,DOMAINS) ; RPC entry point (scalar params)
 ; Broker-friendly wrapper around GETFHIR.
 ; Inputs:
 ;   DFN   - required patient identifier
 ;   ENC   - optional encounter id
 ;   START - optional start date (FM or %DT expression, e.g. T-30)
 ;   END   - optional end date (FM or %DT expression, e.g. NOW)
 ;   MAX   - optional numeric cap on resources
 ;   MODE  - optional ENCOUNTER or DATERANGE
 ;   DOMAINS - optional comma-separated domain list
 ;             (for example: "encounter,condition,vitals,labs")
 NEW FILTER
 KILL RTN
 IF $GET(DFN)'="" SET FILTER("dfn")=$GET(DFN)
 IF $GET(ENC)'="" SET FILTER("encounter")=$GET(ENC)
 IF $GET(START)'="" SET FILTER("start")=$GET(START)
 IF $GET(END)'="" SET FILTER("end")=$GET(END)
 IF +$GET(MAX)>0 SET FILTER("max")=+$GET(MAX)
 IF $GET(MODE)'="" SET FILTER("mode")=$GET(MODE)
 IF $GET(DOMAINS)'="" SET FILTER("domains")=$GET(DOMAINS)
 DO GETFHIR(.RTN,.FILTER)
 QUIT
 ;
RPCFHIRA(RTN,FILTER) ; RPC entry point (array params)
 ; FILTER mirrors web entry parameter names, for example:
 ;   FILTER("dfn")=12345
 ;   FILTER("encounter")=<enc-id>
 ;   FILTER("start")=<fm-date-time or %DT expression>
 ;   FILTER("end")=<fm-date-time or %DT expression>
 ;   FILTER("max")=<n>
 ;   FILTER("mode")="encounter" or "daterange"
 ;   FILTER("domains")="encounter,condition,vitals,labs"
 DO GETFHIR(.RTN,.FILTER)
 QUIT
 ;
GETFHIR(RTN,FILTER) ; Web service entry point
 ; FILTER contains URL parameters, for example FILTER("dfn")=12345
 ; RTN returns JSON output nodes from ENCODE^XLFJSON
 NEW ERR,REQ,TMP,VIEW
 DO ENVINIT
 KILL RTN
 DO MAPFILT(.FILTER,.REQ)
 SET VIEW=$$UPCASE($SELECT($GET(FILTER("view"))'="":$GET(FILTER("view")),1:$GET(FILTER("VIEW"))))
 IF VIEW="BROWSER",+$GET(REQ("DFN"))>0 DO  QUIT
 . SET FILTER("type")="text/html"
 . DO BROWSER^C0FHIRWS(.RTN,+$GET(REQ("DFN")))
 . SET HTTPRSP("mime")="text/html"
 IF $GET(REQ("DFN"))="" DO  QUIT
 . SET FILTER("type")="text/html"
 . DO FHIRIDX(.RTN)
 . SET HTTPRSP("mime")="text/html"
 SET REQ("MODE")=$$REQMODE(.REQ)
 IF $GET(REQ("MODE"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Cannot determine request mode from URL parameters",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 SET FILTER("type")="application/json"
 SET HTTPRSP("mime")="application/json"
 DO GETBNDLJ(.REQ,.RTN,.ERR)
 IF $DATA(ERR) DO
 . DO ERR^C0FHIRBU("JSON encoding failed in ENCODE^XLFJSON",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 QUIT
 ;
FHIRIDX(RTN) ; Render HTML index when /fhir is called without dfn
 NEW BURL,CNT,DFN,FURL,IEN,JURL,KEY,LURL,NAME,ROOT,ROW,SORT,SUM,VURL
 KILL RTN
 DO ADDLN(.RTN,"<!DOCTYPE HTML>")
 DO ADDLN(.RTN,"<html><head><title>FHIR Patient Index</title></head><body>")
 DO ADDLN(.RTN,"<h1>FHIR Patient Index</h1>")
 DO ADDLN(.RTN,"<p>Click Name for interactive browser view. Rows with IEN '-' were discovered from ^LR (non-Synthea).</p>")
 DO ADDLN(.RTN,"<table border=""1"" cellpadding=""4"" cellspacing=""0"">")
 DO ADDLN(.RTN,"<tr><th>Name</th><th>C0FHIR fhir</th><th>DFN</th><th>IEN</th><th>Synthea Json</th><th>Load Log</th><th>VPR</th></tr>")
 SET ROOT=$$GSROOT()
 SET CNT=0
 IF $DATA(@ROOT@("DFN")) DO
 . SET DFN=0
 . FOR  SET DFN=$ORDER(@ROOT@("DFN",DFN)) Q:+DFN<1  DO
 . . SET IEN=$ORDER(@ROOT@("DFN",DFN,""),-1)
 . . IF IEN<1 QUIT
 . . IF '$$SHOWROW(ROOT,IEN) QUIT
 . . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^")
 . . IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . . SET KEY=$$UPCASE(NAME)
 . . SET SORT(KEY,NAME,DFN,IEN)=""
 . . SET SORT("DFN",DFN)=1
 DO ADDLRROWS(.SORT)
 SET KEY=""
 FOR  SET KEY=$ORDER(SORT(KEY)) Q:KEY=""  DO
 . SET NAME=""
 . FOR  SET NAME=$ORDER(SORT(KEY,NAME)) Q:NAME=""  DO
 . . SET DFN=0
 . . FOR  SET DFN=$ORDER(SORT(KEY,NAME,DFN)) Q:+DFN<1  DO
 . . . SET IEN=""
 . . . FOR  SET IEN=$ORDER(SORT(KEY,NAME,DFN,IEN)) Q:IEN=""  DO
 . . . . SET CNT=CNT+1
 . . . . SET FURL="/fhir?dfn="_DFN
 . . . . SET BURL="/fhir?dfn="_DFN_"&view=browser"
 . . . . SET VURL="/vpr?dfn="_DFN_"&format=xml"
 . . . . SET JURL=$SELECT(+IEN>0:"/showfhir?ien="_IEN,1:"")
 . . . . SET LURL=$SELECT(+IEN>0:$$LOADLOGURL(ROOT,IEN),1:"")
 . . . . SET ROW="<tr><td><a href="""_BURL_""">"_$$HTMLESC(NAME)_"</a></td>"
 . . . . SET ROW=ROW_"<td><a href="""_FURL_""">fhir</a></td>"
 . . . . SET ROW=ROW_"<td>"_DFN_"</td><td>"_$SELECT(+IEN>0:IEN,1:"-")_"</td>"
 . . . . IF JURL'="" SET ROW=ROW_"<td><a href="""_JURL_""">json</a></td>"
 . . . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . . . . IF LURL'="" SET ROW=ROW_"<td><a href="""_LURL_""">load</a></td>"
 . . . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . . . . SET ROW=ROW_"<td><a href="""_VURL_""">vpr</a></td></tr>"
 . . . . DO ADDLN(.RTN,ROW)
 . . . . IF +IEN>0 SET SUM=$$DOMSUM(ROOT,IEN)
 . . . . ELSE  SET SUM=$$LRSUM(DFN)
 . . . . DO ADDLN(.RTN,"<tr><td colspan=""7""><small>"_$$HTMLESC(SUM)_"</small></td></tr>")
 IF CNT=0 DO ADDLN(.RTN,"<tr><td colspan=""7"">No patients with labs were found in graph store or ^LR.</td></tr>")
 DO ADDLN(.RTN,"</table>")
 DO ADDLN(.RTN,"</body></html>")
 QUIT
 ;
ADDLRROWS(SORT) ; Add non-Synthea rows discovered via ^LR
 NEW DFN,KEY,LRDFN,NAME
 SET DFN=0
 FOR  SET DFN=$ORDER(^DPT(DFN)) Q:+DFN<1  DO
 . SET LRDFN=+$GET(^DPT(DFN,"LR"))
 . IF LRDFN<1 QUIT
 . IF '$$HASLRLABS(LRDFN) QUIT
 . IF $GET(SORT("DFN",DFN)) QUIT
 . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^")
 . IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . SET KEY=$$UPCASE(NAME)
 . SET SORT(KEY,NAME,DFN,0)=""
 . SET SORT("DFN",DFN)=1
 QUIT
 ;
HASLRLABS(LRDFN) ; True when LR node has chemistry or micro data
 SET LRDFN=+$GET(LRDFN)
 IF LRDFN<1 QUIT 0
 IF $DATA(^LR(LRDFN,"CH")) QUIT 1
 IF $DATA(^LR(LRDFN,"MI")) QUIT 1
 QUIT 0
 ;
LRSUM(DFN) ; Domain summary for non-Synthea rows discovered from ^LR
 NEW CH,LRDFN,MI,TOT
 SET LRDFN=+$GET(^DPT(+$GET(DFN),"LR"))
 IF LRDFN<1 QUIT "labs:0/0 | source:^LR"
 SET CH=$$LRSUBCNT(LRDFN,"CH")
 SET MI=$$LRSUBCNT(LRDFN,"MI")
 SET TOT=CH+MI
 QUIT "labs:"_TOT_"/"_TOT_" | source:^LR"
 ;
LRSUBCNT(LRDFN,SUB) ; Count first-level nodes for one ^LR subdomain
 NEW CNT,IDT
 SET CNT=0
 SET IDT=0
 FOR  SET IDT=$ORDER(^LR(LRDFN,SUB,IDT)) Q:IDT<1  SET CNT=CNT+1
 QUIT CNT
 ;
SHOWROW(ROOT,IEN) ; True when graph has one or more loaded labs
 NEW DOM,LD,ST,ZI
 SET LD=0
 ;
 ; Preferred: explicit per-domain loaded counter.
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  D  Q:LD>0
 . IF $$UPCASE(DOM)'="LABS" QUIT
 . SET LD=+$GET(@ROOT@(IEN,"load",DOM,"status","loaded"))
 IF LD>0 QUIT 1
 ;
 ; Fallback: scan item-level loadstatus nodes.
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  D  Q:LD>0
 . IF $$UPCASE(DOM)'="LABS" QUIT
 . SET ZI=0
 . FOR  SET ZI=$ORDER(@ROOT@(IEN,"load",DOM,ZI)) Q:+ZI<1  DO  Q:LD>0
 . . SET ST=$$UPCASE($GET(@ROOT@(IEN,"load",DOM,ZI,"status","loadstatus")))
 . . IF ST="LOADED" SET LD=1
 QUIT $SELECT(LD>0:1,1:0)
 ;
DOMSUM(ROOT,IEN) ; Build domain loaded/source summary text
 NEW DOM,DOMLD,DOMSRC,LD,SRC,ST,STDOM,SUM,TXT,ZI
 SET TXT=""
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  DO
 . SET (LD,SRC)=0
 . SET ZI=0
 . FOR  SET ZI=$ORDER(@ROOT@(IEN,"load",DOM,ZI)) Q:+ZI<1  DO
 . . SET SRC=SRC+1
 . . SET ST=$$UPCASE($GET(@ROOT@(IEN,"load",DOM,ZI,"status","loadstatus")))
 . . IF ST="LOADED" SET LD=LD+1
 . ; Some domains (for example Patient) use only domain-level status nodes.
 . ; Prefer explicit status counters when present, then fallback to status/loadstatus.
 . SET DOMSRC=+$GET(@ROOT@(IEN,"load",DOM,"status","source"))
 . SET DOMLD=+$GET(@ROOT@(IEN,"load",DOM,"status","loaded"))
 . IF DOMSRC>0 SET SRC=DOMSRC
 . IF DOMLD>0 SET LD=DOMLD
 . IF SRC=0 DO
 . . SET STDOM=$$UPCASE($GET(@ROOT@(IEN,"load",DOM,"status","loadstatus")))
 . . IF STDOM'="" SET SRC=1,LD=$SELECT(STDOM="LOADED":1,1:0)
 . ; Hide empty domains so we do not display misleading 0/0 rows.
 . IF SRC=0,LD=0 QUIT
 . SET SUM=DOM_":"_LD_"/"_SRC
 . IF TXT'="" SET TXT=TXT_" | "
 . SET TXT=TXT_SUM
 IF TXT="" SET TXT="No load summary available."
 QUIT TXT
 ;
GSROOT() ; Resolve graph-store root across deployments
 NEW PROOT
 ; Some deployments do not permit % globals and store graph data in ^SYNGRAPH.
 IF $DATA(^SYNGRAPH(2002.801,2,"DFN")) QUIT "^SYNGRAPH(2002.801,2)"
 ;
 ; Standard C0 path in environments that use ^%wd.
 SET PROOT="^"_$CHAR(37)_"wd(17.040801,3)"
 IF $DATA(@PROOT@("DFN")) QUIT PROOT
 ;
 ; Fallback preserves prior behavior if DFN xref is absent.
 QUIT PROOT
 ;
LOADLOGURL(ROOT,IEN) ; Build /gtree URL for load log node
 NEW URLROOT
 SET URLROOT=$EXTRACT($GET(ROOT),2,$LENGTH($GET(ROOT))) ; drop leading ^
 IF URLROOT="" QUIT ""
 IF URLROOT["(" SET URLROOT=$EXTRACT(URLROOT,1,$LENGTH(URLROOT)-1)_","_(+IEN)_",%22load%22)"
 ELSE  SET URLROOT=URLROOT_"("_(+IEN)_",%22load%22)"
 IF $EXTRACT(URLROOT,1)="%" SET URLROOT="%25"_$EXTRACT(URLROOT,2,$LENGTH(URLROOT))
 QUIT "/gtree/"_URLROOT
 ;
ADDLN(RTN,TXT) ; Append one line to output array
 NEW IDX
 SET IDX=$ORDER(RTN(""),-1)+1
 SET RTN(IDX)=$GET(TXT)
 QUIT
 ;
HTMLESC(X) ; Escape basic HTML special chars
 NEW C,I,Y
 SET Y=""
 FOR I=1:1:$LENGTH($GET(X)) DO
 . SET C=$EXTRACT(X,I)
 . IF C="&" SET Y=Y_"&amp;" QUIT
 . IF C="<" SET Y=Y_"&lt;" QUIT
 . IF C=">" SET Y=Y_"&gt;" QUIT
 . IF C="""" SET Y=Y_"&quot;" QUIT
 . IF C="'" SET Y=Y_"&#39;" QUIT
 . SET Y=Y_C
 QUIT Y
 ;
GETBNDL(REQ,OUT) ; Return one Bundle response structure for a request
 ; REQ("MODE")="ENCOUNTER" or "DATERANGE"
 ; REQ(...) contains request parameters (DFN, encounter/date filters, etc.)
 NEW MODE
 DO ENVINIT
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" DO BYENC^C0FHIRBU(.REQ,.OUT) QUIT
 IF MODE="DATERANGE" DO BYDATE^C0FHIRBU(.REQ,.OUT) QUIT
 DO ERR^C0FHIRBU("Unsupported bundle mode: "_MODE,.OUT)
 QUIT
 ;
GETBNDLJ(REQ,OUT,ERR) ; Return one Bundle response encoded as JSON
 ; OUT returns JSON output nodes from ENCODE^XLFJSON
 ; ERR returns encoder errors, if any
 NEW BUNDLE
 DO GETBNDL(.REQ,.BUNDLE)
 DO TOJSON^C0FHIRBU(.BUNDLE,.OUT,.ERR)
 QUIT
 ;
MAPFILT(FILTER,REQ) ; Map URL parameters into request structure
 NEW ENDVAL,STARTVAL
 KILL REQ
 SET REQ("DFN")=$SELECT($GET(FILTER("dfn"))'="":$GET(FILTER("dfn")),1:$GET(FILTER("DFN")))
 SET REQ("ENCOUNTER")=$SELECT($GET(FILTER("encounter"))'="":$GET(FILTER("encounter")),1:$GET(FILTER("ENCOUNTER")))
 SET STARTVAL=$$PARSEFM($SELECT($GET(FILTER("start"))'="":$GET(FILTER("start")),1:$GET(FILTER("START"))))
 IF STARTVAL'="" SET REQ("START_DT")=STARTVAL
 SET ENDVAL=$$PARSEFM($SELECT($GET(FILTER("end"))'="":$GET(FILTER("end")),1:$GET(FILTER("END"))))
 IF ENDVAL'="" SET REQ("END_DT")=ENDVAL
 SET REQ("MODE")=$$UPCASE($SELECT($GET(FILTER("mode"))'="":$GET(FILTER("mode")),1:$GET(FILTER("MODE"))))
 SET REQ("MAX")=$SELECT($GET(FILTER("max"))'="":+$GET(FILTER("max")),1:+$GET(FILTER("MAX")))
 DO MAPDOM(.FILTER,.REQ)
 QUIT
 ;
MAPDOM(FILTER,REQ) ; Map optional domain filters into REQ("DOMAIN",...)
 NEW SUB,VAL
 SET VAL=$SELECT($GET(FILTER("domains"))'="":$GET(FILTER("domains")),1:$GET(FILTER("DOMAINS")))
 DO ADDDOM(VAL,.REQ)
 SET VAL=$SELECT($GET(FILTER("domain"))'="":$GET(FILTER("domain")),1:$GET(FILTER("DOMAIN")))
 DO ADDDOM(VAL,.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("domains",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("domains",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("DOMAINS",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("DOMAINS",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("domain",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("domain",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("DOMAIN",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("DOMAIN",SUB)),.REQ)
 QUIT
 ;
ADDDOM(VAL,REQ) ; Parse one domain token list into canonical domain flags
 NEW LIST,TOK
 SET LIST=$$UPCASE($$TRIM($GET(VAL)))
 IF LIST="" QUIT
 SET REQ("DOMAIN","_FILTERED")=1
 SET LIST=$TRANSLATE(LIST,"|;/",",,,")
 FOR  QUIT:LIST=""  DO
 . SET TOK=$$TRIM($PIECE(LIST,",",1))
 . SET LIST=$PIECE(LIST,",",2,999)
 . IF TOK="" QUIT
 . SET TOK=$$DOMTOK(TOK)
 . IF TOK'="" SET REQ("DOMAIN",TOK)=1
 QUIT
 ;
DOMTOK(X) ; Normalize domain alias to canonical token
 NEW Y
 SET Y=$$UPCASE($$TRIM($GET(X)))
 IF Y="" QUIT ""
 IF Y="ALL" QUIT "ALL"
 IF Y="PATIENT"!(Y="PAT") QUIT "PATIENT"
 IF Y="ENCOUNTER"!(Y="ENCOUNTERS")!(Y="ENC")!(Y="VISIT")!(Y="VISITS") QUIT "ENCOUNTER"
 IF Y="CONDITION"!(Y="CONDITIONS")!(Y="PROBLEM")!(Y="PROBLEMS") QUIT "CONDITION"
 IF Y="OBS"!(Y="OBSERVATION")!(Y="OBSERVATIONS")!(Y="VITAL")!(Y="VITALS") QUIT "VITAL"
 IF Y="ALLERGY"!(Y="ALLERGIES")!(Y="ALGY")!(Y="ALLERGYINTOLERANCE") QUIT "ALLERGY"
 IF Y="MED"!(Y="MEDS")!(Y="MEDICATION")!(Y="MEDICATIONS")!(Y="RX")!(Y="MEDICATIONREQUEST") QUIT "MEDICATION"
 IF Y="IMM"!(Y="IMMS")!(Y="IMMUNIZATION")!(Y="IMMUNIZATIONS") QUIT "IMMUNIZATION"
 IF Y="LAB"!(Y="LABS")!(Y="LABORATORY")!(Y="LABORATORIES") QUIT "LAB"
 QUIT
 ;
REQMODE(REQ) ; Resolve request mode from mapped parameters
 NEW MODE
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" QUIT "ENCOUNTER"
 IF MODE="DATERANGE" QUIT "DATERANGE"
 IF MODE'="" QUIT ""
 IF $GET(REQ("ENCOUNTER"))'="" QUIT "ENCOUNTER"
 IF $GET(REQ("START_DT"))'="" QUIT "DATERANGE"
 IF $GET(REQ("END_DT"))'="" QUIT "DATERANGE"
 ; Default behavior: if no encounter/date filters are supplied,
 ; return all encounters for the patient.
 QUIT "DATERANGE"
 ;
UPCASE(X) ; Upper-case helper without external dependencies
 NEW C,I,Y
 SET Y=""
 FOR I=1:1:$LENGTH($GET(X)) DO
 . SET C=$EXTRACT(X,I)
 . IF C?1L SET C=$CHAR($ASCII(C)-32)
 . SET Y=Y_C
 QUIT Y
 ;
GENDER(X) ; Map VistA sex code to FHIR gender
 SET X=$$UPCASE($GET(X))
 IF X="M" QUIT "male"
 IF X="F" QUIT "female"
 IF X="U" QUIT "unknown"
 QUIT "unknown"
 ;
TRIM(X) ; Remove leading and trailing spaces
 NEW Y
 SET Y=$GET(X)
 FOR  QUIT:$EXTRACT(Y,1)'=" "  SET Y=$EXTRACT(Y,2,$LENGTH(Y))
 FOR  QUIT:$EXTRACT(Y,$LENGTH(Y))'=" "  SET Y=$EXTRACT(Y,1,$LENGTH(Y)-1)
 QUIT Y
 ;
ENVINIT ; Ensure legacy VPR runtime variables are available
 ; Many legacy VPR/PX/Kernel routines assume U,DT,DUZ,DUZ(0),DUZ(2) are defined.
 NEW DIV
 IF $GET(U)="" SET U="^"
 IF '$DATA(DT) SET DT=$$DT^XLFDT
 IF +$GET(DUZ)<1 DO
 . IF $DATA(^VA(200,.5,0)) SET DUZ=.5 QUIT
 . SET DUZ=+$ORDER(^VA(200,0))
 IF $GET(DUZ(0))="" SET DUZ(0)="@"
 IF +$GET(DUZ(2))<1 DO
 . SET DIV=+$PIECE($GET(^VA(200,+DUZ,2,1,0)),"^")
 . IF DIV<1 SET DIV=+$ORDER(^DIC(4,0))
 . SET DUZ(2)=DIV
 QUIT
 ;
PARSEFM(X) ; Parse URL date value to FileMan date/time
 ; Supports direct FM numbers and expressions like T, T-30, NOW.
 NEW %DT,Y
 SET X=$$TRIM($GET(X))
 IF X="" QUIT ""
 IF X?1.N QUIT X
 SET %DT="TS"
 DO ^%DT
 IF Y>0 QUIT Y
 QUIT ""
