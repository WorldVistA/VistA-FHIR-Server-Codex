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
 NEW CLASS,ENC,ENDDT,IDX,VPRTEXT
 DO ENVINIT
 SET ENCIEN=+ENCIEN
 IF ENCIEN<1 QUIT
 SET VPRTEXT=1
 DO EN1^VPRDVSIT(ENCIEN,.ENC)
 DO ADDRES^C0FHIRBU(.RTN,"Encounter","E"_ENCIEN,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Encounter"
 SET RTN("entry",IDX,"resource","id")="E"_ENCIEN
 SET RTN("entry",IDX,"resource","status")="finished"
 SET CLASS=$SELECT($GET(ENC("patientClass"))="IMP":"IMP",1:"AMB")
 SET RTN("entry",IDX,"resource","class","system")="http://terminology.hl7.org/CodeSystem/v3-ActCode"
 SET RTN("entry",IDX,"resource","class","code")=CLASS
 IF +$GET(DFN)>0 DO
 . SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 . IF $PIECE($GET(^DPT(DFN,0)),U)'="" SET RTN("entry",IDX,"resource","subject","display")=$PIECE($GET(^DPT(DFN,0)),U)
 IF +$GET(ENC("dateTime"))>0 SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(ENC("dateTime"))
 SET ENDDT=+$GET(ENC("departureDateTime"))
 IF ENDDT<1 SET ENDDT=$$ENCEND(+$GET(DFN),.ENC)
 IF ENDDT>0 SET RTN("entry",IDX,"resource","period","end")=$$FM2FHIR^C0FHIRBU(ENDDT)
 DO SETETYP(.RTN,IDX,.ENC)
 DO SETEPRV(.RTN,IDX,.ENC,+$GET(DFN),ENDDT)
 DO SETEFAC(.RTN,IDX,.ENC)
 DO SETELOC(.RTN,IDX,.ENC)
 DO SETESVC(.RTN,IDX,.ENC)
 DO SETERSN(.RTN,IDX,.ENC)
 DO SETENOTE(.RTN,IDX,.ENC)
 QUIT
 ;
SETETYP(RTN,IDX,ENC) ; Populate Encounter.type from encounter CPT/OS5 when available
 NEW CODE,TXT,TYPE
 KILL TYPE
 DO ENCTYP(.ENC,.TYPE)
 IF $DATA(TYPE) MERGE RTN("entry",IDX,"resource","type",1)=TYPE QUIT
 SET CODE=$PIECE($GET(ENC("type")),"^")
 SET TXT=$PIECE($GET(ENC("type")),"^",2)
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","type",1,"coding",1,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","type",1,"coding",1,"code")=CODE
 . IF TXT'="" SET RTN("entry",IDX,"resource","type",1,"coding",1,"display")=TXT
 IF TXT'="" SET RTN("entry",IDX,"resource","type",1,"text")=TXT
 QUIT
 ;
ENCTYP(ENC,TYPE) ; Build encounter type from encounter-like CPT/OS5 rows
 NEW CODE,DA,ITEM,NAME
 KILL TYPE
 SET DA=0
 FOR  SET DA=$ORDER(ENC("cpt",DA)) Q:DA<1  DO  Q:$DATA(TYPE)
 . SET ITEM=$GET(ENC("cpt",DA))
 . SET CODE=$PIECE(ITEM,"^")
 . SET NAME=$PIECE(ITEM,"^",2,99)
 . IF '$$ISENCD^C0FHIRP(CODE) QUIT
 . DO ENCCOD(CODE,NAME,.TYPE)
 QUIT
 ;
ENCCOD(CODE,NAME,TYPE) ; Add encounter coding from OS5/CPT and recovered SNOMED
 NEW SCT,SDISP
 KILL TYPE
 SET CODE=$PIECE($GET(CODE),"^")
 SET NAME=$GET(NAME)
 IF CODE="" QUIT
 DO ENCSNOM(CODE,.SCT,.SDISP)
 IF SCT'="" DO
 . SET TYPE("coding",1,"system")="http://snomed.info/sct"
 . SET TYPE("coding",1,"code")=SCT
 . IF SDISP'="" SET TYPE("coding",1,"display")=SDISP
 . SET TYPE("coding",2,"system")="http://www.ama-assn.org/go/cpt"
 . SET TYPE("coding",2,"code")=CODE
 . IF NAME'="" SET TYPE("coding",2,"display")=NAME
 ELSE  DO
 . SET TYPE("coding",1,"system")="http://www.ama-assn.org/go/cpt"
 . SET TYPE("coding",1,"code")=CODE
 . IF NAME'="" SET TYPE("coding",1,"display")=NAME
 IF NAME="" SET NAME=SDISP
 IF NAME'="" SET TYPE("text")=NAME
 QUIT
 ;
ENCSNOM(CODE,SCT,SDISP) ; Recover source SNOMED mapping for one encounter OS5/CPT code
 NEW HIT
 SET (SCT,SDISP)=""
 SET CODE=$PIECE($GET(CODE),"^")
 IF CODE="" QUIT
 SET HIT=0
 FOR  SET SCT=$ORDER(^SYN("2002.030","sct2os5","inverse",CODE,SCT)) Q:SCT=""  DO  Q:HIT
 . IF '$$ISENCS^C0FHIRP(SCT) QUIT
 . IF $$ISDUALS^C0FHIRP(SCT) QUIT
 . SET SDISP=$GET(^SYN("2002.030","sct2os5","inverse",CODE,SCT))
 . SET HIT=1
 QUIT
 ;
ENCEND(DFN,ENC) ; Recover outpatient end time from clinic appointment checkout
 NEW APDT,CLIEN,ENDDT,IEN
 SET ENDDT=0
 SET DFN=+$GET(DFN)
 SET APDT=+$GET(ENC("dateTime"))
 SET CLIEN=$$ENCCLIN(.ENC)
 IF DFN<1!(APDT<1)!(CLIEN<1) QUIT 0
 SET IEN=0
 FOR  SET IEN=$ORDER(^SC(CLIEN,"S",APDT,1,IEN)) Q:IEN<1!(ENDDT>0)  DO
 . IF +$GET(^SC(CLIEN,"S",APDT,1,IEN,0))'=DFN QUIT
 . SET ENDDT=$$GET1^DIQ(44.003,IEN_","_APDT_","_CLIEN_",",303,"I")
 . IF ENDDT<1 SET ENDDT=$$GET1^DIQ(44.003,IEN_","_APDT_","_CLIEN_",",306,"I")
 QUIT ENDDT
 ;
ENCCLIN(ENC) ; Return clinic ien from visit string
 QUIT +$PIECE($GET(ENC("visitString")),";",1)
 ;
SETEPRV(RTN,IDX,ENC,DFN,ENDDT) ; Add encounter participants from VistA provider data
 NEW I,N,PROV,RAW,ROLE,STARTDT
 SET STARTDT=+$GET(ENC("dateTime"))
 SET N=0,I=0
 FOR  SET I=$ORDER(ENC("provider",I)) Q:I<1  DO
 . SET RAW=$GET(ENC("provider",I))
 . SET PROV=$$PROV^C0FHIRP(RAW)
 . IF $PIECE(PROV,U,2)="" QUIT
 . SET N=N+1
 . SET RTN("entry",IDX,"resource","participant",N,"individual","display")=$PIECE(PROV,U,2)
 . IF +$PIECE(PROV,U)>0 DO
 . . SET RTN("entry",IDX,"resource","participant",N,"individual","identifier","system")="urn:va:user"
 . . SET RTN("entry",IDX,"resource","participant",N,"individual","identifier","value")=+$PIECE(PROV,U)
 . IF STARTDT>0 SET RTN("entry",IDX,"resource","participant",N,"period","start")=$$FM2FHIR^C0FHIRBU(STARTDT)
 . IF ENDDT>0 SET RTN("entry",IDX,"resource","participant",N,"period","end")=$$FM2FHIR^C0FHIRBU(ENDDT)
 . SET ROLE=$$PROL($PIECE(RAW,U,3),+$PIECE(RAW,U,4))
 . IF $PIECE(ROLE,U)'="" DO
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v3-ParticipationType"
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"code")=$PIECE(ROLE,U)
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"display")=$PIECE(ROLE,U,2)
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"text")=$PIECE(ROLE,U,2)
 QUIT
 ;
PROL(CODE,PRIMARY) ; Map VistA visit provider role to participation type
 SET CODE=$$UPCASE($GET(CODE))
 IF +$GET(PRIMARY)=1!(CODE="P") QUIT "PPRF^primary performer"
 IF CODE="A" QUIT "ATND^attender"
 QUIT ""
 ;
SETEFAC(RTN,IDX,ENC) ; Add serviceProvider from VistA facility when available
 NEW FAC,NAME,STA
 SET FAC=$GET(ENC("facility"))
 SET STA=$PIECE(FAC,U)
 SET NAME=$PIECE(FAC,U,2)
 IF STA="",NAME="" QUIT
 IF NAME'="" SET RTN("entry",IDX,"resource","serviceProvider","display")=NAME
 IF STA'="" DO
 . SET RTN("entry",IDX,"resource","serviceProvider","identifier","system")="urn:va:station"
 . SET RTN("entry",IDX,"resource","serviceProvider","identifier","value")=STA
 . SET RTN("entry",IDX,"resource","serviceProvider","identifier","value","\s")=""
 QUIT
 ;
SETELOC(RTN,IDX,ENC) ; Add clinic/location display in the correct Encounter field
 NEW CLIEN
 SET CLIEN=$$ENCCLIN(.ENC)
 IF $GET(ENC("location"))'="" SET RTN("entry",IDX,"resource","location",1,"location","display")=$GET(ENC("location"))
 IF CLIEN>0 DO
 . SET RTN("entry",IDX,"resource","location",1,"location","identifier","system")="urn:va:clinic"
 . SET RTN("entry",IDX,"resource","location",1,"location","identifier","value")=CLIEN
 . SET RTN("entry",IDX,"resource","location",1,"location","identifier","value","\s")=""
 QUIT
 ;
SETESVC(RTN,IDX,ENC) ; Add service text when available
 NEW CODE,TXT
 IF $GET(ENC("service"))'="" SET RTN("entry",IDX,"resource","serviceType","text")=$GET(ENC("service"))
 SET CODE=$PIECE($GET(ENC("stopCode")),U)
 SET TXT=$PIECE($GET(ENC("stopCode")),U,2)
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","serviceType","coding",1,"system")="urn:va:stop-code"
 . SET RTN("entry",IDX,"resource","serviceType","coding",1,"code")=CODE
 . IF TXT'="" SET RTN("entry",IDX,"resource","serviceType","coding",1,"display")=TXT
 QUIT
 ;
SETERSN(RTN,IDX,ENC) ; Add encounter reason from VistA POV data when available
 NEW CODE,NARR,NAME,SYS
 SET CODE=$PIECE($GET(ENC("reason")),U)
 SET NAME=$PIECE($GET(ENC("reason")),U,2)
 SET SYS=$PIECE($GET(ENC("reason")),U,3)
 SET NARR=$PIECE($GET(ENC("reason")),U,4)
 IF CODE=""&(NARR="")&(NAME="") QUIT
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"code")=CODE
 . SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"system")=$$CONDSYS($GET(SYS))
 . IF NAME'="" SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"display")=NAME
 IF NARR="" SET NARR=NAME
 IF NARR'="" SET RTN("entry",IDX,"resource","reasonCode",1,"text")=NARR
 QUIT
 ;
SETENOTE(RTN,IDX,ENC) ; Add encounter-linked TIU note text when available
 NEW CONT,DOC,I,TXT
 SET I=0
 FOR  SET I=$ORDER(ENC("document",I)) Q:I<1  DO
 . SET DOC=$GET(ENC("document",I))
 . SET CONT=$GET(ENC("document",I,"content"))
 . SET TXT=$$DOCNOTE^C0FHIRBU(DOC,CONT)
 . IF TXT'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT)
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
GETPROC(RTN,DFN,BEG,END,MAX) ; Add Procedure resources
 DO GETPROC^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
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
 ;             (for example: "encounter,condition,vitals,procedures,labs")
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
 ;   FILTER("domains")="encounter,condition,vitals,procedures,labs"
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
 NEW BURL,CNT,DFN,FURL,HASGRAPH,HASVPR,IEN,JURL,KEY,LURL,NAME,NCOLS,ROOT,ROW,SORT,SUM,VURL
 KILL RTN
 SET ROOT=$$GSROOT()
 SET HASGRAPH=0 IF $L($G(ROOT))>0,$DATA(@ROOT@("DFN")) SET HASGRAPH=1
 SET HASVPR=$$VPROK()
 SET NCOLS=4+$SELECT(HASGRAPH:2,1:0)+$SELECT(HASVPR:1,1:0)
 DO ADDLN(.RTN,"<!DOCTYPE HTML>")
 DO ADDLN(.RTN,"<html><head><title>FHIR Patient Index</title></head><body>")
 DO ADDLN(.RTN,"<h1>FHIR Patient Index</h1>")
 DO ADDLN(.RTN,"<p>Click Name for interactive browser view. Rows with IEN '-' were discovered from ^LR (non-Synthea).</p>")
 DO ADDLN(.RTN,"<table border=""1"" cellpadding=""4"" cellspacing=""0"">")
 SET ROW="<tr><th>Name</th><th>C0FHIR fhir</th><th>DFN</th><th>IEN</th>"
 IF HASGRAPH SET ROW=ROW_"<th>Synthea Json</th><th>Load Log</th>"
 IF HASVPR SET ROW=ROW_"<th>VPR</th>"
 DO ADDLN(.RTN,ROW_"</tr>")
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
 . . . . SET JURL=$SELECT(HASGRAPH&(+IEN>0):"/showfhir?ien="_IEN,1:"")
 . . . . SET LURL=$SELECT(HASGRAPH&(+IEN>0):$$LOADLOGURL(ROOT,IEN),1:"")
 . . . . SET ROW="<tr><td><a href="""_BURL_""">"_$$HTMLESC(NAME)_"</a></td>"
 . . . . SET ROW=ROW_"<td><a href="""_FURL_""">fhir</a></td>"
 . . . . SET ROW=ROW_"<td>"_DFN_"</td><td>"_$SELECT(+IEN>0:IEN,1:"-")_"</td>"
 . . . . IF HASGRAPH DO
 . . . . . IF JURL'="" SET ROW=ROW_"<td><a href="""_JURL_""">json</a></td>"
 . . . . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . . . . . IF LURL'="" SET ROW=ROW_"<td><a href="""_LURL_""">load</a></td>"
 . . . . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . . . . IF HASVPR SET ROW=ROW_"<td><a href="""_VURL_""">vpr</a></td>"
 . . . . SET ROW=ROW_"</tr>"
 . . . . DO ADDLN(.RTN,ROW)
 . . . . IF +IEN>0 SET SUM=$$DOMSUM(ROOT,IEN)
 . . . . ELSE  SET SUM=$$LRSUM(DFN)
 . . . . DO ADDLN(.RTN,"<tr><td colspan="""_NCOLS_"""><small>"_$$HTMLESC(SUM)_"</small></td></tr>")
 IF CNT=0 DO ADDLN(.RTN,"<tr><td colspan="""_NCOLS_""">No patients with labs were found in graph store or ^LR.</td></tr>")
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
 ; Use SYNWD when present so graph location matches loader (^%wd vs ^SYNGRAPH).
 NEW PROOT,R
 IF $T(setroot^SYNWD)'="" DO
 . SET R=$$setroot^SYNWD("fhir-intake")
 . IF $L(R),$DATA(@R@("DFN")) SET PROOT=R QUIT
 . SET PROOT=""
 IF $G(PROOT)'="" QUIT PROOT
 ; Fallback: detect which backend has the graph.
 IF $DATA(^SYNGRAPH(2002.801,2,"DFN")) QUIT "^SYNGRAPH(2002.801,2)"
 SET PROOT="^"_$CHAR(37)_"wd(17.040801,3)"
 IF $DATA(@PROOT@("DFN")) QUIT PROOT
 QUIT PROOT
 ;
VPROK() ; True when VPR is available on this system (so /vpr link works)
 IF '$D(^VA(200)) QUIT 0
 IF $T(EN1^VPRDVSIT)="" QUIT 0
 QUIT 1
 ;
wsShow(OUT,FILTER) ; GET tfhir: delegate to wsShow^SYNFHIR (graph JSON by ref); if FILTER("format")=tjson, tjson^%wd transforms OUT. showfhir stays wsShow^SYNFHIR only.
 NEW SAVEFMT,FORMAT
 IF '$D(DT) N DIQUIET S DIQUIET=1 D DT^DICRW
 SET SAVEFMT=$GET(FILTER("format"))
 SET FORMAT=$$UPCASE(SAVEFMT)
 KILL FILTER("format")
 IF $T(wsShow^SYNFHIR)'="" DO wsShow^SYNFHIR(.OUT,.FILTER)
 ELSE  DO WSSHOWFB^C0FHIR(.OUT,.FILTER)
 IF SAVEFMT'="" SET FILTER("format")=SAVEFMT
 IF FORMAT="TJSON" DO WSSHOWJSON2TJSON^C0FHIR(FORMAT,.OUT)
 SET HTTPRSP("mime")=$$WSSHOWMIME^C0FHIR(FORMAT)
 QUIT
 ;
WSSHOWFB(OUT,FILTER) ; Fallback when wsShow^SYNFHIR missing: old C0FHIR graph path + encode
 NEW TYPE,ROOT,IEN,JROOT,JTMP,JUSE,TMP,ERR
 SET TYPE=$G(FILTER("type"))
 SET ROOT=$$GSROOT^C0FHIR
 QUIT:$L($G(ROOT))=0
 SET IEN=+$G(FILTER("ien"))
 IF IEN=0 DO
 . N ICN S ICN=$G(FILTER("icn")) Q:ICN=""
 . S IEN=$O(@ROOT@("ICN",ICN,""))
 IF IEN=0 DO
 . N DFN S DFN=$G(FILTER("dfn")) Q:DFN=""
 . S IEN=$O(@ROOT@("DFN",DFN,""))
 QUIT:IEN=0
 SET JROOT=$NA(@ROOT@(IEN,"json"))
 QUIT:'$D(@JROOT)
 SET JUSE=JROOT
 IF TYPE'="",$T(getIntakeFhir^SYNFHIR)'="" DO getIntakeFhir^SYNFHIR("JTMP",$G(FILTER("bundle")),TYPE,IEN,1) SET JUSE="JTMP"
 IF $T(encode^SYNJSON)'="" DO encode^SYNJSON(JUSE,"OUT") QUIT
 MERGE TMP=@JUSE DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 QUIT
 ;
WSSHOWMIME(FMT) ; Mime type for wsShow: JSON default; format=tjson -> HTML wrapper around TJSON in <pre>
 QUIT $SELECT($$UPCASE($GET(FMT))="TJSON":"text/html; charset=utf-8",1:"application/json")
 ;
WSSHOWJSON2TJSON(FMT,ARY) ; If FMT is TJSON, wrap tjson^%wd output in HTML5 + CSS (no %webrsp changes).
 ; HTML TJSON: flex column, vertical scroll in <main>. pre-wrap + overflow-wrap:anywhere so few-\n tjson output fills the viewport.
 QUIT:$$UPCASE($GET(FMT))'="TJSON"
 NEW TIN,TOUT,WRAP,WI,ZI,HPRE,HSUF
 QUIT:'$DATA(ARY)
 MERGE TIN=ARY
 KILL ARY
 IF $T(tjson^%wd)="" MERGE ARY=TIN QUIT
 DO tjson^%wd("TIN","TOUT")
 SET HPRE=""
 SET HPRE=HPRE_"<!DOCTYPE html>"_$CHAR(10)
 SET HPRE=HPRE_"<html lang=""en"">"_$CHAR(10)
 SET HPRE=HPRE_"<head>"_$CHAR(10)
 SET HPRE=HPRE_"<meta charset=""utf-8""/>"_$CHAR(10)
 SET HPRE=HPRE_"<meta name=""viewport"" content=""width=device-width,initial-scale=1""/>"_$CHAR(10)
 SET HPRE=HPRE_"<meta name=""color-scheme"" content=""dark""/>"_$CHAR(10)
 SET HPRE=HPRE_"<title>FHIR · TJSON</title>"_$CHAR(10)
 SET HPRE=HPRE_"<style type=""text/css"">"_$CHAR(10)
 SET HPRE=HPRE_":root{--bg:#051626;--fg:#e8ecf1;--hdr:#030d18;--bd:#0d2844;--muted:#a8b8cc;--accent:#8ec5ff;}"_$CHAR(10)
 SET HPRE=HPRE_"html,body{height:100%;margin:0;}"_$CHAR(10)
 SET HPRE=HPRE_"body{background:var(--bg);color:var(--fg);color-scheme:dark;display:flex;flex-direction:column;font-family:system-ui,Segoe UI,Roboto,sans-serif;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr{flex:0 0 auto;padding:8px 16px;background:var(--hdr);border-bottom:1px solid var(--bd);font-size:12px;line-height:1.35;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr .t{font-weight:600;color:var(--accent);letter-spacing:.03em;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr .h{color:var(--muted);font-weight:400;}"_$CHAR(10)
 SET HPRE=HPRE_"main.main{flex:1 1 auto;min-height:0;min-width:0;overflow-x:hidden;overflow-y:auto;-webkit-overflow-scrolling:touch;background:var(--bg);}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson{margin:0;padding:12px 18px 28px;box-sizing:border-box;width:100%;max-width:100%;min-width:0;"_$CHAR(10)
 SET HPRE=HPRE_"background:var(--bg);color:var(--fg);"_$CHAR(10)
 SET HPRE=HPRE_"font-family:Consolas,'Courier New',ui-monospace,'Cascadia Mono',Menlo,monospace;"_$CHAR(10)
 SET HPRE=HPRE_"font-size:14px;line-height:1.5;tab-size:2;-moz-tab-size:2;"_$CHAR(10)
 SET HPRE=HPRE_"white-space:pre-wrap;overflow-wrap:anywhere;word-break:break-word;"_$CHAR(10)
 SET HPRE=HPRE_"font-variant-ligatures:none;font-feature-settings:'liga' 0;}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson .hl-uuid{color:#c45c3a;}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson .hl-synthea{color:#b39ddb;}"_$CHAR(10)
 SET HPRE=HPRE_"</style></head>"_$CHAR(10)
 SET HPRE=HPRE_"<body>"_$CHAR(10)
 SET HPRE=HPRE_"<header class=""hdr""><span class=""t"">TJSON</span> <span class=""h"">FHIR bundle (rust tjson); long lines wrap — scroll vertically</span></header>"_$CHAR(10)
 SET HPRE=HPRE_"<main class=""main""><pre class=""tjson"" spellcheck=""false"" translate=""no"">"
 SET HSUF="</pre></main><script>document.addEventListener('DOMContentLoaded',function(){var p=document.querySelector('pre.tjson');if(!p)return;var t=p.textContent;"
 SET HSUF=HSUF_"function e(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}var r=/urn:uuid:[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}|\\bSynthea\\b/g,m,o='',l=0;"
 SET HSUF=HSUF_"while((m=r.exec(t))!==null){o+=e(t.slice(l,m.index));if(m[0]==='Synthea')o+=`<span class=""hl-synthea"">Synthea</span>`;else o+=`<span class=""hl-uuid"">${e(m[0])}</span>`;l=r.lastIndex;}"
 SET HSUF=HSUF_"o+=e(t.slice(l));p.innerHTML=o;});</script></body></html>"
 SET WRAP(1)=HPRE
 SET WI=1,ZI=""
 FOR  SET ZI=$ORDER(TOUT(ZI)) QUIT:ZI=""  DO
 . SET WI=WI+1,WRAP(WI)=TOUT(ZI)
 SET WI=WI+1,WRAP(WI)=HSUF
 MERGE ARY=WRAP
 QUIT
 ;
REGTFHIR ; Register GET /tfhir -> wsShow^C0FHIR (^%web 17.6001). Does not alter showfhir (SYNFHIR).
 ; Programmer once per site (or after image rebuild): D REGTFHIR^C0FHIR
 ; Removes wrong pattern tfhir/* if present; see docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md
 IF $T(addService^%webutils)="" QUIT
 IF $T(deleteService^%webutils)'="" DO deleteService^%webutils("GET","tfhir/*")
 DO addService^%webutils("GET","tfhir","wsShow^C0FHIR")
 QUIT
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
 IF Y="PROC"!(Y="PROCS")!(Y="PROCEDURE")!(Y="PROCEDURES") QUIT "PROCEDURE"
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
