C0FWAIC ; VEHU/Codex - C0FW AI Consult DiagnosticReport filing ;Jun 04, 2026
 ;;0.1;C0FHIR PROJECT;;Jun 04, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one AI Consult DiagnosticReport as a TIU document
 N DFN,RES,TITLE,TIUTITLE,TXT
 I '$$ISAIC(ROOT,IEN,RIEN) D ERR(ROOT,IEN,RIEN,"DiagnosticReport is not marked as AI Consult",.RETURN) Q
 S DFN=$$DFN(ROOT,IEN,RIEN)
 I DFN<1 D ERR(ROOT,IEN,RIEN,"AI Consult DiagnosticReport has no resolved DFN",.RETURN) Q
 S TXT=$$TEXT(ROOT,IEN,RIEN)
 I TXT="" D ERR(ROOT,IEN,RIEN,"AI Consult DiagnosticReport has no note text",.RETURN) Q
 S TITLE=$$TITLE(ROOT,IEN,RIEN)
 I TITLE="" S TITLE="AI Consult"
 S TIUTITLE=$$ENSURETTL()
 I TIUTITLE="" D ERR(ROOT,IEN,RIEN,"AI Consult TIU document definition is unavailable",.RETURN) Q
 S @ROOT@(IEN,"load","AIConsult",RIEN,"resourceType")="DiagnosticReport"
 S @ROOT@(IEN,"load","AIConsult",RIEN,"title")=TITLE
 S @ROOT@(IEN,"load","AIConsult",RIEN,"tiuTitle")=TIUTITLE
 I $$HASPTFILE(DFN,TXT) D  Q
 . S @ROOT@(IEN,"load","AIConsult",RIEN,"result")="already matched patient TIU"
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"AIConsult","DiagnosticReport","skipped","AI Consult TIU document already matched patient TIU",.RETURN)
 S RES=$$MAKENOV^C0FWTIU(DFN,TXT,TIUTITLE)
 S @ROOT@(IEN,"load","AIConsult",RIEN,"result")=RES
 I +RES>0 D  Q
 . S @ROOT@(IEN,"load","AIConsult",RIEN,"tiuIen")=+RES
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"AIConsult","DiagnosticReport","loaded","AI Consult TIU document filed",.RETURN)
 D ERR(ROOT,IEN,RIEN,"AI Consult TIU filing failed: "_RES,.RETURN)
 Q
 ;
ISAIC(ROOT,IEN,RIEN) ; $$ - true if DiagnosticReport should file as AI Consult
 N S
 I $G(ROOT)="" Q 0
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="DiagnosticReport" Q 0
 S S=$$UP($$FIELD(ROOT,IEN,RIEN))
 I S["AI CONSULT" Q 1
 I S["CDS-HOOKS-ON-FHIR" Q 1
 Q 0
 ;
FIELD(ROOT,IEN,RIEN) ; $$ - searchable report metadata
 N I,J,S
 S S=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","conclusion"))
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I)) Q:+I=0  D
 . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"system"))
 . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"code"))
 . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"display"))
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I)) Q:+I=0  D
 . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"text"))
 . S J=0 F  S J=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J)) Q:+J=0  D
 . . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"system"))
 . . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code"))
 . . S S=S_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"display"))
 Q S
 ;
DFN(ROOT,IEN,RIEN) ; $$ - patient DFN from subject or graph row
 N ID,REF
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","reference"))
 I REF["Patient/" D  I ID>0 Q ID
 . S ID=$P(REF,"Patient/",2),ID=$P(ID,"/",1),ID=$P(ID,";",1)
 . I ID?1.N,$D(^DPT(+ID,0)) Q
 . S ID=0
 S ID=+$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","identifier","value"))
 I ID>0,$D(^DPT(ID,0)) Q ID
 Q +$O(@ROOT@("SPO",IEN,"DFN",""))
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - encounter visit pointer
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","encounter","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 Q +VISIT
 ;
HASPTFILE(DFN,TXT) ; $$ - AI Consult text already exists for patient
 N SNIP,TIU
 S SNIP=$$SNIP^C0FWTIU($G(TXT))
 I SNIP="" Q 0
 S TIU=0
 F  S TIU=$O(^TIU(8925,"C",+$G(DFN),TIU)) Q:+TIU=0  I $$TXTHAS^C0FWTIU(TIU,SNIP) Q
 Q $S(+TIU>0:1,1:0)
 ;
TITLE(ROOT,IEN,RIEN) ; $$ - TIU title
 N S,T
 S T=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I T="" S T=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I T="" S T="AI Consult"
 I $$UP(T)'["AI CONSULT" S T="AI Consult - "_T
 Q $$TRIM(T)
 ;
ENSURETTL() ; $$ - site TIU title for AI Consult DiagnosticReports
 N CLASS,ERR,FDA,IENS,NAME,Y
 S NAME="AI CONSULT DIAGNOSTIC REPORT"
 S Y=$$FIND1^DIC(8925.1,,"QX",NAME,"B")
 I Y<1 D
 . K ERR,FDA,IENS
 . S FDA(8925.1,"+1,",.01)=NAME
 . S FDA(8925.1,"+1,",.02)="AICDR"
 . S FDA(8925.1,"+1,",.03)="AI Consult Diagnostic Report"
 . S FDA(8925.1,"+1,",.04)="DOC"
 . S FDA(8925.1,"+1,",.06)=55
 . S FDA(8925.1,"+1,",.07)=11
 . D UPDATE^DIE("","FDA","IENS","ERR")
 . I '$D(ERR) S Y=+$G(IENS(1))
 I Y<1 Q ""
 S CLASS=$$FIND1^DIC(8925.1,,"QX","PROGRESS NOTES","B")
 I CLASS>0,'$D(^TIU(8925.1,CLASS,10,"B",Y)) D
 . K ERR,FDA,IENS
 . S FDA(8925.14,"+1,"_CLASS_",",.01)=Y
 . D UPDATE^DIE("","FDA","IENS","ERR")
 Q NAME
 ;
TEXT(ROOT,IEN,RIEN) ; $$ - note text for TIU
 N CODE,CONC,DATA,DISP,I,OUT,PF,TXT
 S OUT=$$TITLE(ROOT,IEN,RIEN)
 S CONC=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","conclusion"))
 I CONC'="" S OUT=OUT_$C(10)_$C(10)_CONC
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","conclusionCode",I)) Q:+I=0  D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","conclusionCode",I,"coding",1,"code"))
 . S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","conclusionCode",I,"coding",1,"display"))
 . I CODE'=""!(DISP'="") S OUT=OUT_$C(10)_"Conclusion code: "_CODE_" "_DISP
 S PF=0 F  S PF=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","presentedForm",PF)) Q:+PF=0  D
 . S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","presentedForm",PF,"data"))
 . I TXT'="" D
 . . S DATA=$TR(TXT,$C(10)_$C(13)_" ","")
 . . I $T(DECODE64^SYNWEBUT)'="" S TXT=$$DECODE64^SYNWEBUT(DATA)
 . S TXT=$S(TXT'="":TXT,1:$G(@ROOT@(IEN,"json","entry",RIEN,"resource","presentedForm",PF,"title")))
 . I TXT'="" S OUT=OUT_$C(10)_$C(10)_TXT
 Q $$TRIM(OUT)
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record AI Consult error
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"AIConsult","DiagnosticReport",$G(MSG),.RETURN)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
TRIM(X) ; $$ - trim simple whitespace
 S X=$G(X)
 F  Q:$E(X,1)'=" "  S X=$E(X,2,$L(X))
 F  Q:$E(X,$L(X))'=" "  S X=$E(X,1,$L(X)-1)
 Q X
 ;
