C0RGWBS ; VEHU/Codex - Reminder WriteBack save graph API ;Apr 29, 2026
 ;;0.1;C0FHIR PROJECT;;Apr 29, 2026
 ;
 ; Stores CPRS reminder writeback POST attempts in the active VistA graph
 ; backend via SYNWD. These are review artifacts, not clinical imports.
 ;
 Q
 ;
WSSAVE(ARGS,BODY,RESULT) ; POST /writebacksaves
 N ROOT,JSON,ITEM,ERR,ID,NOW,NAME
 S HTTPRSP("mime")="application/json"
 S ROOT=$$ROOT()
 I ROOT="" D ERR(.RESULT,"GRAPH","Unable to open reminder-writeback-saves graph") Q ""
 I $G(ARGS("action"))="rename" D WSRENAME(.ARGS,.BODY,.RESULT) Q ""
 I $G(ARGS("action"))="archive" D WSARCH(.ARGS,.BODY,.RESULT) Q ""
 I '$D(BODY) D ERR(.RESULT,"VALIDATION","Empty request body") S HTTPERR=400 Q ""
 M JSON=BODY
 D DECODE^XLFJSON("JSON","ITEM","ERR")
 I $D(ERR) D ERR(.RESULT,"JSON","Unable to decode writeback save JSON") S HTTPERR=400 Q ""
 S ID=$G(ITEM("id"))
 I ID="" S ID=$$NEWID()
 S NOW=$$NOWISO()
 S NAME=$G(ITEM("name"))
 I NAME="" S NAME="WriteBack "_ID
 S ITEM("id")=ID
 S ITEM("name")=NAME
 I $G(ITEM("savedAt"))="" S ITEM("savedAt")=NOW
 S ITEM("updatedAt")=NOW
 K @ROOT@("items",ID)
 M @ROOT@("items",ID,"artifact")=ITEM
 D SETMETA(ROOT,ID,.ITEM)
 D ENCODEONE(.RESULT,ROOT,ID)
 Q ""
 ;
WSLIST(RESULT,ARGS) ; GET /writebacksaves
 N ROOT,DFN,ICN,REM,MAX,COUNT,ID,IDX
 S HTTPRSP("mime")="application/json"
 S ROOT=$$ROOT()
 I ROOT="" D ERR(.RESULT,"GRAPH","Unable to open reminder-writeback-saves graph") Q ""
 S ID=$G(ARGS("id")) I ID'="" D  Q ""
 . I '$D(@ROOT@("items",ID)) D ERR(.RESULT,"NOT_FOUND","Saved writeback not found") S HTTPERR=404 Q
 . D ENCODEONE(.RESULT,ROOT,ID)
 S DFN=$G(ARGS("dfn")),ICN=$G(ARGS("icn")),REM=$G(ARGS("reminder"))
 S MAX=+$G(ARGS("max")) I MAX<1 S MAX=50
 K OUT
 S OUT("status")="ok",OUT("graph")="reminder-writeback-saves"
 S COUNT=0
 I DFN'="" D
 . S ID="" F  S ID=$O(@ROOT@("index","dfn",DFN,ID)) Q:ID=""  D ADDLIST(.OUT,ROOT,ID,.COUNT,MAX)
 E  I ICN'="" D
 . S ID="" F  S ID=$O(@ROOT@("index","icn",ICN,ID)) Q:ID=""  D ADDLIST(.OUT,ROOT,ID,.COUNT,MAX)
 E  I REM'="" D
 . S ID="" F  S ID=$O(@ROOT@("index","reminder",REM,ID)) Q:ID=""  D ADDLIST(.OUT,ROOT,ID,.COUNT,MAX)
 E  D
 . S IDX="" F  S IDX=$O(@ROOT@("index","created",IDX),-1) Q:IDX=""  D  Q:COUNT'<MAX
 . . S ID="" F  S ID=$O(@ROOT@("index","created",IDX,ID)) Q:ID=""  D ADDLIST(.OUT,ROOT,ID,.COUNT,MAX) Q:COUNT'<MAX
 S OUT("count")=COUNT
 D ENCODE^XLFJSON("OUT","RESULT")
 Q ""
 ;
WSGET(RESULT,ARGS) ; GET /writebacksaves/{id}
 N ROOT,ID
 S HTTPRSP("mime")="application/json"
 S ROOT=$$ROOT()
 S ID=$G(ARGS("id"))
 I ID="" D ERR(.RESULT,"VALIDATION","Missing saved writeback id") S HTTPERR=400 Q ""
 I ROOT="" D ERR(.RESULT,"GRAPH","Unable to open reminder-writeback-saves graph") Q ""
 I '$D(@ROOT@("items",ID)) D ERR(.RESULT,"NOT_FOUND","Saved writeback not found") S HTTPERR=404 Q ""
 D ENCODEONE(.RESULT,ROOT,ID)
 Q ""
 ;
WSRENAME(ARGS,BODY,RESULT) ; POST /writebacksaves/{id}/rename
 N ROOT,ID,JSON,ITEM,ERR,NAME,NOW
 S HTTPRSP("mime")="application/json"
 S ROOT=$$ROOT(),ID=$G(ARGS("id"))
 I ID="" D ERR(.RESULT,"VALIDATION","Missing saved writeback id") S HTTPERR=400 Q ""
 I '$D(@ROOT@("items",ID)) D ERR(.RESULT,"NOT_FOUND","Saved writeback not found") S HTTPERR=404 Q ""
 M JSON=BODY
 D DECODE^XLFJSON("JSON","ITEM","ERR")
 I $D(ERR) D ERR(.RESULT,"JSON","Unable to decode rename JSON") S HTTPERR=400 Q ""
 S NAME=$G(ITEM("name"))
 I NAME="" D ERR(.RESULT,"VALIDATION","Name is required") S HTTPERR=400 Q ""
 S NOW=$$NOWISO()
 S @ROOT@("items",ID,"artifact","name")=NAME
 S @ROOT@("items",ID,"artifact","updatedAt")=NOW
 S @ROOT@("items",ID,"meta","name")=NAME
 S @ROOT@("items",ID,"meta","updatedAt")=NOW
 D ENCODEONE(.RESULT,ROOT,ID)
 Q ""
 ;
WSARCH(ARGS,BODY,RESULT) ; POST /writebacksaves/{id}/archive
 N ROOT,ID,NOW
 S HTTPRSP("mime")="application/json"
 S ROOT=$$ROOT(),ID=$G(ARGS("id"))
 I ID="" D ERR(.RESULT,"VALIDATION","Missing saved writeback id") S HTTPERR=400 Q ""
 I '$D(@ROOT@("items",ID)) D ERR(.RESULT,"NOT_FOUND","Saved writeback not found") S HTTPERR=404 Q ""
 S NOW=$$NOWISO()
 S @ROOT@("items",ID,"artifact","archived")=1
 S @ROOT@("items",ID,"artifact","archivedAt")=NOW
 S @ROOT@("items",ID,"meta","archived")=1
 S @ROOT@("items",ID,"meta","archivedAt")=NOW
 D ENCODEONE(.RESULT,ROOT,ID)
 Q ""
 ;
ROOT() ; $$ - graph root
 Q $$setroot^SYNWD("reminder-writeback-saves")
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
