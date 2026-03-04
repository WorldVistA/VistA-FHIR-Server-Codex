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
 ; TODO: Expand Patient mapping fields beyond resourceType/id.
 NEW IDX
 IF $GET(DFN)="" QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Patient",DFN)
 SET IDX=$GET(RTN("entryCount"))
 SET RTN("entry",IDX,"resource","resourceType")="Patient"
 SET RTN("entry",IDX,"resource","id")=DFN
 SET RTN("entry",IDX,"fullUrl")="Patient/"_DFN
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
