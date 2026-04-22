C0RGWEB ; VEHU/Codex - HTTP bridge for rehmp C0RG operations ;Apr 11, 2026
 ;;0.1;C0FHIR PROJECT;;Apr 11, 2026
 ;
 ; POST /rehmp
 ; Body: RequestEnvelope JSON with top-level "operation"
 ;
 Q
 ;
wsRehmp(ARGS,BODY,RESULT) ; Backward-compatible label spelling for existing %web registrations
 IF '$DATA(RESULT) DO  QUIT ""
 . DO WSREHMP2(.ARGS,.BODY)
 DO WSREHMP2(.RESULT,.BODY)
 QUIT ""
 ;
WSREHMP(ARGS,BODY,RESULT) ; %web POST handler
 IF '$DATA(RESULT) DO  QUIT ""
 . DO WSREHMP2(.ARGS,.BODY)
 DO WSREHMP2(.RESULT,.BODY)
 QUIT ""
 ;
WSREHMP2(RESULT,BODY) ; Core POST handler for old/new %web call conventions
 NEW ARGS,RESP,JERR,STATUS,REQID,ECODE,EMSG,OK
 KILL RESULT
 SET HTTPRSP("mime")="application/json"
 ; Older %web stacks can treat any non-empty return value from POST handlers as a
 ; created-resource location, producing HTTP 201 + Location with no response body.
 ; This handler writes RESULT/HTTPERR directly, so always return an empty string.
 ; TEMPORARY: same Kernel job context bootstrap as GETFHIR^C0FHIR (ENVINIT^C0FHIR).
 ; GET /fhir runs WEB^C0FHIRWS -> GETFHIR^C0FHIR, which always DO ENVINIT^C0FHIR first.
 ; POST /rehmp does not, so DUZ/U/DT can be unset and downstream C0RG -> FHIR work can hang
 ; or fail until a real authenticated session establishes DUZ for this %web worker.
 IF $T(ENVINIT^C0FHIR)'="" DO ENVINIT^C0FHIR
 IF '$DATA(BODY) DO  QUIT ""
 . DO ERR^C0RGRES(.RESULT,"","VALIDATION","Empty request body")
 . SET HTTPERR=400
 SET REQID="",ECODE="",EMSG=""
 SET OK=$$HTTP^C0RGAPI(.RESULT,.ARGS,.BODY,.REQID,.ECODE,.EMSG)
 KILL RESP,JERR
 DO DECODE^XLFJSON($NA(RESULT),$NA(RESP),$NA(JERR))
 SET STATUS=$$HTTPSTAT($NA(RESP),$NA(JERR))
 IF STATUS>0 SET HTTPERR=STATUS
 ELSE  SET HTTPERR=0
 QUIT ""
 ;
HTTPSTAT(RESPROOT,JERRROOT) ; $$ - derive HTTP status from a ResponseEnvelope
 IF $$HASERR(JERRROOT) QUIT 500
 IF $GET(@RESPROOT@("status"))'="error" QUIT 0
 QUIT $$MAPSTAT($GET(@RESPROOT@("error","code")))
 ;
HASERR(ROOT) ; $$ - true when XLFJSON populated an error node
 IF $DATA(@ROOT)#2 QUIT 1
 IF $DATA(@ROOT)>1 QUIT 1
 QUIT 0
 ;
MAPSTAT(ECODE) ; Map C0RG error code to HTTP status
 NEW CODE
 SET CODE=$$UP^XLFSTR($GET(ECODE))
 IF CODE="AUTH" QUIT 401
 IF CODE="FORBIDDEN" QUIT 403
 IF CODE="VALIDATION" QUIT 400
 IF CODE="VERSION" QUIT 400
 IF CODE="SIZE" QUIT 413
 IF CODE="NOT_IMPLEMENTED" QUIT 501
 IF CODE="TIMEOUT" QUIT 504
 IF CODE="UPSTREAM" QUIT 502
 QUIT 500
