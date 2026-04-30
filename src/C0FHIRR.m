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
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","code","coding",1,"system")="urn:va:report"
 SET RTN("entry",IDX,"resource","code","coding",1,"code")="reminders-due"
 SET RTN("entry",IDX,"resource","code","coding",1,"display")="Reminders Due"
 SET RTN("entry",IDX,"resource","code","text")="Reminders Due"
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
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
 NEW BASE
 SET BASE=$ORDER(RTN("entry",IDX,"resource","extension",""),-1)+1
 SET RTN("entry",IDX,"resource","extension",BASE,"url")="http://vistaplex.org/fhir/StructureDefinition/va-reminders-due"
 DO SUBEXT(.RTN,IDX,BASE,"uid",$GET(REM("uid")))
 DO SUBEXT(.RTN,IDX,BASE,"ien",$GET(REM("ien")))
 DO SUBEXT(.RTN,IDX,BASE,"name",$GET(REM("name")))
 DO SUBEXT(.RTN,IDX,BASE,"status",$GET(REM("status")))
 DO SUBEXT(.RTN,IDX,BASE,"dueDate",$GET(REM("dueDate")))
 DO SUBEXT(.RTN,IDX,BASE,"lastDone",$GET(REM("lastDone")))
 DO SUBEXT(.RTN,IDX,BASE,"clinicalMaintenance",$GET(REM("clinicalMaintenance")))
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
 SET SYS=$SELECT($TEXT(SYS^HMPUTILS)'="":$$SYS^HMPUTILS,1:"vista")
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
