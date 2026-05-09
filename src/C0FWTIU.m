C0FWTIU ; VEHU/Codex - C0FW TIU document writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; DocumentReference/TIU filing placeholder
 N MSG
 S MSG="DocumentReference TIU filing is not implemented in this C0FW slice; Encounter.note filing is supported."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"DocumentReference","DocumentReference",MSG,.RETURN)
 Q
 ;
LOADENC(ROOT,IEN,RIEN,RETURN) ; File Encounter.note annotations as visit-linked TIU
 N DFN,NI,NOTES,TXT,VISIT
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Encounter" Q
 I '$D(@ROOT@(IEN,"json","entry",RIEN,"resource","note")) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 S VISIT=+$G(@ROOT@(IEN,"load","Encounter",RIEN,"visitIen"))
 I VISIT<1 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id")))
 I VISIT<1 D ERR(ROOT,IEN,RIEN,"Encounter.note has no visit pointer",.RETURN) Q
 S (NI,NOTES)=0
 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI)) Q:+NI=0  D
 . S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"text"))
 . Q:TXT=""
 . S NOTES=NOTES+1
 . D FILENOTE(ROOT,IEN,RIEN,NI,DFN,VISIT,TXT)
 I NOTES<1 Q
 D SUMMARY(ROOT,IEN,RIEN,.RETURN)
 Q
 ;
FILENOTE(ROOT,IEN,RIEN,NI,DFN,VISIT,TXT) ; File one Encounter.note
 N RES,TITLE
 S TITLE=$$TITLE(ROOT,IEN,RIEN,NI,TXT)
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"title")=TITLE
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"visitIen")=+VISIT
 I $$HASFILE(VISIT,TXT) D  Q
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status")="skipped"
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"result")="already matched visit-linked TIU"
 I $T(MAKE^TIUSRVP)="" D  Q
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status")="error"
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"result")="TIUSRVP unavailable"
 S RES=$$MAKE(DFN,VISIT,TXT,TITLE)
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"result")=RES
 I +RES>0 D  Q
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status")="filed"
 . S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"ien")=+RES
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status")="error"
 Q
 ;
MAKE(DFN,VISIT,TXT,TITLE) ; $$ - create visit-linked TIU note
 N CH,DUZSAVE,LINE,N,POS,RESULT,TIUX
 I +$G(DFN)<1 Q "0^missing DFN"
 I +$G(VISIT)<1 Q "0^missing visit IEN"
 I $G(TXT)="" Q "0^empty note"
 S TITLE=$$TITLEIEN($G(TITLE))
 I TITLE<1 Q "0^no TIU title"
 D DUZ^C0FWCTX
 D IO^C0FWCTX
 S DUZSAVE=$G(DUZ)
 S DUZ=$$USER^C0FWENC()
 S TIUX(1202)=DUZ
 S TXT=$$STRIPDOC($TR($G(TXT),$C(13),""))
 S (LINE,N)=""
 F POS=1:1:$L(TXT) S CH=$E(TXT,POS) D
 . I CH=$C(10) D ADDLINE(.TIUX,.N,LINE) S LINE="" Q
 . S LINE=LINE_CH
 D ADDLINE(.TIUX,.N,LINE)
 I +$G(N)<1 S TIUX("TEXT",1,0)=TXT
 S RESULT=0
 D MAKE^TIUSRVP(.RESULT,DFN,TITLE,"","",VISIT,.TIUX,"",0,0)
 S DUZ=DUZSAVE
 Q $G(RESULT)
 ;
TITLE(ROOT,IEN,RIEN,NI,TXT) ; $$ - title from note extension/header/default
 N TITLE
 S TITLE=$$EXTITLE(ROOT,IEN,RIEN,NI)
 I TITLE'="" Q TITLE
 S TITLE=$$DOCTITLE($G(TXT))
 I TITLE'="" Q TITLE
 Q "PROGRESS NOTES"
 ;
EXTITLE(ROOT,IEN,RIEN,NI) ; $$ - va-tiu-note-title extension value
 N EI,TITLE,URL
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI)) Q:+EI=0  D  Q:TITLE'=""
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI,"url"))
 . Q:URL'["va-tiu-note-title"
 . S TITLE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI,"valueString"))
 . I TITLE="" S TITLE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI,"valueCode"))
 . I TITLE="" S TITLE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI,"valueCodeableConcept","text"))
 . I TITLE="" S TITLE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"extension",EI,"valueCodeableConcept","coding",1,"display"))
 Q $$TRIM($G(TITLE))
 ;
TITLEIEN(NAME) ; $$ - TIU document definition IEN
 N Y
 S NAME=$$TRIM($G(NAME))
 I NAME'="" S Y=$$FIND1^DIC(8925.1,,"QX",NAME,"B") I Y>0 Q +Y
 S Y=$$FIND1^DIC(8925.1,,"QX","PROGRESS NOTES","B")
 I Y'>0 S Y=$$FIND1^DIC(8925.1,,"QX","PRIMARY CARE NOTE","B")
 Q +Y
 ;
ADDLINE(TIUX,N,LINE) ; Append wrapped source line
 N I,TLI
 I $G(LINE)="" S N=+$G(N)+1,TIUX("TEXT",N,0)="" Q
 K TLI S TLI(0)=LINE
 D WRAP^DIKCU2(.TLI,80)
 F I=0:1:$O(TLI(" "),-1) S N=+$G(N)+1,TIUX("TEXT",N,0)=TLI(I)
 Q
 ;
HASFILE(VISIT,TXT) ; $$ - note text already exists for visit
 N SNIP,TIU
 S SNIP=$$SNIP($G(TXT))
 I SNIP="" Q 0
 S TIU=0
 F  S TIU=$O(^TIU(8925,"V",+$G(VISIT),TIU)) Q:+TIU=0  I $$TXTHAS(TIU,SNIP) Q
 Q $S(+TIU>0:1,1:0)
 ;
TXTHAS(TIU,SNIP) ; $$ - TIU text has snippet
 N I
 S I=0
 F  S I=$O(^TIU(8925,+$G(TIU),"TEXT",I)) Q:+I=0  I $G(^TIU(8925,+$G(TIU),"TEXT",I,0))[SNIP Q
 Q $S(+I>0:1,1:0)
 ;
SNIP(TXT) ; $$ - useful matching snippet
 N I,LINE,STR
 S STR=$$STRIPDOC($G(TXT))
 F I=1:1:$L(STR,$C(10)) D  Q:$L($G(LINE))>12
 . S LINE=$$TRIM($P(STR,$C(10),I))
 I $L($G(LINE))<1 Q ""
 Q $E(LINE,1,40)
 ;
STRIPDOC(TXT) ; $$ - remove "Document:" title header
 N FIRST,REST
 S TXT=$TR($G(TXT),$C(13),"")
 S FIRST=$$TRIM($P(TXT,$C(10),1))
 I $$UP(FIRST)'?1"DOCUMENT:"1.E Q TXT
 S REST=$P(TXT,$C(10),2,999999)
 I $E(REST,1)=$C(10) S REST=$E(REST,2,$L(REST))
 Q REST
 ;
DOCTITLE(TXT) ; $$ - title from "Document:" first line
 N LINE
 S LINE=$$TRIM($P($G(TXT),$C(10),1))
 I $E($$UP(LINE),1,9)="DOCUMENT:" Q $$TRIM($E(LINE,10,$L(LINE)))
 Q ""
 ;
SUMMARY(ROOT,IEN,RIEN,RETURN) ; Record note filing aggregate
 N ERR,FILED,NI,SKIP,STATUS
 S (ERR,FILED,SKIP)=0,NI=0
 F  S NI=$O(@ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI)) Q:+NI=0  D
 . I $G(@ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status"))="filed" S FILED=FILED+1
 . I $G(@ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status"))="skipped" S SKIP=SKIP+1
 . I $G(@ROOT@(IEN,"load","DocumentReference",RIEN,"tiu",NI,"status"))="error" S ERR=ERR+1
 S STATUS=$S(ERR>0:"error",FILED>0:"loaded",SKIP>0:"skipped",1:"skipped")
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"DocumentReference","Encounter.note",STATUS,$S(FILED>0:"Encounter.note filed to TIU",ERR>0:"Encounter.note TIU filing error",1:"Encounter.note already matched TIU"),.RETURN)
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"filed")=FILED
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"skipped")=SKIP
 S @ROOT@(IEN,"load","DocumentReference",RIEN,"errors")=ERR
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record TIU error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"DocumentReference","Encounter.note",$G(MSG),.RETURN)
 Q
 ;
TRIM(X) ; $$ - trim spaces
 F  Q:$E($G(X),1)'=" "  S X=$E(X,2,$L(X))
 F  Q:$E($G(X),$L(X))'=" "  S X=$E(X,1,$L(X)-1)
 Q $G(X)
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
