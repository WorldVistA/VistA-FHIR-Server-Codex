C0FHIRGF ; VAMC/JS - FHIR RPC gateway wrappers
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GENFULL(RTN,DFN,ENCPTR,SDT,EDT,MAX,MODE,DOMAINS) ; RPC entry point for full bundle
 ; RTN returns JSON lines as an array from ENCODE^XLFJSON.
 ; Parameters mirror the Broker RPC definition:
 ;   DFN    (required) patient IEN
 ;   ENCPTR (optional) encounter IEN
 ;   SDT    (optional) start date (FileMan or %DT expression)
 ;   EDT    (optional) end date (FileMan or %DT expression)
 ;   MAX    (optional) max resources
 ;   MODE   (optional) ENCOUNTER or DATERANGE
 ;   DOMAINS (optional) comma-separated domain list
 NEW FILTER
 KILL RTN
 IF $GET(DFN)'="" SET FILTER("dfn")=$GET(DFN)
 IF $GET(ENCPTR)'="" SET FILTER("encounter")=$GET(ENCPTR)
 IF $GET(SDT)'="" SET FILTER("start")=$GET(SDT)
 IF $GET(EDT)'="" SET FILTER("end")=$GET(EDT)
 IF +$GET(MAX)>0 SET FILTER("max")=+$GET(MAX)
 IF $GET(MODE)'="" SET FILTER("mode")=$GET(MODE)
 IF $GET(DOMAINS)'="" SET FILTER("domains")=$GET(DOMAINS)
 DO GETFHIR^C0FHIR(.RTN,.FILTER)
 QUIT
 ;
