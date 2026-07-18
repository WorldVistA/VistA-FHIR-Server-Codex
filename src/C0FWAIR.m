C0FWAIR ; VEHU/Codex - AI Consult quality review apply ;Jul 18, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 18, 2026
 ;
 Q
 ;
WSAPP(ARGS,BODY,RESULT) ; POST /aiconsult/apply-review?id= to file selected quality artifacts
 I '$D(RESULT) D WSAPP2(.ARGS,.BODY) Q ""
 D WSAPP2(.RESULT,.BODY)
 Q ""
 ;
WSAPP2(OUT,BODY) ; Apply saved quality review through updatepatient
 N DFN,ERR,ID,ROOT,UPD
 S U="^",HTTPRSP("mime")="application/json"
 K OUT
 S ID=$G(HTTPARGS("id"))
 I ID="" S ID=$G(HTTPARGS("review"))
 I ID="" D OO(.OUT,"Missing review id parameter") Q
 S ROOT=$$ROOT^C0FWWBS()
 I ROOT="" D OO(.OUT,"Unable to open reminder-writeback-saves graph") Q
 I '$D(@ROOT@("items",ID,"artifact")) D OO(.OUT,"Saved review artifact not found") Q
 S DFN=+$G(@ROOT@("items",ID,"artifact","patient","dfn"))
 I DFN<1 D OO(.OUT,"Saved review artifact has no DFN") Q
 I $G(@ROOT@("items",ID,"artifact","post","status"))="applied-updatepatient" D RESP(.OUT,ROOT,ID,"already_applied") Q
 D FILEUPD(ROOT,ID,DFN,.UPD,.ERR)
 I $G(ERR)'="" D OO(.OUT,ERR) Q
 D MARK(ROOT,ID,.UPD)
 D RESP(.OUT,ROOT,ID,"applied")
 Q
 ;
FILEUPD(ROOT,ID,DFN,UPD,ERR) ; File saved updateBundle through native updatepatient
 N ARGS,BODY,JSON,RET
 K UPD,ERR,BODY,RET,JSON
 I '$D(@ROOT@("items",ID,"artifact","updateBundle","entry")) S ERR="Saved review has no updateBundle entries" Q
 M JSON=@ROOT@("items",ID,"artifact","updateBundle")
 D TOJSON^C0FHIRBU(.JSON,.BODY,.ERR)
 I $D(ERR) S ERR="Unable to encode quality update Bundle" Q
 K JSON
 S ARGS("dfn")=+DFN,ARGS("load")=1,ARGS("returngraph")=1
 D wsUpdatePatient^C0FWUPD(.ARGS,.BODY,.RET)
 D DECODE^XLFJSON("RET","JSON","ERR")
 I $D(ERR) S ERR="Unable to decode updatepatient response" Q
 M UPD=JSON
 I $G(UPD("status"))'="ok" S ERR=$G(UPD("error","message")) I ERR="" S ERR="updatepatient did not return status ok"
 Q
 ;
NOTE(ROOT,ID) ; $$ - note text for saved quality review
 N ACT,DFN,I,LINE,NOTE,PNAME,RES,TEXT,TYPE
 S DFN=+$G(@ROOT@("items",ID,"artifact","patient","dfn"))
 S PNAME=$G(@ROOT@("items",ID,"artifact","patient","displayName"))
 S NOTE="Quality AI Consult Update Review"_$C(10)_$C(10)
 S NOTE=NOTE_"Review artifact: "_ID_$C(10)
 S NOTE=NOTE_"Patient DFN: "_DFN_$S(PNAME'="":" ("_PNAME_")",1:"")_$C(10)_$C(10)
 S NOTE=NOTE_"Selected actions:"_$C(10)
 S I=0 F  S I=$O(@ROOT@("items",ID,"artifact","acceptedActions",I)) Q:+I=0  D
 . S ACT=$G(@ROOT@("items",ID,"artifact","acceptedActions",I))
 . I ACT'="" S NOTE=NOTE_"- "_ACT_$C(10)
 S NOTE=NOTE_$C(10)_"Proposed FHIR transaction resources (not filed by this note):"_$C(10)
 S I=0 F  S I=$O(@ROOT@("items",ID,"artifact","updateBundle","entry",I)) Q:+I=0  D
 . S RES=$NA(@ROOT@("items",ID,"artifact","updateBundle","entry",I,"resource"))
 . S TYPE=$G(@RES@("resourceType")) Q:TYPE=""
 . S LINE="- "_TYPE_"/"_$G(@RES@("id"))
 . S TEXT=$G(@RES@("code","text")) I TEXT'="" S LINE=LINE_" - "_TEXT
 . S NOTE=NOTE_LINE_$C(10)
 S NOTE=NOTE_$C(10)_"No diagnosis, vital, laboratory, or order resource was filed automatically."
 S NOTE=NOTE_$C(10)_"The proposed changes remain available for clinician review in the saved artifact."
 Q NOTE
 ;
MARK(ROOT,ID,UPD) ; Mark review artifact as applied through updatepatient
 N ITEM,NOW
 S NOW=$$NOWISO^C0FWWBS()
 S @ROOT@("items",ID,"artifact","post","status")="applied-updatepatient"
 S @ROOT@("items",ID,"artifact","post","persisted")=1
 M @ROOT@("items",ID,"artifact","post","updatepatient")=UPD
 S @ROOT@("items",ID,"artifact","appliedAt")=NOW
 S @ROOT@("items",ID,"artifact","updatedAt")=NOW
 M ITEM=@ROOT@("items",ID,"artifact")
 D SETMETA^C0FWWBS(ROOT,ID,.ITEM)
 Q
 ;
RESP(OUT,ROOT,ID,STATUS) ; Encode apply-review response
 N MSG,RESP
 K RESP,OUT
 S MSG=$S($G(STATUS)="already_applied":"Review was already applied through updatepatient",1:"Review applied through updatepatient")
 S RESP("status")=$G(STATUS)
 S RESP("id")=ID
 S RESP("message")=MSG
 M RESP("updatepatient")=@ROOT@("items",ID,"artifact","post","updatepatient")
 M RESP("artifact")=@ROOT@("items",ID,"artifact")
 D ENCODE^XLFJSON("RESP","OUT")
 Q
 ;
OO(OUT,MSG) ; Encode apply-review error
 N TMP
 K OUT
 S HTTPRSP("mime")="application/json",HTTPERR=400
 S TMP("status")="error"
 S TMP("error","code")="exception"
 S TMP("error","message")=$G(MSG)
 D ENCODE^XLFJSON("TMP","OUT")
 Q
 ;
