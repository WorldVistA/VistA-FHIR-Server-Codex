C0FHIRP ; VAMC/JS - Procedure builders
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETPROC(RTN,DFN,BEG,END,MAX) ; Add Procedure resources
 NEW CNT
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 SET CNT=0
 DO GETSR(.RTN,DFN,BEG,END,MAX,.CNT)
 IF CNT'<MAX QUIT
 DO GETRA(.RTN,DFN,BEG,END,MAX,.CNT)
 IF CNT'<MAX QUIT
 DO GETCP(.RTN,DFN,BEG,END,MAX,.CNT)
 IF CNT'<MAX QUIT
 DO GETCPT(.RTN,DFN,BEG,END,MAX,.CNT)
 QUIT
 ;
GETSR(RTN,DFN,BEG,END,MAX,CNT) ; Add surgery procedures
 NEW NUM,ROOT,SHOWADD,SURG,VPRY
 IF CNT'<MAX QUIT
 SET SHOWADD=1
 DO LIST^SROESTV(.ROOT,DFN,BEG,END,MAX,1)
 SET VPRY=$GET(ROOT)
 IF VPRY="" QUIT
 SET NUM=0
 FOR  SET NUM=$ORDER(@VPRY@(NUM)) Q:NUM<1!(CNT'<MAX)  DO
 . KILL SURG
 . DO ONE^VPRDSR(NUM,.SURG)
 . IF '$DATA(SURG) QUIT
 . DO SETPROC(.RTN,.SURG,DFN,"SR")
 . SET CNT=CNT+1
 KILL @VPRY
 KILL ^TMP("VPRTEXT",$J)
 QUIT
 ;
GETRA(RTN,DFN,BEG,END,MAX,CNT) ; Add radiology procedures
 NEW EXAM,ID,RAQMAX
 IF CNT'<MAX QUIT
 SET RAQMAX=MAX-CNT
 IF RAQMAX<1 SET RAQMAX=1
 KILL ^TMP($J,"RAE1")
 DO EN1^RAO7PC1(DFN,BEG,END,RAQMAX)
 SET ID=""
 FOR  SET ID=$ORDER(^TMP($J,"RAE1",DFN,ID)) Q:ID=""!(CNT'<MAX)  DO
 . KILL EXAM
 . DO EN1^VPRDRA(ID,.EXAM)
 . IF '$DATA(EXAM) QUIT
 . DO SETPROC(.RTN,.EXAM,DFN,"RA")
 . SET CNT=CNT+1
 KILL ^TMP($J,"RAE1")
 KILL ^TMP($J,"RAE2",DFN)
 KILL ^TMP($J,"RAE3",DFN)
 KILL ^TMP("VPRTEXT",$J)
 QUIT
 ;
GETCPT(RTN,DFN,BEG,END,MAX,CNT) ; Add V CPT procedures
 NEW CPT,DA,DATE,IDT,ITEM,REC,VPRF
 IF CNT'<MAX QUIT
 KILL ^TMP("C0FHIRP",$J,"CPT")
 SET ITEM=0
 FOR  SET ITEM=$ORDER(^PXRMINDX(9000010.18,"PI",DFN,ITEM)) Q:ITEM<1!(CNT'<MAX)  DO
 . SET DATE=0
 . FOR  SET DATE=$ORDER(^PXRMINDX(9000010.18,"PI",DFN,ITEM,DATE)) Q:DATE<1!(CNT'<MAX)  DO
 .. IF DATE<BEG!(DATE>END) QUIT
 .. SET IDT=9999999-DATE
 .. SET DA=0
 .. FOR  SET DA=$ORDER(^PXRMINDX(9000010.18,"PI",DFN,ITEM,DATE,DA)) Q:DA<1!(CNT'<MAX)  DO
 ... SET ^TMP("C0FHIRP",$J,"CPT",IDT,DA)=ITEM_"^"_DATE
 SET IDT=0
 FOR  SET IDT=$ORDER(^TMP("C0FHIRP",$J,"CPT",IDT)) Q:IDT<1!(CNT'<MAX)  DO
 . SET DA=0
 . FOR  SET DA=$ORDER(^TMP("C0FHIRP",$J,"CPT",IDT,DA)) Q:DA<1!(CNT'<MAX)  DO
 .. SET REC=$GET(^TMP("C0FHIRP",$J,"CPT",IDT,DA))
 .. IF REC="" QUIT
 .. SET ITEM=+REC
 .. SET DATE=+$PIECE(REC,"^",2)
 .. KILL CPT,VPRF
 .. DO VCPT^PXPXRM(DA,.VPRF)
 .. SET CPT("id")=DA
 .. SET CPT("dateTime")=DATE
 .. SET CPT("status")="COMPLETED"
 .. SET CPT("encounter")=+$GET(VPRF("VISIT"))
 .. SET CPT("type")=$$CPTCODE(ITEM)
 .. SET CPT("name")=$$CPTNAME(.VPRF,$GET(CPT("type")))
 .. SET CPT("provider")=$$PROV($GET(VPRF("PROVIDER")))
 .. IF $GET(CPT("provider"))="" SET CPT("provider")=$$PROV($GET(VPRF("ENCOUNTER PROVIDER")))
 .. DO SETPROC(.RTN,.CPT,DFN,"CPT")
 .. SET CNT=CNT+1
 KILL ^TMP("C0FHIRP",$J,"CPT")
 QUIT
 ;
GETCP(RTN,DFN,BEG,END,MAX,CNT) ; Add Clinical Procedure (Medicine) procedures
 NEW CP,DATE,RES,RNAME,RTN1,VPRN,VPRX
 IF CNT'<MAX QUIT
 IF '$LENGTH($TEXT(EN1^MDPS1)) QUIT
 KILL ^TMP("MDHSP",$J)
 SET RES=""
 DO EN1^MDPS1(RES,DFN,BEG,END,MAX,"",0)
 SET VPRN=0
 FOR  SET VPRN=$ORDER(^TMP("MDHSP",$J,VPRN)) Q:VPRN<1!(CNT'<MAX)  DO
 . SET VPRX=$GET(^TMP("MDHSP",$J,VPRN))
 . IF VPRX="" QUIT
 . SET RTN1=$PIECE(VPRX,"^",3,4)
 . IF RTN1="PRPRO^MDPS4" QUIT  ; Skip non-CP rows (matches VPRDMC behavior)
 . SET DATE=$$CPDATE($PIECE(VPRX,"^",6))
 . IF DATE<1 QUIT
 . KILL CP
 . SET CP("id")=+$PIECE(VPRX,"^",2)
 . IF CP("id")<1 QUIT
 . SET CP("name")=$PIECE(VPRX,"^")
 . SET CP("dateTime")=DATE
 . SET CP("status")="COMPLETE"
 . IF $PIECE(VPRX,"^",7)'="" SET CP("interpretation")=$PIECE(VPRX,"^",7)
 . DO SETPROC(.RTN,.CP,DFN,"CP")
 . SET CNT=CNT+1
 KILL ^TMP("MDHSP",$J)
 QUIT
 ;
SETPROC(RTN,PROC,DFN,SRC) ; Map one source procedure to a FHIR Procedure resource
 NEW CAT,CODE,CODEDISP,CODETXT,CODEVAL,DATE,ENC,ID,IDX,NAME,PROV,RID,STAT
 SET ID=$$PROCID($GET(PROC("id")))
 IF ID="" QUIT
 SET RID=SRC_"-"_ID
 DO ADDRES^C0FHIRBU(.RTN,"Procedure",RID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Procedure"
 SET RTN("entry",IDX,"resource","id")=RID
 SET STAT=$$PSTAT($GET(PROC("status")))
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 SET NAME=$GET(PROC("name"))
 SET CODE=$GET(PROC("type"))
 SET CODEVAL=$PIECE(CODE,"^")
 SET CODEDISP=$PIECE(CODE,"^",2)
 IF CODEVAL'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=CODEVAL
 . IF CODEDISP'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=CODEDISP
 IF NAME="" SET NAME=CODEDISP
 IF NAME'="" SET RTN("entry",IDX,"resource","code","text")=NAME
 SET DATE=+$GET(PROC("dateTime"))
 IF DATE>0 SET RTN("entry",IDX,"resource","performedDateTime")=$$FM2FHIR^C0FHIRBU(DATE)
 SET ENC=+$GET(PROC("encounter"))
 IF ENC>0 SET RTN("entry",IDX,"resource","encounter","reference")=$$REFURL^C0FHIRBU("Encounter","E"_ENC)
 SET PROV=$$PROV($GET(PROC("provider")))
 IF $PIECE(PROV,"^",2)'="" DO
 . SET RTN("entry",IDX,"resource","performer",1,"actor","display")=$PIECE(PROV,"^",2)
 . IF +$PIECE(PROV,"^")>0 DO
 .. SET RTN("entry",IDX,"resource","performer",1,"actor","identifier","system")="urn:va:user"
 .. SET RTN("entry",IDX,"resource","performer",1,"actor","identifier","value")=+$PIECE(PROV,"^")
 SET CAT=$$PCAT($GET(SRC))
 IF CAT'="" SET RTN("entry",IDX,"resource","category","text")=CAT
 SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:procedure-source-id"
 SET RTN("entry",IDX,"resource","identifier",1,"value")=$GET(SRC)_":"_$GET(PROC("id"))
 QUIT
 ;
PCAT(SRC) ; Map source token to procedure category text
 SET SRC=$$UPCASE^C0FHIR($GET(SRC))
 IF SRC="SR" QUIT "surgical procedure"
 IF SRC="RA" QUIT "radiology procedure"
 IF SRC="CP" QUIT "clinical procedure"
 IF SRC="CPT" QUIT "coded procedure"
 QUIT "procedure"
 ;
PSTAT(X) ; Map source status to FHIR Procedure.status
 NEW Y
 SET Y=$$UPCASE^C0FHIR($GET(X))
 IF Y["ABORT" QUIT "stopped"
 IF Y["PARTIAL" QUIT "in-progress"
 IF Y["COMPLETE" QUIT "completed"
 IF Y["FINAL" QUIT "completed"
 IF Y="" QUIT "completed"
 QUIT "unknown"
 ;
PROCID(X) ; Normalize procedure id to FHIR-safe id token
 NEW C,I,Y
 SET Y=""
 FOR I=1:1:$LENGTH($GET(X)) DO
 . SET C=$EXTRACT(X,I)
 . IF C?1AN SET Y=Y_C QUIT
 . IF C="-"!(C=".") SET Y=Y_C QUIT
 . SET Y=Y_"-"
 IF Y="" SET Y="unknown"
 IF $LENGTH(Y)>60 SET Y=$EXTRACT(Y,1,60)
 QUIT Y
 ;
PROV(X) ; Normalize provider token to ien^name
 NEW IEN,NAME
 SET X=$GET(X)
 IF X="" QUIT ""
 IF X["^" DO  QUIT $SELECT(IEN>0:IEN_"^"_NAME,NAME'="":"^"_NAME,1:X)
 . SET IEN=+$PIECE(X,"^")
 . SET NAME=$PIECE(X,"^",2)
 . IF NAME="",IEN>0 SET NAME=$PIECE($GET(^VA(200,IEN,0)),"^")
 SET IEN=+X
 IF IEN>0 DO  QUIT IEN_"^"_NAME
 . SET NAME=$PIECE($GET(^VA(200,IEN,0)),"^")
 QUIT "^"_X
 ;
CPTNAME(VPRF,CODE) ; Resolve V CPT display text
 NEW NAME,NARR
 SET NAME=""
 SET NARR=+$GET(VPRF("PROVIDER NARRATIVE"))
 IF NARR>0 SET NAME=$$EXTERNAL^DILFD(9000010.18,.04,,NARR)
 IF NAME="" SET NAME=$PIECE($GET(CODE),"^",2)
 QUIT NAME
 ;
CPTCODE(IEN) ; Return CPT code^display from CPT ien
 NEW I,N,VPRX,X,X0,Y
 SET IEN=+$GET(IEN)
 IF IEN<1 QUIT ""
 SET X0=$$CPT^ICPTCOD(IEN)
 IF X0<0 QUIT ""
 SET Y=$PIECE(X0,"^",2,3)
 SET N=$$CPTD^ICPTCOD($PIECE(Y,"^"),"VPRX")
 IF N>0,$LENGTH($GET(VPRX(1))) DO
 . SET X=$GET(VPRX(1))
 . SET I=1
 . FOR  SET I=$ORDER(VPRX(I)) Q:I<1  Q:VPRX(I)=" "  SET X=X_" "_VPRX(I)
 . SET $PIECE(Y,"^",2)=X
 QUIT Y
 ;
CPDATE(X) ; Parse CP date value to FileMan date/time
 NEW %DT,Y
 IF +$GET(X)>0 QUIT +X
 SET X=$GET(X)
 IF X="" QUIT 0
 SET %DT="STX"
 DO ^%DT
 IF Y>0 QUIT +Y
 QUIT 0
 ;
