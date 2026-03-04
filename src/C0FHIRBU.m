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
 ; TODO:
 ; 1) Resolve the target encounter.
 ; 2) Add patient resource via GETPAT^C0FHIR.
 ; 3) Add encounter resource to the Bundle.
 ; 4) Follow supporting references across required domains.
 ; 5) De-duplicate resources by resourceType/id.
 ; 6) Encode one JSON Bundle response with ENCODE^XLFJSON.
 DO INIT(.OUT,"collection")
 DO GETPAT^C0FHIR(.OUT,$GET(REQ("DFN")))
 QUIT
 ;
BYDATE(REQ,OUT) ; Date-range bundle for encounters and related resources
 ; Expected request parameters:
 ; REQ("DFN")       = patient identifier
 ; REQ("START_DT")  = inclusive start date/time
 ; REQ("END_DT")    = inclusive end date/time
 ;
 ; TODO:
 ; 1) Resolve encounters in date range.
 ; 2) Add patient resource via GETPAT^C0FHIR.
 ; 3) Add encounter resources to the Bundle.
 ; 4) Add related resources needed to support each encounter.
 ; 5) De-duplicate resources by resourceType/id.
 ; 6) Encode one JSON Bundle response with ENCODE^XLFJSON.
 DO INIT(.OUT,"searchset")
 DO GETPAT^C0FHIR(.OUT,$GET(REQ("DFN")))
 QUIT
 ;
INIT(OUT,BTYPE) ; Initialize Bundle container
 KILL OUT
 SET OUT("resourceType")="Bundle"
 SET OUT("type")=$GET(BTYPE,"collection")
 SET OUT("entryCount")=0
 QUIT
 ;
ADDRES(OUT,RTYPE,RID) ; Add placeholder Bundle entry metadata
 NEW IDX
 SET IDX=$GET(OUT("entryCount"))+1
 SET OUT("entryCount")=IDX
 SET OUT("entry",IDX,"resourceType")=$GET(RTYPE)
 SET OUT("entry",IDX,"id")=$GET(RID)
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
 KILL OUT,ERR
 DO ENCODE^XLFJSON("IN","OUT","ERR")
 QUIT
