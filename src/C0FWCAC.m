C0FWCAC ; VEHU/Codex - Cached FHIR bundle search indexes ;Jul 05, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 05, 2026
 ;
 Q
 ;
GET(REQ,OUT) ; Read-through cache for generated patient bundles
 N CID,DFN,IEN,REFRESH,ROOT,SAVEIEN,SAVEROOT
 S DFN=+$G(REQ("DFN"))
 I DFN<1 D LIVE(.REQ,.OUT) Q 1
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" D LIVE(.REQ,.OUT) Q 1
 S IEN=$$DFN2IEN^C0FWFUTL(DFN)
 I IEN<1 D LIVE(.REQ,.OUT) Q 1
 S CID=$$CID(.REQ)
 S REFRESH=+$G(REQ("REFRESH"))
 I 'REFRESH,$D(@ROOT@(IEN,"cache",CID,"bundle","resourceType")) M OUT=@ROOT@(IEN,"cache",CID,"bundle") Q 1
 S SAVEIEN=IEN,SAVEROOT=ROOT
 D LIVE(.REQ,.OUT)
 S IEN=SAVEIEN,ROOT=SAVEROOT
 D STORE(ROOT,IEN,CID,.REQ,.OUT)
 Q 1
 ;
LIVE(REQ,OUT) ; Build the uncached bundle
 K OUT
 D GETBNDL^C0FHIR(.REQ,.OUT)
 D FINAL^C0FHIRBU(.OUT)
 Q
 ;
STORE(ROOT,IEN,CID,REQ,BUNDLE) ; Store and index a derived bundle
 K @ROOT@(IEN,"cache",CID)
 M @ROOT@(IEN,"cache",CID,"bundle")=BUNDLE
 S @ROOT@(IEN,"cache",CID,"meta","createdAt")=$$NOW()
 S @ROOT@(IEN,"cache",CID,"meta","dfn")=+$G(REQ("DFN"))
 S @ROOT@(IEN,"cache",CID,"meta","requestHash")=CID
 D INDEX(ROOT,IEN,CID)
 Q
 ;
INV(IEN,ROOT) ; Invalidate cached bundles for one graph row
 I $G(ROOT)="" S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 Q:+$G(IEN)<1
 K @ROOT@(IEN,"cache")
 Q
 ;
CID(REQ) ; $$ - stable cache id for a normalized request
 N DOM,KEY,SIG
 S SIG="dfn="_+$G(REQ("DFN"))_"|mode="_$G(REQ("MODE"))_"|enc="_$G(REQ("ENCOUNTER"))
 S SIG=SIG_"|start="_$G(REQ("START_DT"))_"|end="_$G(REQ("END_DT"))_"|max="_+$G(REQ("MAX"))
 S SIG=SIG_"|loc="_+$G(REQ("LOCATION"))
 S DOM="" F  S DOM=$O(REQ("DOMAIN",DOM)) Q:DOM=""  S SIG=SIG_"|dom:"_DOM_"="_$G(REQ("DOMAIN",DOM))
 S KEY="c"_$$HASH(SIG)
 Q KEY
 ;
HASH(X) ; $$ - small deterministic checksum safe for M subscripts
 N H,I
 S H=0
 F I=1:1:$L($G(X)) S H=((H*33)+$A(X,I))#2147483647
 Q H
 ;
NOW() ; $$ - current FileMan date/time if available
 I $T(NOW^XLFDT)'="" Q $$NOW^XLFDT
 Q $H
 ;
INDEX(ROOT,IEN,CID) ; Index cached Bundle entries with FHIR search predicates
 N CROOT,ENTRY,IDX,RES,SUB,TYPE
 S CROOT=$NA(@ROOT@(IEN,"cache",CID))
 K @CROOT@("SPO"),@CROOT@("POS"),@CROOT@("PSO"),@CROOT@("OPS"),@CROOT@("type"),@CROOT@("alias")
 S IDX=0
 F  S IDX=$O(@CROOT@("bundle","entry",IDX)) Q:+IDX<1  D
 . S ENTRY=$NA(@CROOT@("bundle","entry",IDX))
 . S RES=$NA(@ENTRY@("resource"))
 . S TYPE=$G(@RES@("resourceType")) Q:TYPE=""
 . I $G(@RES@("id"))'="",$G(@ENTRY@("fullUrl"))'="" S @CROOT@("alias",$G(@ENTRY@("fullUrl")))=TYPE_"/"_$G(@RES@("id"))
 S IDX=0
 F  S IDX=$O(@CROOT@("bundle","entry",IDX)) Q:+IDX<1  D
 . S ENTRY=$NA(@CROOT@("bundle","entry",IDX))
 . S RES=$NA(@ENTRY@("resource"))
 . S TYPE=$G(@RES@("resourceType")) Q:TYPE=""
 . S SUB=$$SUBJ(RES,ENTRY,TYPE,IDX)
 . S @CROOT@("type",TYPE,IDX)=""
 . D SET(CROOT,SUB,"type",TYPE)
 . D SET(CROOT,SUB,"entry",IDX)
 . D SET(CROOT,SUB,"_id",$G(@RES@("id")))
 . D COMMON(CROOT,SUB,RES,TYPE)
 Q
 ;
SUBJ(RES,ENTRY,TYPE,IDX) ; $$ - stable resource subject
 N ID,FULL
 S ID=$G(@RES@("id"))
 I ID'="" Q TYPE_"/"_ID
 S FULL=$G(@ENTRY@("fullUrl"))
 I FULL'="" Q FULL
 Q TYPE_"/entry-"_IDX
 ;
COMMON(CROOT,SUB,RES,TYPE) ; Add common and resource-specific search facts
 N I
 D PROFILE(CROOT,SUB,RES)
 D IDENT(CROOT,SUB,RES)
 I TYPE="Patient" D PAT(CROOT,SUB,RES) Q
 D REF(CROOT,SUB,"patient",$G(@RES@("patient","reference")))
 D REF(CROOT,SUB,"patient",$G(@RES@("subject","reference")))
 D REF(CROOT,SUB,"subject",$G(@RES@("subject","reference")))
 I TYPE="Provenance" D PROV(CROOT,SUB,RES)
 D REF(CROOT,SUB,"encounter",$G(@RES@("encounter","reference")))
 D REF(CROOT,SUB,"encounter",$G(@RES@("context","reference")))
 D CODEABLE(CROOT,SUB,"code",$NA(@RES@("code")))
 D CODEABLE(CROOT,SUB,"category",$NA(@RES@("category")))
 D CODEABLE(CROOT,SUB,"clinical-status",$NA(@RES@("clinicalStatus")))
 D CODEABLE(CROOT,SUB,"status",$NA(@RES@("status")))
 I $G(@RES@("status"))'="" D SET(CROOT,SUB,"status",$G(@RES@("status")))
 I $G(@RES@("intent"))'="" D SET(CROOT,SUB,"intent",$G(@RES@("intent")))
 D BOOL(CROOT,SUB,"do-not-perform",$$DONOT(RES))
 D DATE(CROOT,SUB,"date",$G(@RES@("effectiveDateTime")))
 D DATE(CROOT,SUB,"date",$G(@RES@("issued")))
 D DATE(CROOT,SUB,"date",$G(@RES@("onsetDateTime")))
 D DATE(CROOT,SUB,"date",$G(@RES@("period","start")))
 D DATE(CROOT,SUB,"date",$G(@RES@("period","end")))
 D DATE(CROOT,SUB,"recorded-date",$G(@RES@("recordedDate")))
 D DATE(CROOT,SUB,"authored",$G(@RES@("authoredOn")))
 Q
 ;
PROV(CROOT,SUB,RES) ; Provenance target search parameter
 N I
 S I=0 F  S I=$O(@RES@("target",I)) Q:+I<1  D REF(CROOT,SUB,"target",$G(@RES@("target",I,"reference")))
 Q
 ;
PAT(CROOT,SUB,RES) ; Patient search parameters
 N I,NAME
 D SET(CROOT,SUB,"gender",$G(@RES@("gender")))
 D DATE(CROOT,SUB,"birthdate",$G(@RES@("birthDate")))
 S I=0 F  S I=$O(@RES@("name",I)) Q:+I<1  D
 . S NAME=$NA(@RES@("name",I))
 . D STR(CROOT,SUB,"name",$G(@NAME@("text")))
 . D STR(CROOT,SUB,"family",$G(@NAME@("family")))
 . D STR(CROOT,SUB,"name",$G(@NAME@("family")))
 . N G S G=0 F  S G=$O(@NAME@("given",G)) Q:+G<1  D
 . . D STR(CROOT,SUB,"given",$G(@NAME@("given",G)))
 . . D STR(CROOT,SUB,"name",$G(@NAME@("given",G)))
 Q
 ;
PROFILE(CROOT,SUB,RES) ; meta.profile
 N I
 S I=0 F  S I=$O(@RES@("meta","profile",I)) Q:+I<1  D SET(CROOT,SUB,"_profile",$G(@RES@("meta","profile",I)))
 Q
 ;
IDENT(CROOT,SUB,RES) ; identifier token values
 N CODE,I,SYS,VAL
 S I=0 F  S I=$O(@RES@("identifier",I)) Q:+I<1  D
 . S SYS=$G(@RES@("identifier",I,"system")),VAL=$G(@RES@("identifier",I,"value"))
 . I VAL="" Q
 . D SET(CROOT,SUB,"identifier",VAL)
 . I SYS'="" D SET(CROOT,SUB,"identifier",SYS_"|"_VAL)
 Q
 ;
DONOT(RES) ; $$ - doNotPerform token, inferred for USQC not-requested fixtures
 N I,ID,PROF,X
 SET X=$G(@RES@("doNotPerform")) IF X'="" QUIT X
 SET ID=$$UP($G(@RES@("id")))
 IF ID["NOTREQUESTED"!(ID["NOTDONE")!(ID["DECLINED") QUIT "true"
 SET I=0
 FOR  SET I=$O(@RES@("meta","profile",I)) Q:+I<1  DO  Q:$GET(X)'=""
 . SET PROF=$$UP($G(@RES@("meta","profile",I)))
 . IF PROF["NOTREQUESTED"!(PROF["NOTDONE")!(PROF["DECLINED") SET X="true"
 IF X'="" QUIT X
 IF ID["DEVICEREQUEST"!(ID["SERVICEREQUEST")!(ID["MEDICATIONREQUEST") QUIT "false"
 QUIT ""
 ;
BOOL(CROOT,SUB,PRED,VAL) ; Boolean token aliases
 SET VAL=$GET(VAL) QUIT:VAL=""
 IF VAL="True"!(VAL="TRUE") SET VAL="true"
 IF VAL="False"!(VAL="FALSE") SET VAL="false"
 D SET(CROOT,SUB,PRED,VAL)
 QUIT
 ;
CODEABLE(CROOT,SUB,PRED,NODE) ; CodeableConcept token extraction
 N CODE,I,SYS,TXT
 I '$D(@NODE@("coding")),$D(@NODE) DO  Q
 . S I=0 F  S I=$O(@NODE@(I)) Q:+I<1  D CODEABLE(CROOT,SUB,PRED,$NA(@NODE@(I)))
 S TXT=$G(@NODE@("text")) I TXT'="" D STR(CROOT,SUB,PRED,TXT)
 S I=0 F  S I=$O(@NODE@("coding",I)) Q:+I<1  D
 . S SYS=$G(@NODE@("coding",I,"system")),CODE=$G(@NODE@("coding",I,"code"))
 . I CODE="" Q
 . D SET(CROOT,SUB,PRED,CODE)
 . I SYS'="" D SET(CROOT,SUB,PRED,SYS_"|"_CODE)
 Q
 ;
REF(CROOT,SUB,PRED,VAL) ; Reference search aliases
 S VAL=$G(VAL) Q:VAL=""
 D SET(CROOT,SUB,PRED,VAL)
 I $G(@CROOT@("alias",VAL))'="" D SET(CROOT,SUB,PRED,$G(@CROOT@("alias",VAL)))
 I VAL["Patient/" D SET(CROOT,SUB,PRED,$P(VAL,"Patient/",2))
 I VAL["Encounter/" D SET(CROOT,SUB,PRED,$P(VAL,"Encounter/",2))
 Q
 ;
DATE(CROOT,SUB,PRED,VAL) ; Date search value
 S VAL=$G(VAL) Q:VAL=""
 D SET(CROOT,SUB,PRED,$P(VAL,"T",1))
 D SET(CROOT,SUB,PRED,VAL)
 Q
 ;
STR(CROOT,SUB,PRED,VAL) ; String search value
 S VAL=$$TRIM($G(VAL)) Q:VAL=""
 D SET(CROOT,SUB,PRED,$$UP(VAL))
 Q
 ;
SET(CROOT,SUB,PRED,OBJ) ; Set one cached search triple
 D SETIDXGN^C0FWFUTL(CROOT,$G(SUB),$G(PRED),$G(OBJ))
 Q
 ;
WS(OUT,FILTER) ; REST-style /fhir/{resource}[/{id}] search/read endpoint
 N ERR,IDARG,JERR,PATH,RESARG,TMP
 I $D(HTTPARGS) M FILTER=HTTPARGS
 S PATH=$G(HTTPREQ("path"))
 I $EXTRACT(PATH)="/" SET PATH=$EXTRACT(PATH,2,$LENGTH(PATH))
 ; Prefer path segments so fhir/{resource} still reads fhir/Type/id.
 I $PIECE(PATH,"/",1)="fhir",$PIECE(PATH,"/",2)'="" DO
 . S RESARG=$PIECE(PATH,"/",2)
 . S IDARG=$PIECE(PATH,"/",3)
 E  DO
 . S RESARG=$S($D(FILTER("resource")):$G(FILTER("resource")),$D(FILTER)#2:$G(FILTER),1:"")
 . S IDARG=$G(FILTER("id"))
 I RESARG["/" S IDARG=$PIECE(RESARG,"/",2),RESARG=$PIECE(RESARG,"/",1)
 I RESARG'="" S FILTER("resource")=RESARG
 I IDARG'="" S FILTER("id")=IDARG
 I IDARG'="" D READ(.FILTER,.TMP,.ERR)
 E  D SEARCH(.FILTER,.TMP,.ERR)
 I $G(ERR)'="" D OO(ERR,.TMP)
 D TOJSON^C0FHIRBU(.TMP,.OUT,.JERR)
 S HTTPRSP("mime")="application/fhir+json"
 Q
 ;
WSREAD(OUT,FILTER,ID) ; GET /fhir/{resource}/{id} wrapper
 N ERR,IDARG,JERR,PATH,RESARG,TMP
 I $D(HTTPARGS) M FILTER=HTTPARGS
 S PATH=$G(HTTPREQ("path"))
 I $EXTRACT(PATH)="/" SET PATH=$EXTRACT(PATH,2,$LENGTH(PATH))
 S RESARG=$PIECE(PATH,"/",2),IDARG=$PIECE(PATH,"/",3)
 I RESARG="" S RESARG=$G(FILTER("resource"))
 I IDARG="" S IDARG=$G(FILTER("id"))
 I IDARG="",$G(ID)'="" S IDARG=ID
 S FILTER("resource")=RESARG
 S FILTER("id")=IDARG
 D READ(.FILTER,.TMP,.ERR)
 I $G(ERR)'="" D OO(ERR,.TMP)
 D TOJSON^C0FHIRBU(.TMP,.OUT,.JERR)
 S HTTPRSP("mime")="application/fhir+json"
 Q
 ;
WSPOST(ARGS,BODY,RESULT) ; POST /fhir/{resource}/_search form search wrapper
 I '$DATA(RESULT) DO  QUIT ""
 . NEW EMPTY
 . DO WSPOST2(.ARGS,.EMPTY,.BODY)
 DO WSPOST2(.RESULT,.ARGS,.BODY)
 QUIT ""
 ;
WSPOST2(OUT,ARGS,BODY) ; Core POST search handler
 N ERR,FILTER,JERR,PATH,RESARG,TMP
 K OUT,FILTER
 I $DATA(HTTPARGS) MERGE FILTER=HTTPARGS
 I $DATA(ARGS) MERGE FILTER=ARGS
 DO FORMBODY(.FILTER,.BODY)
 S PATH=$G(HTTPREQ("path"))
 I $EXTRACT(PATH)="/" SET PATH=$EXTRACT(PATH,2,$LENGTH(PATH))
 S RESARG=$PIECE(PATH,"/",2)
 IF RESARG="" S RESARG=$G(FILTER("resource"))
 IF RESARG["/" S RESARG=$PIECE(RESARG,"/",1)
 S FILTER("resource")=RESARG
 DO SEARCH(.FILTER,.TMP,.ERR)
 IF $G(ERR)'="" D OO(ERR,.TMP)
 D TOJSON^C0FHIRBU(.TMP,.OUT,.JERR)
 S HTTPRSP("mime")="application/fhir+json"
 QUIT
 ;
FORMBODY(FILTER,BODY) ; Merge application/x-www-form-urlencoded body into FILTER
 N RAW
 SET RAW=$$BODYTXT(.BODY)
 IF RAW="" QUIT
 DO FORMDECODE(.FILTER,RAW)
 QUIT
 ;
BODYTXT(BODY) ; $$ - flatten %web POST body array/string
 N I,RAW
 SET RAW=""
 IF $DATA(BODY)#2 SET RAW=$GET(BODY)
 SET I=0
 FOR  SET I=$ORDER(BODY(I)) QUIT:I=""  SET RAW=RAW_$GET(BODY(I))
 QUIT RAW
 ;
FORMDECODE(FILTER,RAW) ; Parse k=v&k2=v2 pairs
 N K,PAIR,V
 FOR  QUIT:RAW=""  DO
 . SET PAIR=$PIECE(RAW,"&",1),RAW=$PIECE(RAW,"&",2,999)
 . IF PAIR="" QUIT
 . SET K=$$URLDEC($PIECE(PAIR,"=",1)),V=$$URLDEC($PIECE(PAIR,"=",2,999))
 . IF K'="" SET FILTER(K)=V
 QUIT
 ;
URLDEC(X) ; $$ - decode minimal URL-encoded form value
 N H,I,N,Y
 SET X=$TRANSLATE($GET(X),"+"," "),Y="",I=1
 FOR  QUIT:I>$LENGTH(X)  DO
 . IF $EXTRACT(X,I)'="%" SET Y=Y_$EXTRACT(X,I),I=I+1 QUIT
 . SET H=$EXTRACT(X,I+1,I+2)
 . IF H'?2AN SET Y=Y_"%",I=I+1 QUIT
 . SET N=$$HEX(H)
 . IF N<0 SET Y=Y_"%",I=I+1 QUIT
 . SET Y=Y_$CHAR(N),I=I+3
 QUIT Y
 ;
HEX(H) ; $$ - two hex characters to decimal, -1 if invalid
 N A,B
 SET A=$$HEXDIG($EXTRACT($GET(H),1)),B=$$HEXDIG($EXTRACT($GET(H),2))
 IF A<0!(B<0) QUIT -1
 QUIT (A*16)+B
 ;
HEXDIG(C) ; $$ - one hex digit to decimal
 SET C=$$UP($GET(C))
 IF C?1N QUIT +C
 IF C="A" QUIT 10
 IF C="B" QUIT 11
 IF C="C" QUIT 12
 IF C="D" QUIT 13
 IF C="E" QUIT 14
 IF C="F" QUIT 15
 QUIT -1
 ;
READ(FILTER,OUT,ERR) ; Read one cached resource by resource type/id
 N BESTC,BESTIEN,BESTT,C,ENTRY,IEN,RES,ROOT,SUB,T
 K OUT,ERR
 S RES=$$RESTYPE($G(FILTER("resource")))
 I RES="" S ERR="Missing or unsupported FHIR resource type" Q
 S SUB=RES_"/"_$G(FILTER("id"))
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" S ERR="FHIR graph root is unavailable" Q
 ; Prefer the newest cache row when the same id exists in multiple CIDs
 ; (stale pre-fix bundles otherwise win on $ORDER order).
 S (BESTC,BESTIEN,BESTT)=""
 S IEN=0 F  S IEN=$O(@ROOT@(IEN)) Q:+IEN<1  D
 . S C="" F  S C=$O(@ROOT@(IEN,"cache",C)) Q:C=""  D
 . . S ENTRY=+$O(@ROOT@(IEN,"cache",C,"SPO",SUB,"entry","")) Q:ENTRY<1
 . . S T=+$G(@ROOT@(IEN,"cache",C,"meta","createdAt"))
 . . I BESTIEN=""!(T'<BESTT) S BESTIEN=IEN,BESTC=C,BESTT=T
 I BESTIEN'="" D
 . S ENTRY=+$O(@ROOT@(BESTIEN,"cache",BESTC,"SPO",SUB,"entry",""))
 . M OUT=@ROOT@(BESTIEN,"cache",BESTC,"bundle","entry",ENTRY,"resource")
 I '$D(OUT) S ERR=RES_"/"_$G(FILTER("id"))_" not found in cache"
 Q
 ;
SEARCH(FILTER,OUT,ERR) ; Build searchset Bundle from cache indexes
 N CROOT,CID,DFN,IEN,REQ,RES,ROOT,SAVEIEN,SAVEROOT
 K OUT,ERR
 S RES=$$RESTYPE($G(FILTER("resource")))
 I RES="" S ERR="Missing or unsupported FHIR resource type" Q
 I $G(FILTER("id"))'="" S FILTER("_id")=$G(FILTER("id"))
 S DFN=$$REQDFN(.FILTER,RES)
 I DFN<1 S ERR="FHIR cache search requires a patient id, _id, patient, or subject parameter" Q
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" S ERR="FHIR graph root is unavailable" Q
 S IEN=$$DFN2IEN^C0FWFUTL(DFN)
 I IEN<1 S ERR="Patient graph row not found" Q
 S REQ("DFN")=DFN,REQ("MODE")="DATERANGE",REQ("MAX")=$S(+$G(FILTER("_count"))>0:+$G(FILTER("_count")),1:200)
 S REQ("DOMAIN","ALL")=1
 I +$G(FILTER("refresh")) S REQ("REFRESH")=1
 S SAVEIEN=IEN,SAVEROOT=ROOT
 D GET(.REQ,.OUT)
 S IEN=SAVEIEN,ROOT=SAVEROOT
 S CID=$$CID(.REQ),CROOT=$NA(@ROOT@(IEN,"cache",CID))
 D FINDS(.FILTER,CROOT,RES,.OUT)
 Q
 ;
FINDS(FILTER,CROOT,RES,OUT) ; Evaluate indexed search params and rebuild a Bundle
 N CAND,IDX,LIMIT,MATCH,SUB
 K CAND,MATCH
 S SUB="" F  S SUB=$O(@CROOT@("POS","type",RES,SUB)) Q:SUB=""  S CAND(SUB)=""
 D APPLY(.CAND,CROOT,"_id",$G(FILTER("_id")),"TOKEN")
 D APPLY(.CAND,CROOT,"identifier",$G(FILTER("identifier")),"TOKEN")
 D APPLY(.CAND,CROOT,"patient",$G(FILTER("patient")),"REF")
 D APPLY(.CAND,CROOT,"subject",$G(FILTER("subject")),"REF")
 D APPLY(.CAND,CROOT,"target",$G(FILTER("target")),"REF")
 D APPLY(.CAND,CROOT,"encounter",$G(FILTER("encounter")),"REF")
 D APPLY(.CAND,CROOT,"code",$G(FILTER("code")),"TOKEN")
 D APPLY(.CAND,CROOT,"status",$G(FILTER("status")),"TOKEN")
 D APPLY(.CAND,CROOT,"intent",$G(FILTER("intent")),"TOKEN")
 D APPLY(.CAND,CROOT,"do-not-perform",$G(FILTER("do-not-perform")),"TOKEN")
 D APPLY(.CAND,CROOT,"clinical-status",$G(FILTER("clinical-status")),"TOKEN")
 D APPLY(.CAND,CROOT,"category",$G(FILTER("category")),"TOKEN")
 D APPLY(.CAND,CROOT,"gender",$G(FILTER("gender")),"TOKEN")
 D APPLY(.CAND,CROOT,"birthdate",$G(FILTER("birthdate")),"DATE")
 D APPLY(.CAND,CROOT,"date",$G(FILTER("date")),"DATE")
 D APPLY(.CAND,CROOT,"recorded-date",$G(FILTER("recorded-date")),"DATE")
 D APPLY(.CAND,CROOT,"authored",$G(FILTER("authored")),"DATE")
 D APPLY(.CAND,CROOT,"name",$G(FILTER("name")),"STRING")
 D APPLY(.CAND,CROOT,"family",$G(FILTER("family")),"STRING")
 D APPLY(.CAND,CROOT,"given",$G(FILTER("given")),"STRING")
 D INITSRCH(.MATCH)
 S LIMIT=+$G(FILTER("_count")) I LIMIT<1 S LIMIT=200
 S SUB="",IDX=0 F  S SUB=$O(CAND(SUB)) Q:SUB=""!(IDX'<LIMIT)  D
 . N ENTRY S ENTRY=+$O(@CROOT@("SPO",SUB,"entry","")) Q:ENTRY<1
 . S IDX=IDX+1
 . M MATCH("entry",IDX)=@CROOT@("bundle","entry",ENTRY)
 S MATCH("total")=IDX
 D REVINC(.FILTER,CROOT,.MATCH,.CAND)
 K OUT
 M OUT=MATCH
 D FINAL^C0FHIRBU(.OUT)
 Q
 ;
REVINC(FILTER,CROOT,MATCH,CAND) ; Include Provenance resources matching _revinclude=Provenance:target
 N ENTRY,INC,PCAND,PROV,SUB
 SET INC=$GET(FILTER("_revinclude")) QUIT:INC=""
 IF INC'["Provenance:target" QUIT
 SET PROV="" F  SET PROV=$O(@CROOT@("POS","type","Provenance",PROV)) Q:PROV=""  DO
 . SET SUB="" F  SET SUB=$O(CAND(SUB)) Q:SUB=""  DO  Q:$DATA(PCAND(PROV))
 . . IF $DATA(@CROOT@("SPO",PROV,"target",SUB)) SET PCAND(PROV)=""
 S PROV="" F  SET PROV=$O(PCAND(PROV)) Q:PROV=""  DO
 . SET ENTRY=+$O(@CROOT@("SPO",PROV,"entry","")) Q:ENTRY<1
 . MERGE MATCH("entry",$O(MATCH("entry",""),-1)+1)=@CROOT@("bundle","entry",ENTRY)
 Q
 ;
INITSRCH(OUT) ; Initialize searchset Bundle
 K OUT
 S OUT("resourceType")="Bundle"
 S OUT("type")="searchset"
 S OUT("total")=0
 Q
 ;
APPLY(CAND,CROOT,PRED,VAL,TYPE) ; Intersect candidates with one search parameter
 N KEEP,SUB
 S VAL=$G(VAL) Q:VAL=""
 K KEEP
 I TYPE="DATE" D DATESET(CROOT,PRED,VAL,.KEEP)
 E  I TYPE="STRING" D STRSET(CROOT,PRED,VAL,.KEEP)
 E  D TOKSET(CROOT,PRED,VAL,.KEEP)
 S SUB="" F  S SUB=$O(CAND(SUB)) Q:SUB=""  I '$D(KEEP(SUB)) K CAND(SUB)
 Q
 ;
TOKSET(CROOT,PRED,VAL,KEEP) ; Exact token/reference match, comma means OR
 N TOK
 F  Q:VAL=""  D
 . S TOK=$P(VAL,",",1),VAL=$P(VAL,",",2,999)
 . D ADDKEEP(CROOT,PRED,TOK,.KEEP)
 . I TOK'["/" D ADDKEEP(CROOT,PRED,"Patient/"_TOK,.KEEP)
 . I TOK'["/" D ADDKEEP(CROOT,PRED,"Encounter/"_TOK,.KEEP)
 . I TOK["Patient/" D ADDKEEP(CROOT,PRED,$P(TOK,"Patient/",2),.KEEP)
 . I TOK["Encounter/" D ADDKEEP(CROOT,PRED,$P(TOK,"Encounter/",2),.KEEP)
 Q
 ;
DATESET(CROOT,PRED,VAL,KEEP) ; Date exact/range match
 N OP,SUB,V
 S OP=$E(VAL,1,2)
 I OP'="eq",OP'="ne",OP'="lt",OP'="le",OP'="gt",OP'="ge",OP'="sa",OP'="eb",OP'="ap" S OP="eq"
 I OP'="eq" S VAL=$E(VAL,3,$L(VAL))
 S V="" F  S V=$O(@CROOT@("POS",PRED,V)) Q:V=""  I $$DATEOK(V,OP,VAL) D
 . S SUB="" F  S SUB=$O(@CROOT@("POS",PRED,V,SUB)) Q:SUB=""  S KEEP(SUB)=""
 Q
 ;
STRSET(CROOT,PRED,VAL,KEEP) ; Case-insensitive prefix string match
 N KEY,SUB,UVAL
 S UVAL=$$UP($$TRIM(VAL))
 S KEY="" F  S KEY=$O(@CROOT@("POS",PRED,KEY)) Q:KEY=""  I $E(KEY,1,$L(UVAL))=UVAL D
 . S SUB="" F  S SUB=$O(@CROOT@("POS",PRED,KEY,SUB)) Q:SUB=""  S KEEP(SUB)=""
 Q
 ;
ADDKEEP(CROOT,PRED,OBJ,KEEP) ; Add exact POS hits
 N SUB
 S OBJ=$G(OBJ) Q:OBJ=""
 S SUB="" F  S SUB=$O(@CROOT@("POS",PRED,OBJ,SUB)) Q:SUB=""  S KEEP(SUB)=""
 Q
 ;
DATEOK(HAVE,OP,WANT) ; $$ - compare FHIR date/dateTime at WANT precision
 ; Day-only WANT (YYYY-MM-DD) compares calendar days. DateTime WANT keeps
 ; second precision so ge/gt/le/lt do not return earlier same-day instants
 ; (Inferno DiagnosticReport patient+category+date).
 N H,W
 I $G(WANT)["T",$G(HAVE)'["T" Q 0
 S W=$$DKEY($G(WANT)),H=$$DKEY($G(HAVE),$L(W))
 I H=""!(W="") Q 0
 I OP="eq" Q H=W
 I OP="ge" Q H'<W
 I OP="gt" Q H>W
 I OP="le" Q H'>W
 I OP="lt" Q H<W
 Q HAVE=WANT
 ;
DKEY(X,MAX) ; $$ - sortable YYYYMMDD[HHMMSS] clipped to MAX digits (default full)
 N D,T,KEY
 S X=$G(X),MAX=+$G(MAX)
 S D=$P(X,"T",1),T=$P($P(X,"T",2),"Z",1),T=$P(T,"+",1),T=$P(T,"-",1)
 I D?4N1"-"2N1"-"2N S KEY=$TR(D,"-")
 E  I D?4N1"-"2N S KEY=$TR(D,"-")_"01"
 E  I D?4N S KEY=D_"0101"
 E  Q ""
 I T'="" S KEY=KEY_$TR($E(T_"00:00:00",1,8),":")
 I MAX>0,$L(KEY)>MAX S KEY=$E(KEY,1,MAX)
 Q KEY
 ;
DNUM(X) ; $$ - ISO date/dateTime prefix as sortable YYYYMMDD number
 Q +$$DKEY($G(X),8)
 ;
REQDFN(FILTER,RES) ; $$ - patient id for patient-scoped cache
 N RID,X
 I RES="Patient" D  Q +X
 . S X=$G(FILTER("_id")) I X="" S X=$G(FILTER("id"))
 . I X="" S X=$G(FILTER("patient"))
 . I X["Patient/" S X=$P(X,"Patient/",2)
 S X=$G(FILTER("patient")) I X="" S X=$G(FILTER("subject"))
 I X="" S X=$G(FILTER("dfn"))
 I X["Patient/" S X=$P(X,"Patient/",2)
 I +X>0 Q +X
 ; Encounter?_id=E123 (and similar) has no patient param - resolve from cache.
 S RID=$G(FILTER("_id")) I RID="" S RID=$G(FILTER("id"))
 I RID'="" Q $$DFNBYID(RES,RID)
 Q 0
 ;
DFNBYID(RES,RID) ; $$ - DFN owning cached RES/RID via subject/patient
 N C,ENTRY,IEN,PAT,ROOT,SUB
 S RES=$G(RES),RID=$G(RID) Q:RES=""!(RID="") 0
 S SUB=RES_"/"_RID
 S ROOT=$$ROOT^C0FWGRT("fhir-intake") Q:ROOT="" 0
 S IEN=0,PAT=0
 F  S IEN=$O(@ROOT@(IEN)) Q:+IEN<1!(PAT>0)  D
 . S C="" F  S C=$O(@ROOT@(IEN,"cache",C)) Q:C=""!(PAT>0)  D
 . . S ENTRY=+$O(@ROOT@(IEN,"cache",C,"SPO",SUB,"entry","")) Q:ENTRY<1
 . . S PAT=$$PATOF($NA(@ROOT@(IEN,"cache",C,"bundle","entry",ENTRY,"resource")))
 Q +PAT
 ;
PATOF(RES) ; $$ - Patient id from resource subject/patient reference
 N X
 S X=$G(@RES@("subject","reference"))
 I X="" S X=$G(@RES@("patient","reference"))
 I X["Patient/" Q +$P(X,"Patient/",2)
 I X?1.N Q +X
 Q 0
 ;
RESTYPE(X) ; $$ - normalize supported resource type
 S X=$$UP($G(X))
 I X="PATIENT" Q "Patient"
 I X="OBSERVATION" Q "Observation"
 I X="CONDITION" Q "Condition"
 I X="DIAGNOSTICREPORT" Q "DiagnosticReport"
 I X="ORGANIZATION" Q "Organization"
 I X="LOCATION" Q "Location"
 I X="PRACTITIONER" Q "Practitioner"
 I X="ENCOUNTER" Q "Encounter"
 I X="ALLERGYINTOLERANCE" Q "AllergyIntolerance"
 I X="IMMUNIZATION" Q "Immunization"
 I X="PROCEDURE" Q "Procedure"
 I X="MEDICATIONREQUEST" Q "MedicationRequest"
 I X="MEDICATION" Q "Medication"
 I X="DOCUMENTREFERENCE" Q "DocumentReference"
 I X="PROVENANCE" Q "Provenance"
 I X="ADVERSEEVENT" Q "AdverseEvent"
 I X="CAREPLAN" Q "CarePlan"
 I X="CARETEAM" Q "CareTeam"
 I X="COVERAGE" Q "Coverage"
 I X="DEVICE" Q "Device"
 I X="DEVICEREQUEST" Q "DeviceRequest"
 I X="FAMILYMEMBERHISTORY" Q "FamilyMemberHistory"
 I X="GOAL" Q "Goal"
 I X="MEDICATIONADMINISTRATION" Q "MedicationAdministration"
 I X="MEDICATIONDISPENSE" Q "MedicationDispense"
 I X="QUESTIONNAIRERESPONSE" Q "QuestionnaireResponse"
 I X="RELATEDPERSON" Q "RelatedPerson"
 I X="SERVICEREQUEST" Q "ServiceRequest"
 I X="TASK" Q "Task"
 I X="PRACTITIONERROLE" Q "PractitionerRole"
 I X="SPECIMEN" Q "Specimen"
 Q ""
 ;
OO(MSG,OUT) ; OperationOutcome
 K OUT
 S OUT("resourceType")="OperationOutcome"
 S OUT("issue",1,"severity")="error"
 S OUT("issue",1,"code")="processing"
 S OUT("issue",1,"diagnostics")=$G(MSG)
 D FINAL^C0FHIRBU(.OUT)
 Q
 ;
UP(X) ; Uppercase helper
 N C,I,Y
 S Y=""
 F I=1:1:$L($G(X)) S C=$E(X,I),Y=Y_$S(C?1L:$C($A(C)-32),1:C)
 Q Y
 ;
TRIM(X) ; Trim spaces
 N Y
 S Y=$G(X)
 F  Q:$E(Y,1)'=" "  S Y=$E(Y,2,$L(Y))
 F  Q:$E(Y,$L(Y))'=" "  S Y=$E(Y,1,$L(Y)-1)
 Q Y
 ;
