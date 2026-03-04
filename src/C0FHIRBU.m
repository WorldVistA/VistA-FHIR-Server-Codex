C0FHIRBU ; Bundle orchestration for multi-domain responses
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
 ;
 NEW DFN,VID
 SET DFN=+$GET(REQ("DFN"))
 SET VID=$$ENCIEN($GET(REQ("ENCOUNTER")))
 DO INIT(.OUT,"transaction")
 IF DFN<1 DO ERR("Missing required request value: DFN",.OUT) QUIT
 IF VID<1 DO ERR("Missing or invalid request value: ENCOUNTER",.OUT) QUIT
 DO GETPAT^C0FHIR(.OUT,DFN)
 DO GETENC^C0FHIR(.OUT,VID,DFN)
 QUIT
 ;
BYDATE(REQ,OUT) ; Date-range bundle for encounters and related resources
 ; Expected request parameters:
 ; REQ("DFN")       = patient identifier
 ; REQ("START_DT")  = inclusive start date/time
 ; REQ("END_DT")    = inclusive end date/time
 ;
 NEW DFN
 SET DFN=+$GET(REQ("DFN"))
 DO INIT(.OUT,"transaction")
 IF DFN<1 DO ERR("Missing required request value: DFN",.OUT) QUIT
 DO GETPAT^C0FHIR(.OUT,DFN)
 DO ADDRNG(.REQ,.OUT)
 QUIT
 ;
INIT(OUT,BTYPE) ; Initialize Bundle container
 KILL OUT
 SET OUT("resourceType")="Bundle"
 SET OUT("type")=$GET(BTYPE,"transaction")
 QUIT
 ;
ADDRNG(REQ,OUT) ; Add encounters for a patient date range
 NEW BEG,CNT,DFN,END,LOC,MAX,VDT,VID
 SET DFN=+$GET(REQ("DFN"))
 SET BEG=+$GET(REQ("START_DT"),1410101)
 SET END=$GET(REQ("END_DT"),4141015)
 IF END'["." SET END=END_".24"
 SET MAX=+$GET(REQ("MAX"))
 IF MAX<1 SET MAX=200
 SET (CNT,VDT)=0
 SET VDT=END
 FOR  SET VDT=$ORDER(^AUPNVSIT("AET",DFN,VDT),-1) Q:VDT<BEG!(CNT'<MAX)  DO
 . SET LOC=0
 . FOR  SET LOC=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC)) Q:LOC<1!(CNT'<MAX)  DO
 .. SET VID=0
 .. FOR  SET VID=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC,"P",VID)) Q:VID<1!(CNT'<MAX)  DO
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
 SET OUT("entry",IDX,"request","method")="POST"
 SET OUT("entry",IDX,"request","url")=$GET(RTYPE)
 QUIT
 ;
KEY(RTYPE,RID) ; Build a de-duplication key
 QUIT $GET(RTYPE)_"|"_$$SAFE($GET(RID))
 ;
REFURL(RTYPE,RID) ; Build a deterministic urn:uuid fullUrl
 QUIT "urn:uuid:"_$TRANSLATE($GET(RTYPE)_"-"_$$SAFE($GET(RID))," ","-")
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
 SET T=$PIECE($GET(FMDT),".",2)_"000000"
 SET HH=$EXTRACT(T,1,2),MM=$EXTRACT(T,3,4),SS=$EXTRACT(T,5,6)
 SET S=Y_"-"_M_"-"_DAY_"T"_HH_":"_MM_":"_SS_"Z"
 QUIT S
 ;
FINAL(OUT) ; Remove internal-only nodes before JSON encoding
 KILL OUT("index")
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
 QUIT
