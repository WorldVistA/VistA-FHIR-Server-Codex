C0FHIRL ; VAMC/JS - Laboratory observation builders
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations and panel DiagnosticReports
 NEW CNT,LRDFN,PAN
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET LRDFN=+$GET(^DPT(DFN,"LR"))
 IF LRDFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 SET CNT=0
 DO GETLBSUB(.RTN,DFN,BEG,END,MAX,"CH",.CNT,LRDFN,.PAN)
 IF CNT<MAX DO GETLBSUB(.RTN,DFN,BEG,END,MAX,"MI",.CNT,LRDFN)
 IF $DATA(PAN) DO ADDPANELS(.RTN,DFN,.PAN)
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN,PAN) ; Extract one lab subdomain
 NEW LIM,LINE,OBSRID,ORD,VPRIDT,VPRP
 SET LIM=MAX-CNT
 IF LIM<1 QUIT
 KILL ^TMP("LRRR",$J,DFN)
 DO RR^LR7OR1(DFN,,BEG,END,SUB,,,LIM)
 SET VPRIDT=0
 FOR  SET VPRIDT=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT)) Q:VPRIDT<1!(CNT'<MAX)  DO
 . SET VPRP=0
 . FOR  SET VPRP=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT,VPRP)) Q:VPRP<1!(CNT'<MAX)  DO
 .. SET ORD=""
 .. SET LINE=$$LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP)
 .. IF LINE="" QUIT
 .. SET OBSRID=$$SETLAB(.RTN,LINE,SUB,DFN,$GET(ORD))
 .. IF SUB="CH" DO TRACKPAN(.PAN,LINE,OBSRID)
 .. SET CNT=CNT+1
 KILL ^TMP("LRRR",$J,DFN)
 QUIT
 ;
LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP) ; Build normalized line from ^TMP("LRRR")
 NEW X0
 SET X0=$GET(^TMP("LRRR",$J,DFN,SUB,VPRIDT,VPRP))
 IF X0="" QUIT ""
 IF SUB="CH" QUIT $$CHLINE(LRDFN,VPRIDT,VPRP,X0)
 IF SUB="MI" QUIT $$MILINE(VPRIDT,VPRP,X0)
 QUIT ""
 ;
CHLINE(LRDFN,VPRIDT,VPRP,X0) ; Return normalized chemistry line
 NEW ACC,HDR,ID,LINE,LOINC,LOINCP,LOW,NODE,ORD,P,PERF,RANGE,TEST,VUID,HIGH
 SET P=+$$LRDN^LRPXAPIU(+$GET(X0))
 SET ID="CH;"_VPRIDT_";"_$SELECT(P>0:P,1:VPRP)
 SET TEST=$PIECE($GET(^LAB(60,+X0,0)),"^")
 IF $PIECE(X0,"^",15)'="" SET TEST=$PIECE(X0,"^",15)
 SET LINE=ID_"^"_TEST_"^"_$PIECE(X0,"^",2)_"^"_$PIECE(X0,"^",3)_"^"_$PIECE(X0,"^",4)
 SET RANGE=$PIECE(X0,"^",5)
 SET (LOW,HIGH)=""
 IF RANGE["-" DO
 . SET LOW=$$TRIM^C0FHIR($PIECE(RANGE,"-",1))
 . SET HIGH=$$TRIM^C0FHIR($PIECE(RANGE,"-",2,99))
 SET $PIECE(LINE,"^",6)=LOW
 SET $PIECE(LINE,"^",7)=HIGH
 IF P>0 SET NODE=$GET(^LR(LRDFN,"CH",VPRIDT,P))
 SET LOINCP=+$PIECE($PIECE($GET(NODE),"^",3),"!",3)
 IF LOINCP>0 DO
 . SET LOINC=$$GET1^DIQ(95.3,LOINCP_",",.01)
 . IF LOINC'="" DO
 .. SET $PIECE(LINE,"^",9)=LOINC
 .. SET VUID=$$VUID^VPRD(+LOINC,95.3)
 .. IF VUID'="" SET $PIECE(LINE,"^",10)=VUID
 SET ORD=+$PIECE(X0,"^",17)
 IF ORD>0 SET $PIECE(LINE,"^",11)=ORD
 SET PERF=+$PIECE($GET(NODE),"^",9)
 IF PERF>0 SET $PIECE(LINE,"^",12)=$$NAME^XUAF4(PERF)
 SET ACC=$$TRIM^C0FHIR($PIECE(X0,"^",16))
 IF ACC="" DO
 . SET HDR=$GET(^LR(LRDFN,"CH",VPRIDT,0))
 . SET ACC=$$TRIM^C0FHIR($PIECE(HDR,"^",6))
 IF ACC'="" SET $PIECE(LINE,"^",13)=ACC
 QUIT LINE
 ;
MILINE(VPRIDT,VPRP,X0) ; Return normalized microbiology line
 NEW ACC,ID,LINE,ORD,TEST
 IF $L($PIECE(X0,"^"))'>1 QUIT ""
 SET ID="MI;"_VPRIDT_";"_VPRP
 SET TEST=$PIECE(X0,"^",15)
 IF TEST="" SET TEST="Microbiology"
 SET LINE=ID_"^"_TEST_"^"_$PIECE(X0,"^",2)_"^"_$PIECE(X0,"^",3)_"^"_$PIECE(X0,"^",4)
 SET ORD=+$PIECE(X0,"^",17)
 IF ORD>0 SET $PIECE(LINE,"^",11)=ORD
 SET ACC=$$TRIM^C0FHIR($PIECE(X0,"^",16))
 IF ACC'="" SET $PIECE(LINE,"^",13)=ACC
 QUIT LINE
 ;
SETLAB(RTN,LINE,SUB,DFN,ORD) ; Map one VPR lab line to FHIR Observation
 NEW ID,IDX,LOINC,NAME,RES,RID,UNIT,VUID
 SET ID=$PIECE($GET(LINE),"^",1)
 IF ID="" QUIT ""
 SET RID=$$LABID(ID)
 DO ADDRES^C0FHIRBU(.RTN,"Observation",RID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Observation"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="laboratory"
 SET NAME=$PIECE($GET(LINE),"^",2)
 IF NAME'="" SET RTN("entry",IDX,"resource","code","text")=NAME
 SET LOINC=$PIECE($GET(LINE),"^",9)
 IF LOINC'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://loinc.org"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=LOINC
 SET VUID=$PIECE($GET(LINE),"^",10)
 IF VUID'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",2,"system")="urn:va:vuid"
 . SET RTN("entry",IDX,"resource","code","coding",2,"code")=VUID
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$LABDT($PIECE(ID,";",2))
 SET RES=$PIECE($GET(LINE),"^",3),UNIT=$PIECE($GET(LINE),"^",5)
 IF $$ISNUM^C0FHIRD(RES) DO  QUIT RID
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+RES
 . IF UNIT'="" SET RTN("entry",IDX,"resource","valueQuantity","unit")=UNIT
 . DO LABMETA(.RTN,IDX,LINE,ORD)
 IF RES'="" SET RTN("entry",IDX,"resource","valueString")=RES
 DO LABMETA(.RTN,IDX,LINE,ORD)
 QUIT RID
 ;
TRACKPAN(PAN,LINE,OBSRID) ; Collect lab observations by accession for panel reports
 NEW ACC,CNT,ID,PKEY,VPRIDT
 SET ID=$PIECE($GET(LINE),"^",1)
 SET VPRIDT=$PIECE(ID,";",2)
 SET ACC=$$TRIM^C0FHIR($PIECE($GET(LINE),"^",13))
 IF ACC="" QUIT
 IF VPRIDT="" QUIT
 IF $GET(OBSRID)="" QUIT
 SET PKEY=VPRIDT_"|"_ACC
 SET PAN(PKEY,"idt")=VPRIDT
 SET PAN(PKEY,"accession")=ACC
 SET CNT=+$GET(PAN(PKEY,"count"))+1
 SET PAN(PKEY,"count")=CNT
 SET PAN(PKEY,"obs",CNT)=OBSRID
 QUIT
 ;
ADDPANELS(RTN,DFN,PAN) ; Emit DiagnosticReport resources for multi-test panels
 NEW ACC,CNT,DRID,IDT,IDX,OBS,PKEY,SEQ
 SET PKEY=""
 FOR  SET PKEY=$ORDER(PAN(PKEY)) Q:PKEY=""  DO
 . SET CNT=+$GET(PAN(PKEY,"count"))
 . IF CNT<2 QUIT
 . SET IDT=$GET(PAN(PKEY,"idt"))
 . SET ACC=$GET(PAN(PKEY,"accession"))
 . IF IDT=""!(ACC="") QUIT
 . SET DRID=$$PANELID(IDT,ACC)
 . DO ADDRES^C0FHIRBU(.RTN,"DiagnosticReport",DRID,.IDX)
 . SET RTN("entry",IDX,"resource","resourceType")="DiagnosticReport"
 . SET RTN("entry",IDX,"resource","id")=DRID
 . SET RTN("entry",IDX,"resource","status")="final"
 . SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0074"
 . SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="LAB"
 . SET RTN("entry",IDX,"resource","code","text")=ACC_" panel"
 . SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 . SET RTN("entry",IDX,"resource","effectiveDateTime")=$$LABDT(IDT)
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:accession"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=ACC
 . SET SEQ=0
 . FOR  SET SEQ=$ORDER(PAN(PKEY,"obs",SEQ)) Q:SEQ<1  DO
 . . SET OBS=$GET(PAN(PKEY,"obs",SEQ))
 . . IF OBS="" QUIT
 . . SET RTN("entry",IDX,"resource","result",SEQ,"reference")=$$REFURL^C0FHIRBU("Observation",OBS)
 QUIT
 ;
PANELID(IDT,ACC) ; Build stable FHIR id for one lab panel DiagnosticReport
 NEW ID
 SET ID="DRL-"_$TRANSLATE($GET(IDT)," ;#/:^","------")_"-"_$TRANSLATE($GET(ACC)," ;#/:^","------")
 IF $LENGTH(ID)>64 SET ID=$EXTRACT(ID,1,64)
 QUIT ID
 ;
LABMETA(RTN,IDX,LINE,ORD) ; Add lab interpretation/range/order metadata
 NEW HI,INT,LOW,PERF
 SET INT=$PIECE($GET(LINE),"^",4)
 IF INT'="" SET RTN("entry",IDX,"resource","interpretation",1,"text")=INT
 SET LOW=$PIECE($GET(LINE),"^",6),HI=$PIECE($GET(LINE),"^",7)
 IF LOW'=""!(HI'="") SET RTN("entry",IDX,"resource","referenceRange",1,"text")=LOW_" - "_HI
 IF $GET(ORD)="" SET ORD=$PIECE($GET(LINE),"^",11)
 IF ORD'="" SET RTN("entry",IDX,"resource","note",1,"text")="Lab order ID: "_ORD
 SET PERF=$PIECE($GET(LINE),"^",12)
 IF PERF'="" SET RTN("entry",IDX,"resource","performer",1,"display")=PERF
 QUIT
 ;
LABDT(X) ; Convert inverse FM date piece from lab id to FHIR dateTime
 NEW Y
 SET Y=+$GET(X)
 IF Y<1 QUIT ""
 SET Y=9999999-Y
 QUIT $$FM2FHIR^C0FHIRBU(Y)
 ;
LABID(X) ; Normalize lab id to FHIR-safe id
 QUIT "L"_$TRANSLATE($GET(X),";#","--")
 ;
