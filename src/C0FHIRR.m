C0FHIRR ; VAMC/JS - Reminder DiagnosticReport builder ;Apr 30, 2026
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETREM(RTN,DFN,LOC,MAX) ; Add Reminders Due DiagnosticReport
 NEW CNT,IDX,LIST,NUM,REM,RIEN
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 SET LOC=+$GET(LOC)
 IF LOC<1 SET LOC=$$REMLOC(DFN)
 DO ADDRES^C0FHIRBU(.RTN,"DiagnosticReport","REMINDERS-DUE-"_DFN,.IDX)
 DO REPORT(.RTN,IDX,DFN,LOC)
 IF $TEXT(GETLIST^ORQQPX)="" DO NOPXRM(.RTN,IDX,"GETLIST^ORQQPX unavailable") QUIT
 IF $TEXT(MAIN^PXRM)="" DO NOPXRM(.RTN,IDX,"MAIN^PXRM unavailable") QUIT
 KILL LIST
 DO GETLIST^ORQQPX(.LIST,LOC)
 SET (CNT,NUM)=0
 FOR  SET NUM=$ORDER(LIST(NUM)) QUIT:NUM<1!(CNT'<MAX)  DO
 . SET RIEN=+$GET(LIST(NUM))
 . QUIT:RIEN<1
 . KILL REM
 . DO EVAL(.REM,DFN,RIEN)
 . IF '$$ISDUE($GET(REM("status")),$GET(REM("dueDate"))) QUIT
 . SET CNT=CNT+1
 . DO ADDEXT(.RTN,IDX,CNT,.REM)
 SET RTN("entry",IDX,"resource","conclusion")=$SELECT(CNT>0:CNT_" reminder(s) due.",1:"No reminders due.")
 QUIT
 ;
REPORT(RTN,IDX,DFN,LOC) ; Initialize DiagnosticReport resource
 SET RTN("entry",IDX,"resource","resourceType")="DiagnosticReport"
 SET RTN("entry",IDX,"resource","id")="REMINDERS-DUE-"_DFN
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">Clinical reminders due for patient "_+$GET(DFN)_"</div>"
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","code","coding",1,"system")="urn:va:report"
 SET RTN("entry",IDX,"resource","code","coding",1,"code")="reminders-due"
 SET RTN("entry",IDX,"resource","code","coding",1,"display")="Reminders Due"
 SET RTN("entry",IDX,"resource","code","text")="Reminders Due"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$NOWFHIR()
 SET RTN("entry",IDX,"resource","issued")=$$NOWFHIR()
 SET RTN("entry",IDX,"resource","performer",1,"display")="VistA Clinical Reminders"
 IF LOC>0 DO
 . SET RTN("entry",IDX,"resource","extension",1,"url")="http://vistaplex.org/fhir/StructureDefinition/va-reminder-location"
 . SET RTN("entry",IDX,"resource","extension",1,"valueString")=LOC
 QUIT
 ;
EVAL(REM,DFN,RIEN) ; Evaluate one reminder definition with PXRM
 NEW DUEDATE,J,LASTDONE,NAME,NODE,STATUS,TXT
 KILL REM,^TMP("PXRHM",$J)
 SET NAME=$$RNAME(RIEN)
 SET REM("uid")=$$UID(RIEN)
 SET REM("ien")=RIEN
 SET REM("name")=NAME
 DO MAIN^PXRM(DFN,RIEN,5)
 SET NAME=$ORDER(^TMP("PXRHM",$J,RIEN,""))
 IF NAME'="" DO
 . SET NODE=$GET(^TMP("PXRHM",$J,RIEN,NAME))
 . SET STATUS=$PIECE(NODE,U)
 . SET DUEDATE=$PIECE(NODE,U,2)
 . SET LASTDONE=$PIECE(NODE,U,3)
 . SET REM("status")=STATUS
 . SET REM("dueDate")=DUEDATE
 . SET REM("lastDone")=LASTDONE
 . SET TXT=""
 . SET J=0
 . FOR  SET J=$ORDER(^TMP("PXRHM",$J,RIEN,NAME,"TXT",J)) QUIT:J=""  SET TXT=TXT_$GET(^TMP("PXRHM",$J,RIEN,NAME,"TXT",J))_$CHAR(10)
 . SET REM("clinicalMaintenance")=TXT
 KILL ^TMP("PXRHM",$J)
 QUIT
 ;
ADDEXT(RTN,IDX,N,REM) ; Add one va-reminders-due extension
 NEW BASE,C0FI
 SET BASE=$ORDER(RTN("entry",IDX,"resource","extension",""),-1)+1
 SET RTN("entry",IDX,"resource","extension",BASE,"url")="http://vistaplex.org/fhir/StructureDefinition/va-reminders-due"
 DO SUBEXT(.RTN,IDX,BASE,"uid",$GET(REM("uid")))
 DO SUBEXT(.RTN,IDX,BASE,"ien",$GET(REM("ien")))
 DO SUBEXT(.RTN,IDX,BASE,"name",$GET(REM("name")))
 DO SUBEXT(.RTN,IDX,BASE,"status",$GET(REM("status")))
 DO SUBEXT(.RTN,IDX,BASE,"dueDate",$GET(REM("dueDate")))
 DO SUBEXT(.RTN,IDX,BASE,"lastDone",$GET(REM("lastDone")))
 DO SUBEXT(.RTN,IDX,BASE,"clinicalMaintenance",$GET(REM("clinicalMaintenance")))
 DO FINDHF(.REM,+$GET(REM("ien")))
 SET C0FI=0
 FOR  SET C0FI=$ORDER(REM("hf",C0FI)) QUIT:'C0FI  DO SUBEXT(.RTN,IDX,BASE,"healthFactor",$GET(REM("hf",C0FI)))
 QUIT
 ;
SUBEXT(RTN,IDX,BASE,URL,VAL) ; Add named subextension
 NEW N
 SET VAL=$GET(VAL) IF VAL="" QUIT
 SET N=$ORDER(RTN("entry",IDX,"resource","extension",BASE,"extension",""),-1)+1
 SET RTN("entry",IDX,"resource","extension",BASE,"extension",N,"url")=URL
 SET RTN("entry",IDX,"resource","extension",BASE,"extension",N,"valueString")=VAL
 SET RTN("entry",IDX,"resource","extension",BASE,"extension",N,"valueString","\s")=""
 QUIT
 ;
NOPXRM(RTN,IDX,TXT) ; Explain missing reminder runtime
 SET RTN("entry",IDX,"resource","conclusion")="Clinical reminder evaluation unavailable: "_$GET(TXT)
 QUIT
 ;
ISDUE(STATUS,DUEDATE) ; True if reminder evaluation indicates due
 NEW X
 SET X=$$UPCASE^C0FHIR($GET(STATUS))
 IF X["NOT DUE" QUIT 0
 IF X["DUE" QUIT 1
 QUIT 0
 ;
RNAME(RIEN) ; Reminder display name
 NEW NAME
 SET NAME=""
 IF $TEXT(GET1^DIQ)'="" SET NAME=$$GET1^DIQ(811.9,+$GET(RIEN)_",",1.2)
 IF NAME="",($TEXT(GET1^DIQ)'="") SET NAME=$$GET1^DIQ(811.9,+$GET(RIEN)_",",.01)
 IF NAME="" SET NAME=$PIECE($GET(^PXD(811.9,+$GET(RIEN),0)),U)
 QUIT NAME
 ;
UID(RIEN) ; Stable reminder uid
 NEW SYS
 SET SYS=$$SYS^C0FWCTX()
 QUIT "urn:va:pxrm:"_SYS_":"_+$GET(RIEN)
 ;
REMLOC(DFN) ; Most recent patient visit location for reminder list context
 NEW LOC,VDT
 SET (LOC,VDT)=0
 SET VDT=$ORDER(^AUPNVSIT("AET",+$GET(DFN),""),-1)
 IF VDT>0 SET LOC=$ORDER(^AUPNVSIT("AET",+$GET(DFN),VDT,""))
 QUIT +LOC
 ;
NOWFHIR() ; Current time as FHIR instant
 QUIT $$FM2FHIR^C0FHIRBU($$NOW^XLFDT())
 ;
FINDHF(REM,RIEN) ; AUTTHF type-F findings that PXRM will accept
 NEW C0FFI,C0FVP,C0FHF,C0FTYP,C0FCAT,C0FFIL
 SET C0FFI=0
 FOR  SET C0FFI=$ORDER(^PXD(811.9,+$GET(RIEN),20,C0FFI)) QUIT:'C0FFI  DO
 . SET C0FVP=$PIECE($GET(^PXD(811.9,+RIEN,20,C0FFI,0)),U)
 . SET C0FFIL=$PIECE(C0FVP,";",2)
 . IF C0FFIL["811.5" DO TERMHF(.REM,+C0FVP) QUIT
 . QUIT:C0FFIL'["AUTTHF"
 . SET C0FHF=+C0FVP
 . QUIT:C0FHF<1
 . SET C0FTYP=$PIECE($GET(^AUTTHF(C0FHF,0)),U,10)
 . IF C0FTYP="C" DO FAMALL(.REM,C0FHF) QUIT
 . IF C0FTYP="F" DO ONEHF(.REM,C0FHF)
 . SET C0FCAT=+$PIECE($GET(^AUTTHF(C0FHF,0)),U,3)
 . IF C0FCAT>0 DO FAMHF(.REM,C0FCAT)
 QUIT
 ;
TERMHF(REM,TERM) ; AUTTHF members of a reminder term (exclusion HFs, not drug class)
 NEW C0FTI,C0FTVP
 SET C0FTI=0
 FOR  SET C0FTI=$ORDER(^PXRMD(811.5,+$GET(TERM),20,C0FTI)) QUIT:'C0FTI  DO
 . SET C0FTVP=$PIECE($GET(^PXRMD(811.5,+TERM,20,C0FTI,0)),U)
 . QUIT:$PIECE(C0FTVP,";",2)'["AUTTHF"
 . QUIT:$PIECE($GET(^AUTTHF(+C0FTVP,0)),U,10)'="F"
 . DO ONEHF(.REM,+C0FTVP)
 QUIT
 ;
FAMALL(REM,CAT) ; All type-F members when the finding is a category
 NEW C0FMEM
 SET C0FMEM=0
 FOR  SET C0FMEM=$ORDER(^AUTTHF("AC",+$GET(CAT),C0FMEM)) QUIT:'C0FMEM  DO
 . IF $PIECE($GET(^AUTTHF(C0FMEM,0)),U,10)="F" DO ONEHF(.REM,C0FMEM)
 QUIT
 ;
FAMHF(REM,CAT) ; Refused/unable siblings in the finding family
 NEW C0FMEM,C0FN,C0FX
 SET C0FMEM=0
 FOR  SET C0FMEM=$ORDER(^AUTTHF("AC",+$GET(CAT),C0FMEM)) QUIT:'C0FMEM  DO
 . QUIT:$PIECE($GET(^AUTTHF(C0FMEM,0)),U,10)'="F"
 . SET C0FN=$PIECE($GET(^AUTTHF(C0FMEM,0)),U)
 . SET C0FX=$$UPCASE^C0FHIR(C0FN)
 . IF C0FX["UNABLE"!(C0FX["REFUS")!(C0FX["DECLIN") DO ONEHF(.REM,C0FMEM)
 QUIT
 ;
ONEHF(REM,HFIEN) ; Record one AUTTHF name once
 NEW C0FN,C0FI
 SET C0FN=$PIECE($GET(^AUTTHF(+$GET(HFIEN),0)),U)
 QUIT:C0FN=""
 QUIT:$DATA(REM("hfb",C0FN))
 SET REM("hfb",C0FN)=+HFIEN
 SET C0FI=$ORDER(REM("hf",""),-1)+1
 SET REM("hf",C0FI)=C0FN
 QUIT
 ;
