C0FHIRBU ; VAMC/JS - Bundle orchestration for multi-domain responses
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 ; This routine builds one FHIR Bundle response per request.
 ; OUT is a local structure to be serialized as JSON by the caller layer.
 ;
 QUIT  ; No default action
 ;
BYENC(REQ,OUT) ; Encounter bundle with supporting resources
 ; Expected request parameters:
 ; REQ("DFN")       = patient identifier
 ; REQ("ENCOUNTER") = encounter identifier
 ; REQ("DOMAIN",*)  = optional domain filter tokens
 ;
 NEW BEG,DFN,ENC,END,MAX,VID
 SET DFN=+$GET(REQ("DFN"))
 SET VID=$$ENCIEN($GET(REQ("ENCOUNTER")))
 DO INIT(.OUT,"collection")
 IF DFN<1 DO ERR("Missing required request value: DFN",.OUT) QUIT
 IF VID<1 DO ERR("Missing or invalid request value: ENCOUNTER",.OUT) QUIT
 SET MAX=+$GET(REQ("MAX"))
 IF MAX<1 SET MAX=200
 DO GETPAT^C0FHIR(.OUT,DFN)
 IF $$WANT(.REQ,"ENCOUNTER") DO GETENC^C0FHIR(.OUT,VID,DFN)
 DO EN1^VPRDVSIT(VID,.ENC)
 SET BEG=+$PIECE($GET(ENC("dateTime")),".")
 IF BEG<1 SET BEG=1410101
 SET END=BEG_".24"
 IF $$WANT(.REQ,"CONDITION") DO GETCOND^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"VITAL") DO GETOBS^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"ALLERGY") DO GETALGY^C0FHIR(.OUT,DFN,1410101,4141015,MAX)
 IF $$WANT(.REQ,"MEDICATION") DO GETMED^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"IMMUNIZATION") DO GETIMM^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"LAB") DO GETLAB^C0FHIR(.OUT,DFN,BEG,END,MAX)
 QUIT
 ;
BYDATE(REQ,OUT) ; Date-range bundle for encounters and related resources
 ; Expected request parameters:
 ; REQ("DFN")       = patient identifier
 ; REQ("START_DT")  = inclusive start date/time
 ; REQ("END_DT")    = inclusive end date/time
 ; REQ("DOMAIN",*)  = optional domain filter tokens
 ;
 NEW BEG,DFN,END,MAX
 SET DFN=+$GET(REQ("DFN"))
 DO INIT(.OUT,"collection")
 IF DFN<1 DO ERR("Missing required request value: DFN",.OUT) QUIT
 SET BEG=+$GET(REQ("START_DT"))
 IF BEG<1 SET BEG=1410101
 SET END=$GET(REQ("END_DT"))
 IF END="" SET END=4141015
 SET MAX=+$GET(REQ("MAX"))
 IF MAX<1 SET MAX=200
 DO GETPAT^C0FHIR(.OUT,DFN)
 IF $$WANT(.REQ,"ENCOUNTER") DO ADDRNG(.REQ,.OUT)
 IF $$WANT(.REQ,"CONDITION") DO GETCOND^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"VITAL") DO GETOBS^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"ALLERGY") DO GETALGY^C0FHIR(.OUT,DFN,1410101,4141015,MAX)
 IF $$WANT(.REQ,"MEDICATION") DO GETMED^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"IMMUNIZATION") DO GETIMM^C0FHIR(.OUT,DFN,BEG,END,MAX)
 IF $$WANT(.REQ,"LAB") DO GETLAB^C0FHIR(.OUT,DFN,BEG,END,MAX)
 QUIT
 ;
INIT(OUT,BTYPE) ; Initialize Bundle container
 KILL OUT
 KILL ^TMP("C0FHIRBU",$J,"UUID")
 SET OUT("resourceType")="Bundle"
 SET OUT("type")=$GET(BTYPE,"collection")
 QUIT
 ;
WANT(REQ,DOM) ; True if domain should be included
 ; Supported canonical domain keys:
 ; ENCOUNTER, CONDITION, VITAL, ALLERGY, MEDICATION, IMMUNIZATION, LAB
 IF '$DATA(REQ("DOMAIN")) QUIT 1
 IF $GET(REQ("DOMAIN","ALL"))=1 QUIT 1
 QUIT +$GET(REQ("DOMAIN",$GET(DOM)))
 ;
ADDRNG(REQ,OUT) ; Add encounters for a patient date range
 NEW BEG,CNT,DFN,END,LOC,MAX,VDT,VID
 SET DFN=+$GET(REQ("DFN"))
 SET BEG=+$GET(REQ("START_DT"))
 IF BEG<1 SET BEG=1410101
 SET END=$GET(REQ("END_DT"))
 IF END="" SET END=4141015
 IF END'["." SET END=END_".24"
 SET MAX=+$GET(REQ("MAX"))
 IF MAX<1 SET MAX=200
 SET (CNT,VDT)=0
 SET VDT=END
 FOR  SET VDT=$ORDER(^AUPNVSIT("AET",DFN,VDT),-1) Q:VDT=""!(VDT<BEG)!(CNT'<MAX)  DO
 . SET LOC=0
 . FOR  SET LOC=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC)) Q:LOC=""!(LOC<1)!(CNT'<MAX)  DO
 .. SET VID=0
 .. FOR  SET VID=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC,"P",VID)) Q:VID=""!(VID<1)!(CNT'<MAX)  DO
 ... DO GETENC^C0FHIR(.OUT,VID,DFN)
 ... SET CNT=CNT+1
 QUIT
 ;
ENCIEN(X) ; Normalize encounter input to visit ien
 NEW Y
 SET Y=$GET(X)
 IF Y?1"E".N SET Y=$EXTRACT(Y,2,$LENGTH(Y))
 IF Y[";" SET Y=$PIECE(Y,";",1)
 QUIT +Y
 ;
ADDRES(OUT,RTYPE,RID,IDX) ; Add de-duplicated Bundle entry metadata
 NEW KEY
 SET IDX=""
 IF $GET(RTYPE)="" QUIT
 SET KEY=$$KEY(RTYPE,RID)
 IF $DATA(OUT("index",KEY)) SET IDX=OUT("index",KEY) QUIT
 SET IDX=$ORDER(OUT("entry",""),-1)+1
 SET OUT("index",KEY)=IDX
 SET OUT("entry",IDX,"fullUrl")=$$REFURL(RTYPE,RID)
 SET OUT("entry",IDX,"resource","resourceType")=$GET(RTYPE)
 SET OUT("entry",IDX,"resource","id")=$GET(RID)
 QUIT
 ;
KEY(RTYPE,RID) ; Build a de-duplication key
 QUIT $GET(RTYPE)_"|"_$$SAFE($GET(RID))
 ;
REFURL(RTYPE,RID) ; Build a deterministic urn:uuid fullUrl
 NEW KEY,UUID
 SET KEY=$$KEY(RTYPE,RID)
 SET UUID=$GET(^TMP("C0FHIRBU",$J,"UUID",KEY))
 IF UUID="" DO
 . SET UUID=$$NEWUUID()
 . SET ^TMP("C0FHIRBU",$J,"UUID",KEY)=UUID
 QUIT "urn:uuid:"_UUID
 ;
NEWUUID() ; Return an RFC4122-style UUID string
 NEW U
 SET U=$$RANDHEX(8)_"-"_$$RANDHEX(4)_"-"_$$RANDHEX(4)_"-"_$$RANDHEX(4)_"-"_$$RANDHEX(12)
 SET $EXTRACT(U,15)="4"
 SET $EXTRACT(U,20)=$EXTRACT("89ab",$RANDOM(4)+1)
 QUIT U
 ;
RANDHEX(N) ; Return N random lowercase hex characters
 NEW I,S
 SET S=""
 FOR I=1:1:+$GET(N) SET S=S_$EXTRACT("0123456789abcdef",$RANDOM(16)+1)
 QUIT S
 ;
PATREF(DFN) ; Return the patient fullUrl reference
 QUIT $$REFURL("Patient",+$GET(DFN))
 ;
SAFE(X) ; Light normalization for ids used in keys/fullUrl
 NEW Y
 SET Y=$GET(X)
 SET Y=$TRANSLATE(Y," /;,:^~|()[]{}","----------------")
 IF Y="" SET Y="unknown"
 QUIT Y
 ;
FM2FHIR(FMDT) ; Convert FileMan date/time to FHIR date/dateTime
 NEW D,DAY,HH,M,MM,S,SS,T,Y
 SET D=$PIECE($GET(FMDT),".")
 IF D'?7N QUIT ""
 SET Y=1700+$EXTRACT(D,1,3)
 SET M=$EXTRACT(D,4,5),DAY=$EXTRACT(D,6,7)
 IF M="" SET M="01"
 IF DAY="" SET DAY="01"
 IF $PIECE($GET(FMDT),".")=$GET(FMDT) QUIT Y_"-"_M_"-"_DAY
 SET T=$EXTRACT($PIECE($GET(FMDT),".",2)_"000000",1,6)
 SET HH=+$EXTRACT(T,1,2),MM=+$EXTRACT(T,3,4),SS=+$EXTRACT(T,5,6)
 ; Lab inverse-date arithmetic can yield non-canonical times (for example seconds=64);
 ; normalize to valid clock values before emitting FHIR dateTime.
 IF SS>59 SET MM=MM+(SS\60),SS=SS#60
 IF MM>59 SET HH=HH+(MM\60),MM=MM#60
 IF HH>23 SET HH=23,MM=59,SS=59
 SET HH=$$PAD2(HH),MM=$$PAD2(MM),SS=$$PAD2(SS)
 SET S=Y_"-"_M_"-"_DAY_"T"_HH_":"_MM_":"_SS_"Z"
 QUIT S
 ;
PAD2(X) ; Left-pad a numeric value to two digits
 NEW Y
 SET Y=+$GET(X)
 IF Y<10 QUIT "0"_Y
 QUIT Y
 ;
FINAL(OUT) ; Remove internal-only nodes before JSON encoding
 NEW IDX
 IF $GET(OUT("type"))'="transaction",$GET(OUT("type"))'="batch" DO
 . SET IDX=0
 . FOR  SET IDX=$ORDER(OUT("entry",IDX)) Q:IDX<1  KILL OUT("entry",IDX,"request")
 KILL OUT("index")
 KILL ^TMP("C0FHIRBU",$J,"UUID")
 QUIT
 ;
ERR(MSG,OUT) ; Build OperationOutcome-like error payload
 KILL OUT
 SET OUT("resourceType")="OperationOutcome"
 SET OUT("issue",1,"severity")="error"
 SET OUT("issue",1,"code")="processing"
 SET OUT("issue",1,"diagnostics")=$GET(MSG)
 QUIT
 ;
TOJSON(IN,OUT,ERR) ; Encode a local M structure with ENCODE^XLFJSON
 ; IN  = local array by reference
 ; OUT = encoded JSON output nodes
 ; ERR = encoder error array
 DO FINAL(.IN)
 KILL OUT,ERR
 DO ENCODE^XLFJSON("IN","OUT","ERR")
 DO FORCESTR(.OUT)
 QUIT
 ;
FORCESTR(OUT) ; Ensure id/code numeric JSON literals are emitted as strings
 NEW I
 SET I=""
 FOR  SET I=$ORDER(OUT(I)) Q:I=""  DO
 . SET OUT(I)=$$QKEY($GET(OUT(I)),"id")
 . SET OUT(I)=$$QKEY($GET(OUT(I)),"code")
 QUIT
 ;
QKEY(LINE,KEY) ; Quote numeric JSON literal for named key
 NEW CH,DONE,NUM,PAT,POS,SCAN,START,STOP
 SET PAT=""""_$GET(KEY)_""":"
 SET POS=1
 FOR  SET POS=$FIND(LINE,PAT,POS) Q:'POS  DO
 . SET SCAN=POS
 . FOR  Q:SCAN>$LENGTH(LINE)!($EXTRACT(LINE,SCAN)'=" ")  SET SCAN=SCAN+1
 . IF SCAN>$LENGTH(LINE) QUIT
 . SET CH=$EXTRACT(LINE,SCAN)
 . IF CH="""" QUIT  ; already a JSON string
 . IF CH'="-",CH'?1N QUIT
 . SET START=SCAN,STOP=SCAN,DONE=0
 . FOR  QUIT:DONE  DO
 . . SET CH=$EXTRACT(LINE,STOP)
 . . IF CH="" SET DONE=1 QUIT
 . . IF CH="," SET DONE=1 QUIT
 . . IF CH="}" SET DONE=1 QUIT
 . . IF CH="]" SET DONE=1 QUIT
 . . IF CH=" " SET DONE=1 QUIT
 . . SET STOP=STOP+1
 . SET NUM=$EXTRACT(LINE,START,STOP-1)
 . IF '$$ISJNUM(NUM) QUIT
 . SET LINE=$EXTRACT(LINE,1,START-1)_""""_NUM_""""_$EXTRACT(LINE,STOP,$LENGTH(LINE))
 . SET POS=STOP+2
 QUIT LINE
 ;
ISJNUM(X) ; True if X is a valid JSON numeric literal
 NEW FAIL,FST,I,LEN
 SET X=$GET(X),LEN=$LENGTH(X),FAIL=0
 IF LEN<1 QUIT 0
 SET I=1
 IF $EXTRACT(X,I)="-" SET I=I+1
 IF I>LEN QUIT 0
 SET FST=$EXTRACT(X,I)
 IF FST="0" DO
 . SET I=I+1
 ELSE  DO
 . IF FST'?1N SET FAIL=1 QUIT
 . FOR  Q:I>LEN!($EXTRACT(X,I)'?1N)  SET I=I+1
 IF FAIL QUIT 0
 IF I'>LEN,$EXTRACT(X,I)?1N QUIT 0
 IF I'>LEN,$EXTRACT(X,I)="." DO
 . SET I=I+1
 . IF I>LEN SET FAIL=1 QUIT
 . IF $EXTRACT(X,I)'?1N SET FAIL=1 QUIT
 . FOR  Q:I>LEN!($EXTRACT(X,I)'?1N)  SET I=I+1
 IF FAIL QUIT 0
 IF I'>LEN,($EXTRACT(X,I)="e"!($EXTRACT(X,I)="E")) DO
 . SET I=I+1
 . IF I>LEN SET FAIL=1 QUIT
 . IF ($EXTRACT(X,I)="+")!($EXTRACT(X,I)="-") SET I=I+1
 . IF I>LEN SET FAIL=1 QUIT
 . IF $EXTRACT(X,I)'?1N SET FAIL=1 QUIT
 . FOR  Q:I>LEN!($EXTRACT(X,I)'?1N)  SET I=I+1
 IF FAIL QUIT 0
 IF I'>LEN QUIT 0
 QUIT 1
