C0RGWBS ; VEHU/Codex - Reminder WriteBack save graph API shim ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;Apr 29, 2026
 ;
 ; Compatibility shim. C0FW-owned implementation lives in C0FWWBS.
 ;
 Q
 ;
WSSAVE(ARGS,BODY,RESULT) ; POST /writebacksaves
 Q $$WSSAVE^C0FWWBS(.ARGS,.BODY,.RESULT)
 ;
WSLIST(RESULT,ARGS) ; GET /writebacksaves
 Q $$WSLIST^C0FWWBS(.RESULT,.ARGS)
 ;
WSGET(RESULT,ARGS) ; GET /writebacksaves/{id}
 Q $$WSGET^C0FWWBS(.RESULT,.ARGS)
 ;
WSRENAME(ARGS,BODY,RESULT) ; POST /writebacksaves/{id}/rename
 Q $$WSRENAME^C0FWWBS(.ARGS,.BODY,.RESULT)
 ;
WSARCH(ARGS,BODY,RESULT) ; POST /writebacksaves/{id}/archive
 Q $$WSARCH^C0FWWBS(.ARGS,.BODY,.RESULT)
 ;
ROOT() ; $$ - graph root
 Q $$ROOT^C0FWWBS()
 ;
NEWID() ; $$ - compact URL-safe id
 Q "wbs-"_$P($H,",",1)_"-"_$P($H,",",2)_"-"_$J
 ;
NOWISO() ; $$ - external timestamp string
 Q $TR($TR($$FMTE^XLFDT($$NOW^XLFDT,"7Z"),"@","T")," ","")
 ;
SETMETA(ROOT,ID,ITEM) ; maintain summary and indexes
 N DFN,ICN,REM,CREATED,KEY
 K @ROOT@("items",ID,"meta")
 S DFN=$G(ITEM("patient","dfn"))
 S ICN=$G(ITEM("patient","icn"))
 S REM=$G(ITEM("reminder","id"))
 S CREATED=$G(ITEM("createdAt")) I CREATED="" S CREATED=$G(ITEM("savedAt"))
 S @ROOT@("items",ID,"meta","id")=ID
 S @ROOT@("items",ID,"meta","name")=$G(ITEM("name"))
 S @ROOT@("items",ID,"meta","createdAt")=CREATED
 S @ROOT@("items",ID,"meta","updatedAt")=$G(ITEM("updatedAt"))
 S @ROOT@("items",ID,"meta","patientDisplay")=$G(ITEM("patient","displayName"))
 S @ROOT@("items",ID,"meta","dfn")=DFN
 S @ROOT@("items",ID,"meta","icn")=ICN
 S @ROOT@("items",ID,"meta","reminderId")=REM
 S @ROOT@("items",ID,"meta","reminderLabel")=$G(ITEM("reminder","label"))
 S @ROOT@("items",ID,"meta","httpStatus")=$G(ITEM("post","status"))
 S @ROOT@("items",ID,"meta","accepted")=$S($G(ITEM("post","persisted")):1,1:0)
 S @ROOT@("items",ID,"meta","archived")=$S($G(ITEM("archived")):1,1:0)
 I DFN'="" S @ROOT@("index","dfn",DFN,ID)=""
 I ICN'="" S @ROOT@("index","icn",ICN,ID)=""
 I REM'="" S @ROOT@("index","reminder",REM,ID)=""
 S KEY=$TR(CREATED,":-.TZ","")
 I KEY="" S KEY=$P($H,",",1)_$P($H,",",2)
 S @ROOT@("index","created",KEY,ID)=""
 Q
 ;
ADDLIST(OUT,ROOT,ID,COUNT,MAX) ; add summary row
 I COUNT'<MAX Q
 I $G(@ROOT@("items",ID,"meta","archived")) Q
 S COUNT=COUNT+1
 M OUT("items",COUNT)=@ROOT@("items",ID,"meta")
 Q
 ;
ENCODEONE(RESULT,ROOT,ID) ; encode one artifact response
 K OUT
 S OUT("status")="ok"
 S OUT("id")=ID
 M OUT("artifact")=@ROOT@("items",ID,"artifact")
 D ENCODE^XLFJSON("OUT","RESULT")
 Q
 ;
ERR(RESULT,CODE,MESSAGE) ; encode error response
 K OUT
 S OUT("status")="error"
 S OUT("error","code")=CODE
 S OUT("error","message")=MESSAGE
 D ENCODE^XLFJSON("OUT","RESULT")
 Q
