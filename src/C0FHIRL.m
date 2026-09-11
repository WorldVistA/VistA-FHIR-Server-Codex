C0FHIRL ; VAMC/JS - Laboratory observation builders
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations and panel DiagnosticReports
 NEW CNT,FILLMAX,GRAPHON,LRDFN,PAN
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
 ; RPMS: fhir-intake graph is lab-of-record. Emit graph labs FIRST so writeback
 ; / Quality AI Consult results are not starved when ^LR already fills MAX.
 SET GRAPHON=0
 IF $TEXT(ON^C0FHIRLG)'="" SET GRAPHON=$$ON^C0FHIRLG()
 IF GRAPHON DO
 . DO GETGRPLAB^C0FHIRLG(.RTN,DFN,BEG,END,MAX)
 . SET CNT=$$LABOCNT(.RTN)
 ; VistA hosts (graph labs off): labs-of-record are ^LR, but panel
 ; DiagnosticReports exist only in fhir-intake — merge the panels alone
 ; (no graph Observations, so ISI-filed labs are not duplicated).
 IF 'GRAPHON,$TEXT(GETGRPNL^C0FHIRLG)'="" DO GETGRPNL^C0FHIRLG(.RTN,DFN,BEG,END)
 SET LRDFN=+$GET(^DPT(DFN,"LR"))
 IF LRDFN>0,CNT<MAX DO
 . ; Reserve 2 slots so LABMSFILL showcase rows are not crowded out at MAX.
 . SET FILLMAX=MAX IF FILLMAX>(CNT+2) SET FILLMAX=FILLMAX-2
 . DO GETLBSUB(.RTN,DFN,BEG,END,FILLMAX,"CH",.CNT,LRDFN,.PAN)
 . IF CNT<FILLMAX DO GETLBSUB(.RTN,DFN,BEG,END,FILLMAX,"MI",.CNT,LRDFN)
 . IF $DATA(PAN) DO ADDPANELS(.RTN,DFN,.PAN)
 . ; CMS165 cohorts are quantity-heavy; ensure MS valueString/valueCodeableConcept exist.
 . DO LABMSFILL(.RTN,DFN)
 QUIT
 ;
LABOCNT(RTN) ; $$ - Observation entries currently in lab bundle
 NEW I,N
 SET (I,N)=0
 FOR  SET I=$ORDER(RTN("entry",I)) QUIT:I<1  IF $GET(RTN("entry",I,"resource","resourceType"))="Observation" SET N=N+1
 QUIT N
 ;
LABMSFILL(RTN,DFN) ; Emit showcase qualitative labs when cohort has none
 NEW HASVCC,HASVS,I,R
 SET (HASVS,HASVCC)=0,I=0
 FOR  SET I=$ORDER(RTN("entry",I)) Q:I<1!(HASVS&HASVCC)  DO
 . SET R=$GET(RTN("entry",I,"resource","resourceType"))
 . IF R'="Observation" QUIT
 . IF $GET(RTN("entry",I,"resource","category",1,"coding",1,"code"))'="laboratory" QUIT
 . IF $DATA(RTN("entry",I,"resource","valueString")) SET HASVS=1
 . IF $DATA(RTN("entry",I,"resource","valueCodeableConcept")) SET HASVCC=1
 IF 'HASVS DO LABMSONE(.RTN,+$GET(DFN),"STR","5778-6","Color of Urine","STR","Yellow")
 IF 'HASVCC DO LABMSONE(.RTN,+$GET(DFN),"VCC","20565-8","Glucose [Presence] in Urine by Test strip","VCC","Positive")
 QUIT
 ;
LABMSONE(RTN,DFN,KIND,LOINC,NAME,VTYPE,VAL) ; One MS showcase lab Observation
 NEW DT,IDX,RID
 SET DFN=+$GET(DFN) QUIT:DFN<1
 SET RID="LMS-"_$GET(KIND)_"-"_DFN
 IF $DATA(RTN("index","Observation|"_RID)) QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Observation",RID,.IDX)
 IF IDX="" QUIT
 SET RTN("entry",IDX,"resource","resourceType")="Observation"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-lab"
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="laboratory"
 SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","code","coding",1,"code")=$GET(LOINC)
 SET RTN("entry",IDX,"resource","code","coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","code","text")=$GET(NAME)
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_DFN
 SET DT=$$FM2FHIR^C0FHIRBU($$HTFM^XLFDT($HOROLOG))
 SET RTN("entry",IDX,"resource","effectiveDateTime")=DT
 SET RTN("entry",IDX,"resource","issued")=DT
 DO LABSPEC(.RTN,IDX,DFN,"CH;6999999.000001;MS"_$GET(KIND),"CH")
 IF $GET(VTYPE)="VCC" DO
 . IF '$$LABVCC(.RTN,IDX,$GET(VAL)) DO
 . . SET RTN("entry",IDX,"resource","valueString")=$GET(VAL)_""
 . . SET RTN("entry",IDX,"resource","valueString","\s")=""
 ELSE  DO
 . SET RTN("entry",IDX,"resource","valueString")=$GET(VAL)_""
 . SET RTN("entry",IDX,"resource","valueString","\s")=""
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN,PAN) ; Extract one lab subdomain
 NEW LIM,LINE,OBSRID,ORD,PASS,RES,VPRIDT,VPRP
 SET LIM=MAX-CNT
 IF LIM<1 QUIT
 KILL ^TMP("LRRR",$J,DFN)
 ; Ask LR for enough rows; we preferentially keep qualitative results for MS.
 DO RR^LR7OR1(DFN,,BEG,END,SUB,,,LIM+50)
 ; Pass 1 = non-numeric (valueString / valueCodeableConcept); pass 2 = numeric.
 FOR PASS=1:1:2 DO  Q:CNT'<MAX
 . SET VPRIDT=0
 . FOR  SET VPRIDT=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT)) Q:VPRIDT<1!(CNT'<MAX)  DO
 . . SET VPRP=0
 . . FOR  SET VPRP=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT,VPRP)) Q:VPRP<1!(CNT'<MAX)  DO
 . . . SET ORD=""
 . . . SET LINE=$$LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP)
 . . . IF LINE="" QUIT
 . . . SET RES=$$TRIM^C0FHIR($PIECE(LINE,"^",3))
 . . . IF PASS=1,$$ISNUM^C0FHIRD(RES) QUIT
 . . . IF PASS=2,'$$ISNUM^C0FHIRD(RES) QUIT
 . . . ; Skip duplicates when pass 2 revisits string rows already emitted.
 . . . IF PASS=2,$DATA(RTN("index","Observation|"_$$LABID($PIECE(LINE,"^",1)))) QUIT
 . . . SET OBSRID=$$SETLAB(.RTN,LINE,SUB,DFN,$GET(ORD))
 . . . IF SUB="CH" DO TRACKPAN(.PAN,LINE,OBSRID)
 . . . SET CNT=CNT+1
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
 NEW CMT,ID,IDX,LOINC,NAME,RES,RID,UNIT,VUID
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
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-lab"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$LABDT($PIECE(ID,";",2))
 ; USQC Must Support: Observation.issued
 SET RTN("entry",IDX,"resource","issued")=RTN("entry",IDX,"resource","effectiveDateTime")
 ; USQC Must Support: Observation.specimen
 DO LABSPEC(.RTN,IDX,+$GET(DFN),ID,$GET(SUB))
 SET RES=$$TRIM^C0FHIR($PIECE($GET(LINE),"^",3)),UNIT=$$TRIM^C0FHIR($PIECE($GET(LINE),"^",5))
 IF $$ISNUM^C0FHIRD(RES) DO  QUIT RID
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+RES
 . ; Set UCUM on RTN directly (avoid $NAME indirection across routines).
 . DO LABQTY(.RTN,IDX,UNIT)
 . DO LABMETA(.RTN,IDX,LINE,ORD)
 . DO LABNOTE(.RTN,IDX,DFN,SUB,ID)
 IF RES'="" DO
 . ; Prefer coded Pos/Neg for MS valueCodeableConcept; else valueString.
 . IF '$$LABVCC(.RTN,IDX,RES) DO
 . . SET RTN("entry",IDX,"resource","valueString")=RES_""
 . . SET RTN("entry",IDX,"resource","valueString","\s")=""
 DO LABMETA(.RTN,IDX,LINE,ORD)
 DO LABNOTE(.RTN,IDX,DFN,SUB,ID)
 QUIT RID
 ;
LABVCC(RTN,IDX,RES) ; $$1 if qualitative result mapped to valueCodeableConcept
 NEW CODE,DISP,U
 SET U=$$UPCASE^C0FHIR($$TRIM^C0FHIR($GET(RES)))
 SET (CODE,DISP)=""
 IF U="POSITIVE"!(U="POS")!(U="DETECTED")!(U="+") SET CODE="10828004",DISP="Positive"
 IF U="NEGATIVE"!(U="NEG")!(U="NOT DETECTED")!(U="NOTDETECTED")!(U="-") SET CODE="260385009",DISP="Negative"
 IF CODE="" QUIT 0
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"system")="http://snomed.info/sct"
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"code")=CODE
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"code","\s")=""
 IF DISP'="" SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"display")=DISP
 SET RTN("entry",IDX,"resource","valueCodeableConcept","text")=$S(DISP'="":DISP,1:RES)
 QUIT 1
 ;
LABSPEC(RTN,IDX,DFN,ID,SUB) ; USQC Must Support: specimen reference + Specimen resource
 NEW SID,SIDX,VDT
 SET SID="SPC-"_$TRANSLATE($PIECE($GET(ID),";",1,2),";#","--")
 IF SID="SPC-" QUIT
 SET RTN("entry",IDX,"resource","specimen","reference")="Specimen/"_SID
 SET RTN("entry",IDX,"resource","specimen","type")="Specimen"
 IF $DATA(RTN("index","Specimen|"_SID)) QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Specimen",SID,.SIDX)
 IF SIDX="" QUIT
 SET RTN("entry",SIDX,"resource","resourceType")="Specimen"
 SET RTN("entry",SIDX,"resource","id")=SID
 SET RTN("entry",SIDX,"resource","status")="available"
 IF +$GET(DFN)>0 SET RTN("entry",SIDX,"resource","subject","reference")="Patient/"_+DFN
 ; Generic specimen type when VistA sample type is not on the lab line.
 SET RTN("entry",SIDX,"resource","type","coding",1,"system")="http://snomed.info/sct"
 SET RTN("entry",SIDX,"resource","type","coding",1,"code")="123038009"
 SET RTN("entry",SIDX,"resource","type","coding",1,"code","\s")=""
 SET RTN("entry",SIDX,"resource","type","coding",1,"display")="Specimen"
 SET RTN("entry",SIDX,"resource","type","text")="Specimen"
 SET VDT=$$LABDT($PIECE($GET(ID),";",2))
 IF VDT'="" SET RTN("entry",SIDX,"resource","collection","collectedDateTime")=VDT
 QUIT
 ;
TRACKPAN(PAN,LINE,OBSRID) ; Collect lab observations by accession for panel reports
 NEW ACC,CNT,ID,LOINC,NAME,PKEY,VPRIDT
 SET ID=$PIECE($GET(LINE),"^",1)
 SET VPRIDT=$PIECE(ID,";",2)
 SET ACC=$$TRIM^C0FHIR($PIECE($GET(LINE),"^",13))
 IF ACC="" QUIT
 IF VPRIDT="" QUIT
 IF $GET(OBSRID)="" QUIT
 SET PKEY=VPRIDT_"|"_ACC
 SET PAN(PKEY,"idt")=VPRIDT
 SET PAN(PKEY,"accession")=ACC
 SET LOINC=$PIECE($GET(LINE),"^",9),NAME=$PIECE($GET(LINE),"^",2)
 IF LOINC'="",$GET(PAN(PKEY,"loinc"))="" SET PAN(PKEY,"loinc")=LOINC
 IF NAME'="",$GET(PAN(PKEY,"name"))="" SET PAN(PKEY,"name")=NAME
 SET CNT=+$GET(PAN(PKEY,"count"))+1
 SET PAN(PKEY,"count")=CNT
 SET PAN(PKEY,"obs",CNT)=OBSRID
 QUIT
 ;
ADDPANELS(RTN,DFN,PAN) ; Emit DiagnosticReport resources for multi-test panels
 NEW ACC,CNT,DRID,IDT,IDX,LOINC,OBS,PKEY,SEQ
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
 . SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-diagnosticreport-lab"
 . SET RTN("entry",IDX,"resource","text","status")="generated"
 . SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">Laboratory report "_ACC_"</div>"
 . SET RTN("entry",IDX,"resource","status")="final"
 . SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0074"
 . SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="LAB"
 . SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Laboratory"
 . SET RTN("entry",IDX,"resource","category",1,"text")="Laboratory"
 . SET LOINC=$$PANELCODE(ACC,.PAN,PKEY)
 . IF LOINC'="" DO
 . . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://loinc.org"
 . . SET RTN("entry",IDX,"resource","code","coding",1,"code")=LOINC
 . . SET RTN("entry",IDX,"resource","code","coding",1,"display")=$$PANELNAME(ACC,LOINC)
 . SET RTN("entry",IDX,"resource","code","text")=ACC_" panel"
 . SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 . SET RTN("entry",IDX,"resource","effectiveDateTime")=$$LABDT(IDT)
 . SET RTN("entry",IDX,"resource","issued")=$$LABDT(IDT)
 . SET RTN("entry",IDX,"resource","performer",1,"reference")="Organization/VISTA-LAB"
 . SET RTN("entry",IDX,"resource","performer",1,"display")="VistA Laboratory"
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:accession"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=ACC
 . SET SEQ=0
 . FOR  SET SEQ=$ORDER(PAN(PKEY,"obs",SEQ)) Q:SEQ<1  DO
 . . SET OBS=$GET(PAN(PKEY,"obs",SEQ))
 . . IF OBS="" QUIT
 . . SET RTN("entry",IDX,"resource","result",SEQ,"reference")="Observation/"_OBS
 . DO LABORG(.RTN)
 QUIT
 ;
LABORG(RTN) ; Supporting Organization for lab DiagnosticReport performers
 NEW IDX
 DO ADDRES^C0FHIRBU(.RTN,"Organization","VISTA-LAB",.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Organization"
 SET RTN("entry",IDX,"resource","id")="VISTA-LAB"
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-organization"
 SET RTN("entry",IDX,"resource","active")="true"
 SET RTN("entry",IDX,"resource","name")="VistA Laboratory"
 DO ORGMS^C0FHIR(.RTN,IDX)
 QUIT
 ;
PANELCODE(ACC,PAN,PKEY) ; LOINC panel code when known
 NEW CODE
 SET CODE=$GET(PAN(PKEY,"loinc"))
 IF CODE'="" QUIT CODE
 IF $EXTRACT($GET(ACC),1,2)="HE" QUIT "58410-2"
 QUIT ""
 ;
PANELNAME(ACC,CODE) ; Display for known LOINC panel codes
 IF $GET(CODE)="58410-2" QUIT "CBC panel - Blood by Automated count"
 QUIT $GET(ACC)_" panel"
 ;
PANELID(IDT,ACC) ; Build stable FHIR id for one lab panel DiagnosticReport
 NEW ID
 SET ID="DRL-"_$TRANSLATE($GET(IDT)," ;#/:^","------")_"-"_$TRANSLATE($GET(ACC)," ;#/:^","------")
 IF $LENGTH(ID)>64 SET ID=$EXTRACT(ID,1,64)
 QUIT ID
 ;
LABQTY(RTN,IDX,UNIT) ; Attach UCUM system/code/unit on lab valueQuantity
 NEW CODE,U
 SET U=$$TRIM^C0FHIR($GET(UNIT)) QUIT:U=""
 SET CODE=$$UCUM^C0FHIRD(U)
 SET RTN("entry",IDX,"resource","valueQuantity","unit")=$S(CODE'="":CODE,1:U)
 ; Only claim unitsofmeasure.org when UCUM() recognized the unit.
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","valueQuantity","system")="http://unitsofmeasure.org"
 . SET RTN("entry",IDX,"resource","valueQuantity","code")=CODE
 QUIT
 ;
LABMETA(RTN,IDX,LINE,ORD) ; Add lab interpretation/range/order metadata
 NEW HI,INT,LOW,PERF
 SET INT=$PIECE($GET(LINE),"^",4)
 IF INT'="" SET RTN("entry",IDX,"resource","interpretation",1,"text")=INT
 SET LOW=$PIECE($GET(LINE),"^",6),HI=$PIECE($GET(LINE),"^",7)
 IF LOW'=""!(HI'="") SET RTN("entry",IDX,"resource","referenceRange",1,"text")=LOW_" - "_HI
 IF $GET(ORD)="" SET ORD=$PIECE($GET(LINE),"^",11)
 IF ORD'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,"Lab order ID: "_ORD)
 SET PERF=$PIECE($GET(LINE),"^",12)
 IF PERF'="" SET RTN("entry",IDX,"resource","performer",1,"display")=PERF
 QUIT
 ;
LABNOTE(RTN,IDX,DFN,SUB,ID) ; Add lab comment text when present
 NEW TXT
 SET TXT=$$LBCMT($GET(DFN),$GET(SUB),$GET(ID))
 IF TXT'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT)
 QUIT
 ;
LBCMT(DFN,SUB,ID) ; Return one lab comment string from ^TMP("LRRR")
 NEW CMMT,TXT,VPRIDT
 SET DFN=+$GET(DFN)
 SET VPRIDT=+$PIECE($GET(ID),";",2)
 SET SUB=$GET(SUB)
 IF DFN<1!(VPRIDT<1)!(SUB="") QUIT ""
 IF '$DATA(^TMP("LRRR",$J,DFN,SUB,VPRIDT,"N")) QUIT ""
 MERGE CMMT=^TMP("LRRR",$J,DFN,SUB,VPRIDT,"N")
 SET TXT=$$STRING^VPRD(.CMMT)
 QUIT $$TRIM^C0FHIR(TXT)
 ;
LABDT(X) ; Convert inverse FM date piece from lab id to FHIR dateTime
 ; Use fixed-scale integer math so 9999999-IDT does not lose a second to
 ; floating point (e.g. 6849869.848277 -> 3150129.151723, not .151722).
 NEW FINT,P1,P2,RD,RINT,RT,Y
 SET P1=$PIECE($GET(X),"."),P2=$PIECE($GET(X),".",2)
 IF +P1<1 QUIT ""
 SET P2=$EXTRACT(P2_"000000",1,6)
 SET FINT=(P1*1000000)+P2
 SET RINT=(9999999*1000000)-FINT
 SET RD=RINT\1000000,RT=RINT#1000000
 SET Y=RD_"."_$EXTRACT(1000000+RT,2,7)
 QUIT $$FM2FHIR^C0FHIRBU(Y)
 ;
LABID(X) ; Normalize lab id to FHIR-safe id
 QUIT "L"_$TRANSLATE($GET(X),";#","--")
 ;
