C0FHIR ; VistA FHIR Server entry points
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 ; Namespace convention:
 ; - All project MUMPS routines use the C0FHIR prefix.
 ; - New DDE entities defined for this project use the C0FHIR namespace.
 ; - Bundle requests return one multi-domain FHIR Bundle per request.
 ;
 QUIT  ; No default action
 ;
GETPAT(DFN,OUT) ; Build Patient resource JSON for patient DFN
 ; TODO: Implement Patient resource mapping and serialization.
 QUIT
 ;
GETBNDL(REQ,OUT) ; Return one Bundle response for a request
 ; REQ("MODE")="ENCOUNTER" or "DATERANGE"
 ; REQ(...) contains request parameters (DFN, encounter/date filters, etc.)
 NEW MODE
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" DO BYENC^C0FHIRBU(.REQ,.OUT) QUIT
 IF MODE="DATERANGE" DO BYDATE^C0FHIRBU(.REQ,.OUT) QUIT
 DO ERR^C0FHIRBU("Unsupported bundle mode: "_MODE,.OUT)
 QUIT
