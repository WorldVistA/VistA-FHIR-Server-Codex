C0FHIR ; VistA FHIR Server entry points
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
 SET NAME=$PIECE(X0,U)
 SET RTN("entry",IDX,"resource","resourceType")="Patient"
 SET RTN("entry",IDX,"resource","id")=DFN
 IF NAME'="" DO
 . SET RTN("entry",IDX,"resource","name",1,"text")=NAME
 . SET FAM=$$TRIM($PIECE(NAME,",",1))
 . SET GIV=$$TRIM($PIECE(NAME,",",2,99))
 . IF FAM'="" SET RTN("entry",IDX,"resource","name",1,"family")=FAM
 . IF GIV'="" SET RTN("entry",IDX,"resource","name",1,"given",1)=GIV
 SET SEX=$PIECE(X0,U,2)
 IF SEX'="" SET RTN("entry",IDX,"resource","gender")=$$GENDER(SEX)
 SET DOB=+$PIECE(X0,U,3)
 IF DOB>0 SET RTN("entry",IDX,"resource","birthDate")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 SET SSN=$PIECE(X0,U,9)
 IF SSN?9N DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-ssn"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=SSN
 QUIT
 ;
GETENC(RTN,ENCIEN,DFN) ; Add Encounter resource to the passed bundle array
 ; ENCIEN is expected to be a visit ien from ^AUPNVSIT
 NEW CLASS,ENC,IDX,TYPE
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
 SET TYPE=$PIECE($GET(ENC("type")),U,2)
 IF TYPE'="" SET RTN("entry",IDX,"resource","type",1,"text")=TYPE
 QUIT
 ;
GETFHIR(RTN,FILTER) ; Web service entry point
 ; FILTER contains URL parameters, for example FILTER("dfn")=12345
 ; RTN returns JSON output nodes from ENCODE^XLFJSON
 NEW ERR,REQ,TMP
 KILL RTN
 DO MAPFILT(.FILTER,.REQ)
 IF $GET(REQ("DFN"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Missing required URL parameter: dfn",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 SET REQ("MODE")=$$REQMODE(.REQ)
 IF $GET(REQ("MODE"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Cannot determine request mode from URL parameters",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 DO GETBNDLJ(.REQ,.RTN,.ERR)
 IF $DATA(ERR) DO
 . DO ERR^C0FHIRBU("JSON encoding failed in ENCODE^XLFJSON",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 QUIT
 ;
GETBNDL(REQ,OUT) ; Return one Bundle response structure for a request
 ; REQ("MODE")="ENCOUNTER" or "DATERANGE"
 ; REQ(...) contains request parameters (DFN, encounter/date filters, etc.)
 NEW MODE
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
 KILL REQ
 SET REQ("DFN")=$SELECT($GET(FILTER("dfn"))'="":$GET(FILTER("dfn")),1:$GET(FILTER("DFN")))
 SET REQ("ENCOUNTER")=$SELECT($GET(FILTER("encounter"))'="":$GET(FILTER("encounter")),1:$GET(FILTER("ENCOUNTER")))
 SET REQ("START_DT")=$SELECT($GET(FILTER("start"))'="":$GET(FILTER("start")),1:$GET(FILTER("START")))
 SET REQ("END_DT")=$SELECT($GET(FILTER("end"))'="":$GET(FILTER("end")),1:$GET(FILTER("END")))
 SET REQ("MODE")=$$UPCASE($SELECT($GET(FILTER("mode"))'="":$GET(FILTER("mode")),1:$GET(FILTER("MODE"))))
 SET REQ("MAX")=$SELECT($GET(FILTER("max"))'="":+$GET(FILTER("max")),1:+$GET(FILTER("MAX")))
 QUIT
 ;
REQMODE(REQ) ; Resolve request mode from mapped parameters
 NEW MODE
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" QUIT "ENCOUNTER"
 IF MODE="DATERANGE" QUIT "DATERANGE"
 IF $GET(REQ("ENCOUNTER"))'="" QUIT "ENCOUNTER"
 IF $GET(REQ("START_DT"))'="" QUIT "DATERANGE"
 IF $GET(REQ("END_DT"))'="" QUIT "DATERANGE"
 QUIT ""
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
