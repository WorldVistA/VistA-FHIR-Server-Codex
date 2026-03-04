C0FHIR ; VistA FHIR Server entry points
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 ; Namespace convention:
 ; - All project MUMPS routines use the C0FHIR prefix.
 ; - New DDE entities defined for this project use the C0FHIR namespace.
 ; - Bundle requests return one multi-domain FHIR Bundle per request.
 ; - JSON encoding standard is ENCODE^XLFJSON.
 ;
 QUIT  ; No default action
 ;
GETPAT(RTN,DFN) ; Add Patient resource to the passed bundle array
 ; RTN is the in-flight Bundle structure
 ; This first version maps core demographic fields from file #2.
 NEW DOB,FAM,GIV,IDX,NAME,SEX,SSN,X0
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Patient",DFN,.IDX)
 SET X0=$GET(^DPT(DFN,0))
 SET NAME=$PIECE(X0,"^")
 SET RTN("entry",IDX,"resource","resourceType")="Patient"
 SET RTN("entry",IDX,"resource","id")=DFN
 IF NAME'="" DO
 . SET RTN("entry",IDX,"resource","name",1,"text")=NAME
 . SET FAM=$$TRIM($PIECE(NAME,",",1))
 . SET GIV=$$TRIM($PIECE(NAME,",",2,99))
 . IF FAM'="" SET RTN("entry",IDX,"resource","name",1,"family")=FAM
 . IF GIV'="" SET RTN("entry",IDX,"resource","name",1,"given",1)=GIV
 SET SEX=$PIECE(X0,"^",2)
 IF SEX'="" SET RTN("entry",IDX,"resource","gender")=$$GENDER(SEX)
 SET DOB=+$PIECE(X0,"^",3)
 IF DOB>0 SET RTN("entry",IDX,"resource","birthDate")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 SET SSN=$PIECE(X0,"^",9)
 IF SSN?9N DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-ssn"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=SSN
 QUIT
 ;
GETENC(RTN,ENCIEN,DFN) ; Add Encounter resource to the passed bundle array
 ; ENCIEN is expected to be a visit ien from ^AUPNVSIT
 NEW CLASS,ENC,IDX,TYPE
 DO ENSUREENV
 SET ENCIEN=+ENCIEN
 IF ENCIEN<1 QUIT
 DO EN1^VPRDVSIT(ENCIEN,.ENC)
 DO ADDRES^C0FHIRBU(.RTN,"Encounter","E"_ENCIEN,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Encounter"
 SET RTN("entry",IDX,"resource","id")="E"_ENCIEN
 SET RTN("entry",IDX,"resource","status")="finished"
 SET CLASS=$SELECT($GET(ENC("patientClass"))="IMP":"IMP",1:"AMB")
 SET RTN("entry",IDX,"resource","class","system")="http://terminology.hl7.org/CodeSystem/v3-ActCode"
 SET RTN("entry",IDX,"resource","class","code")=CLASS
 IF +$GET(DFN)>0 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 IF +$GET(ENC("dateTime"))>0 SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(ENC("dateTime"))
 IF +$GET(ENC("departureDateTime"))>0 SET RTN("entry",IDX,"resource","period","end")=$$FM2FHIR^C0FHIRBU(ENC("departureDateTime"))
 SET TYPE=$PIECE($GET(ENC("type")),"^",2)
 IF TYPE'="" SET RTN("entry",IDX,"resource","type",1,"text")=TYPE
 QUIT
 ;
GETCOND(RTN,DFN,BEG,END,MAX) ; Add Condition resources for patient/date range
 NEW CNT,I,IEN,ONSET,PLIST,PROB
 DO ENSUREENV
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 DO LIST^GMPLUTL2(.PLIST,DFN,"")
 SET (CNT,I)=0
 FOR  SET I=$ORDER(PLIST(I)) Q:I<1!(CNT'<MAX)  DO
 . SET ONSET=+$PIECE($GET(PLIST(I)),"^",5)
 . IF ONSET>0,(ONSET<BEG!(ONSET>END)) QUIT
 . SET IEN=+$GET(PLIST(I))
 . IF IEN<1 QUIT
 . KILL PROB
 . DO EN1^VPRDGMPL(IEN,.PROB)
 . IF '$DATA(PROB) QUIT
 . DO SETCOND(.RTN,.PROB,DFN)
 . SET CNT=CNT+1
 QUIT
 ;
SETCOND(RTN,PROB,DFN) ; Map one VPR problem to a FHIR Condition resource
 NEW CODESYS,ID,IDX,STATUS,TXT
 SET ID=+$GET(PROB("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Condition","C"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Condition"
 SET RTN("entry",IDX,"resource","id")="C"_ID
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="problem-list-item"
 SET STATUS=$PIECE($GET(PROB("status")),"^")
 IF STATUS="A" DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-clinical"
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="active"
 IF STATUS="I" DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-clinical"
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="inactive"
 IF $GET(PROB("unverified"))=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-ver-status"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="unconfirmed"
 IF $GET(PROB("unverified"))'=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-ver-status"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="confirmed"
 SET TXT=$GET(PROB("name"))
 IF TXT'="" SET RTN("entry",IDX,"resource","code","text")=TXT
 IF $GET(PROB("sctc"))'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://snomed.info/sct"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=$GET(PROB("sctc"))
 . IF $GET(PROB("sctt"))'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$GET(PROB("sctt"))
 IF $GET(PROB("sctc"))="",($GET(PROB("icd"))'="") DO
 . SET CODESYS=$$CONDSYS($GET(PROB("codingSystem")))
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")=CODESYS
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=$GET(PROB("icd"))
 . IF $GET(PROB("icdd"))'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$GET(PROB("icdd"))
 IF +$GET(PROB("onset"))>0 SET RTN("entry",IDX,"resource","onsetDateTime")=$$FM2FHIR^C0FHIRBU($GET(PROB("onset")))
 IF +$GET(PROB("entered"))>0 SET RTN("entry",IDX,"resource","recordedDate")=$$FM2FHIR^C0FHIRBU($GET(PROB("entered")))
 IF +$GET(PROB("resolved"))>0 SET RTN("entry",IDX,"resource","abatementDateTime")=$$FM2FHIR^C0FHIRBU($GET(PROB("resolved")))
 QUIT
 ;
CONDSYS(X) ; Map VPR coding system token to FHIR system URL
 NEW Y
 SET Y=$$UPCASE($GET(X))
 IF Y["10" QUIT "http://hl7.org/fhir/sid/icd-10-cm"
 IF Y["SNOMED" QUIT "http://snomed.info/sct"
 QUIT "http://hl7.org/fhir/sid/icd-9-cm"
 ;
GETOBS(RTN,DFN,BEG,END,MAX) ; Add Observation resources (vitals) for patient/date range
 NEW CNT,GMRVSTR,IDT,IEN,TYPE,VIT
 DO ENSUREENV
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=$GET(END)
 IF END="" SET END=4141015
 IF END'["." SET END=END_".24"
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 SET GMRVSTR="BP;T;R;P;HT;WT;CVP;CG;PO2;PN",GMRVSTR(0)=BEG_"^"_END_"^"_MAX_"^1"
 KILL ^UTILITY($J,"GMRVD")
 DO EN1^GMRVUT0
 SET (CNT,IDT)=0
 FOR  SET IDT=$ORDER(^UTILITY($J,"GMRVD",IDT)) Q:IDT<1!(CNT'<MAX)  DO
 . SET TYPE=""
 . FOR  SET TYPE=$ORDER(^UTILITY($J,"GMRVD",IDT,TYPE)) Q:TYPE=""!(CNT'<MAX)  DO
 .. SET IEN=+$ORDER(^UTILITY($J,"GMRVD",IDT,TYPE,0))
 .. IF IEN<1 QUIT
 .. KILL VIT
 .. DO EN1^VPRDGMV(IEN,.VIT)
 .. IF '$DATA(VIT) QUIT
 .. DO SETOBS(.RTN,.VIT,DFN)
 .. SET CNT=CNT+1
 KILL ^UTILITY($J,"GMRVD")
 QUIT
 ;
SETOBS(RTN,VIT,DFN) ; Map one VPR vital entry to a FHIR Observation resource
 NEW CODE,ID,IDX,M0,MRES,MUNT,NAME,RES,UNIT,VUID
 SET M0=$GET(VIT("measurement",1))
 SET ID=+$PIECE(M0,"^",1)
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Observation","V"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Observation"
 SET RTN("entry",IDX,"resource","id")="V"_ID
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="vital-signs"
 SET VUID=$PIECE(M0,"^",2),NAME=$PIECE(M0,"^",3)
 IF VUID'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="urn:va:vuid"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=VUID
 IF NAME'="" SET RTN("entry",IDX,"resource","code","text")=NAME
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 IF +$GET(VIT("taken"))>0 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$FM2FHIR^C0FHIRBU($GET(VIT("taken")))
 IF +$GET(VIT("entered"))>0 SET RTN("entry",IDX,"resource","issued")=$$FM2FHIR^C0FHIRBU($GET(VIT("entered")))
 SET RES=$PIECE(M0,"^",4),UNIT=$PIECE(M0,"^",5),MRES=$PIECE(M0,"^",6),MUNT=$PIECE(M0,"^",7)
 IF $$ISNUM(MRES) DO  QUIT
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+MRES
 . IF MUNT'="" SET RTN("entry",IDX,"resource","valueQuantity","unit")=MUNT
 IF $$ISNUM(RES) DO  QUIT
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+RES
 . IF UNIT'="" SET RTN("entry",IDX,"resource","valueQuantity","unit")=UNIT
 IF RES'="" SET RTN("entry",IDX,"resource","valueString")=RES
 QUIT
 ;
ISNUM(X) ; True if X is numeric
 NEW Y
 SET Y=$GET(X)
 IF Y="" QUIT 0
 IF Y?1.N QUIT 1
 IF Y?1.N1"."1.N QUIT 1
 IF Y?1"-".N QUIT 1
 IF Y?1"-".N1"."1.N QUIT 1
 QUIT 0
 ;
GETALGY(RTN,DFN,BEG,END,MAX) ; Add AllergyIntolerance resources
 NEW CNT,GMRA,GMRAL,ID,REAC
 DO ENSUREENV
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 DO EN1^GMRADPT
 ; If no allergy entries exist, VPR uses assessment flags; skip for now.
 IF '$GET(GMRAL) QUIT
 SET (CNT,ID)=0
 FOR  SET ID=$ORDER(GMRAL(ID)) Q:ID<1!(CNT'<MAX)  DO
 . KILL REAC
 . DO EN1^VPRDGMRA(ID,.REAC)
 . IF '$DATA(REAC) QUIT
 . DO SETALGY(.RTN,.REAC,DFN)
 . SET CNT=CNT+1
 QUIT
 ;
SETALGY(RTN,REAC,DFN) ; Map one VPR allergy entry to FHIR AllergyIntolerance
 NEW CODE,ID,IDX,SEV,TAG,TYPE
 SET ID=+$GET(REAC("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"AllergyIntolerance","A"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="AllergyIntolerance"
 SET RTN("entry",IDX,"resource","id")="A"_ID
 SET RTN("entry",IDX,"resource","patient","reference")=$$PATREF^C0FHIRBU(DFN)
 SET TYPE=$PIECE($GET(REAC("type")),"^")
 IF TYPE="D" SET RTN("entry",IDX,"resource","category",1)="medication"
 IF TYPE="F" SET RTN("entry",IDX,"resource","category",1)="food"
 IF TYPE'="D",TYPE'="F" SET RTN("entry",IDX,"resource","category",1)="environment"
 SET RTN("entry",IDX,"resource","type")="allergy"
 IF $GET(REAC("name"))'="" SET RTN("entry",IDX,"resource","code","text")=$GET(REAC("name"))
 IF $GET(REAC("vuid"))'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="urn:va:vuid"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=$GET(REAC("vuid"))
 IF $GET(REAC("localCode"))'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",2,"system")="urn:va:allergy-local-code"
 . SET RTN("entry",IDX,"resource","code","coding",2,"code")=$GET(REAC("localCode"))
 IF $GET(REAC("removed"))=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/allergyintolerance-verification"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="entered-in-error"
 IF $GET(REAC("removed"))'=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/allergyintolerance-verification"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="confirmed"
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical"
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="active"
 SET SEV=$$ALGSEV($GET(REAC("severity")))
 SET TAG=""
 IF SEV'="" SET TAG="low"
 IF SEV="severe" SET TAG="high"
 IF TAG'="" SET RTN("entry",IDX,"resource","criticality")=TAG
 IF +$GET(REAC("entered"))>0 SET RTN("entry",IDX,"resource","recordedDate")=$$FM2FHIR^C0FHIRBU($GET(REAC("entered")))
 DO ALGREAC(.RTN,.REAC,IDX,SEV)
 DO ALGNOTE(.RTN,.REAC,IDX)
 QUIT
 ;
ALGREAC(RTN,REAC,IDX,SEV) ; Add reaction manifestations
 NEW I,N,TXT,VUID
 SET (I,N)=0
 FOR  SET I=$ORDER(REAC("reaction",I)) Q:I<1  DO
 . SET TXT=$PIECE($GET(REAC("reaction",I)),"^")
 . SET VUID=$PIECE($GET(REAC("reaction",I)),"^",2)
 . SET N=N+1
 . IF TXT'="" SET RTN("entry",IDX,"resource","reaction",N,"manifestation",1,"text")=TXT
 . IF VUID'="" DO
 .. SET RTN("entry",IDX,"resource","reaction",N,"manifestation",1,"coding",1,"system")="urn:va:vuid"
 .. SET RTN("entry",IDX,"resource","reaction",N,"manifestation",1,"coding",1,"code")=VUID
 . IF SEV'="" SET RTN("entry",IDX,"resource","reaction",N,"severity")=SEV
 QUIT
 ;
ALGNOTE(RTN,REAC,IDX) ; Add allergy comments as note entries
 NEW I,N,TXT
 SET (I,N)=0
 FOR  SET I=$ORDER(REAC("comment",I)) Q:I<1  DO
 . SET N=N+1
 . SET TXT=$PIECE($GET(REAC("comment",I)),"^",4)
 . IF TXT'="" SET RTN("entry",IDX,"resource","note",N,"text")=TXT
 . IF +$PIECE($GET(REAC("comment",I)),"^",2)>0 SET RTN("entry",IDX,"resource","note",N,"time")=$$FM2FHIR^C0FHIRBU($PIECE($GET(REAC("comment",I)),"^",2))
 . IF $PIECE($GET(REAC("comment",I)),"^",1)'="" SET RTN("entry",IDX,"resource","note",N,"authorString")=$PIECE($GET(REAC("comment",I)),"^",1)
 QUIT
 ;
ALGSEV(X) ; Map allergy severity to FHIR reaction severity
 NEW Y
 SET Y=$$UPCASE($GET(X))
 IF Y["SEVERE" QUIT "severe"
 IF Y["MODERATE" QUIT "moderate"
 IF Y["MILD" QUIT "mild"
 QUIT ""
 ;
GETMED(RTN,DFN,BEG,END,MAX) ; Add MedicationRequest resources
 NEW CNT,ID,MED,ORIFN,PS0,VPRN
 DO ENSUREENV
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=$GET(END)
 IF END="" SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 KILL ^TMP("PS",$J),^TMP("VPRPS",$J)
 DO OCL^PSOORRL(DFN,BEG,END)
 MERGE ^TMP("VPRPS",$J)=^TMP("PS",$J)
 SET (CNT,VPRN)=0
 FOR  SET VPRN=$ORDER(^TMP("VPRPS",$J,VPRN)) Q:VPRN<1!(CNT'<MAX)  DO
 . SET PS0=$GET(^TMP("VPRPS",$J,VPRN,0))
 . SET ID=$PIECE(PS0,"^"),ORIFN=+$PIECE(PS0,"^",8)
 . IF ORIFN<1 QUIT
 . IF '$DATA(^OR(100,ORIFN,0)) QUIT
 . KILL MED
 . DO EN1^VPRDPSOR(ORIFN,.MED)
 . IF '$DATA(MED) QUIT
 . DO SETMED(.RTN,.MED,DFN)
 . SET CNT=CNT+1
 KILL ^TMP("VPRPS",$J),^TMP("PS",$J),^TMP($J,"PSOI")
 QUIT
 ;
SETMED(RTN,MED,DFN) ; Map one VPR medication entry to FHIR MedicationRequest
 NEW DOSE,ID,IDX,NAME,STAT
 SET ID=+$GET(MED("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"MedicationRequest","M"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="MedicationRequest"
 SET RTN("entry",IDX,"resource","id")="M"_ID
 SET RTN("entry",IDX,"resource","intent")="order"
 SET STAT=$$MEDSTAT($GET(MED("status")))
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","subject","reference")=$$PATREF^C0FHIRBU(DFN)
 SET NAME=$GET(MED("name"))
 IF NAME'="" SET RTN("entry",IDX,"resource","medicationCodeableConcept","text")=NAME
 DO MEDCODE(.RTN,.MED,IDX)
 IF +$GET(MED("ordered"))>0 SET RTN("entry",IDX,"resource","authoredOn")=$$FM2FHIR^C0FHIRBU($GET(MED("ordered")))
 IF +$GET(MED("ordered"))'>0,+$GET(MED("start"))>0 SET RTN("entry",IDX,"resource","authoredOn")=$$FM2FHIR^C0FHIRBU($GET(MED("start")))
 IF $PIECE($GET(MED("orderingProvider")),"^",2)'="" SET RTN("entry",IDX,"resource","requester","display")=$PIECE($GET(MED("orderingProvider")),"^",2)
 IF $GET(MED("sig"))'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"text")=$GET(MED("sig"))
 SET DOSE=$GET(MED("dose",1))
 IF $PIECE(DOSE,"^",5)'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"route","text")=$PIECE(DOSE,"^",5)
 IF $PIECE(DOSE,"^",6)'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"timing","code","text")=$PIECE(DOSE,"^",6)
 IF +$GET(MED("quantity"))>0 SET RTN("entry",IDX,"resource","dispenseRequest","quantity","value")=+$GET(MED("quantity"))
 IF +$GET(MED("daysSupply"))>0 DO
 . SET RTN("entry",IDX,"resource","dispenseRequest","expectedSupplyDuration","value")=+$GET(MED("daysSupply"))
 . SET RTN("entry",IDX,"resource","dispenseRequest","expectedSupplyDuration","unit")="days"
 IF +$GET(MED("fillsAllowed"))>0 SET RTN("entry",IDX,"resource","dispenseRequest","numberOfRepeatsAllowed")=+$GET(MED("fillsAllowed"))
 QUIT
 ;
MEDCODE(RTN,MED,IDX) ; Add medication coding details when available
 NEW PROD,VUID
 SET PROD=$GET(MED("product",1))
 SET VUID=$PIECE(PROD,"^",3)
 IF VUID'="" DO
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"system")="urn:va:vuid"
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"code")=VUID
 IF $PIECE(PROD,"^",2)'="" SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"display")=$PIECE(PROD,"^",2)
 IF $PIECE(PROD,"^",1)'="" DO
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",2,"system")="urn:va:drug"
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",2,"code")=$PIECE(PROD,"^",1)
 QUIT
 ;
MEDSTAT(X) ; Map VPR medication status to FHIR MedicationRequest status
 NEW Y
 SET Y=$$UPCASE($GET(X))
 IF Y="ACTIVE" QUIT "active"
 IF Y="HOLD" QUIT "on-hold"
 IF Y="HISTORICAL" QUIT "completed"
 IF Y="NOT ACTIVE" QUIT "stopped"
 QUIT "unknown"
 ;
GETIMM(RTN,DFN,BEG,END,MAX) ; Add Immunization resources
 NEW CNT,IMM,VPRIDT,VPRN
 DO ENSUREENV
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 DO SORT^VPRDPXIM(DFN,BEG,END)
 SET (CNT,VPRIDT)=0
 FOR  SET VPRIDT=$ORDER(^TMP("VPRIMM",$J,VPRIDT)) Q:VPRIDT<1!(CNT'<MAX)  DO
 . SET VPRN=0
 . FOR  SET VPRN=$ORDER(^TMP("VPRIMM",$J,VPRIDT,VPRN)) Q:VPRN<1!(CNT'<MAX)  DO
 .. KILL IMM
 .. DO EN1^VPRDPXIM(VPRN,.IMM)
 .. IF '$DATA(IMM) QUIT
 .. DO SETIMM(.RTN,.IMM,DFN)
 .. SET CNT=CNT+1
 KILL ^TMP("VPRIMM",$J),^TMP("PXKENC",$J)
 QUIT
 ;
SETIMM(RTN,IMM,DFN) ; Map one VPR immunization entry to FHIR Immunization
 NEW CVX,DATE,DOSE,ID,IDX,SRC,SITE,STAT,UNITS
 SET ID=+$GET(IMM("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Immunization","IM"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Immunization"
 SET RTN("entry",IDX,"resource","id")="IM"_ID
 SET STAT=$S(+$GET(IMM("contraindicated"))=1:"not-done",1:"completed")
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","patient","reference")=$$PATREF^C0FHIRBU(DFN)
 SET DATE=+$GET(IMM("administered"))
 IF DATE>0 SET RTN("entry",IDX,"resource","occurrenceDateTime")=$$FM2FHIR^C0FHIRBU(DATE)
 IF $GET(IMM("name"))'="" SET RTN("entry",IDX,"resource","vaccineCode","text")=$GET(IMM("name"))
 SET CVX=$GET(IMM("cvx"))
 IF CVX'="" DO
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"system")="http://hl7.org/fhir/sid/cvx"
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"code")=$PIECE(CVX,"^")
 . IF $PIECE(CVX,"^",2)'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"display")=$PIECE(CVX,"^",2)
 IF $GET(IMM("cpt"))'="" DO
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"code")=$PIECE($GET(IMM("cpt")),"^")
 . IF $PIECE($GET(IMM("cpt")),"^",2)'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"display")=$PIECE($GET(IMM("cpt")),"^",2)
 IF +$GET(IMM("encounter"))>0 SET RTN("entry",IDX,"resource","encounter","reference")=$$REFURL^C0FHIRBU("Encounter","E"_+$GET(IMM("encounter")))
 IF $PIECE($GET(IMM("provider")),"^",2)'="" SET RTN("entry",IDX,"resource","performer",1,"actor","display")=$PIECE($GET(IMM("provider")),"^",2)
 IF $PIECE($GET(IMM("orderingProvider")),"^",2)'="" SET RTN("entry",IDX,"resource","performer",2,"actor","display")=$PIECE($GET(IMM("orderingProvider")),"^",2)
 IF $PIECE($GET(IMM("documentedBy")),"^",2)'="" SET RTN("entry",IDX,"resource","performer",3,"actor","display")=$PIECE($GET(IMM("documentedBy")),"^",2)
 IF $GET(IMM("lot"))'="" SET RTN("entry",IDX,"resource","lotNumber")=$GET(IMM("lot"))
 IF +$GET(IMM("expirationDate"))>0 SET RTN("entry",IDX,"resource","expirationDate")=$PIECE($$FM2FHIR^C0FHIRBU($GET(IMM("expirationDate"))),"T",1)
 IF $GET(IMM("manufacturer"))'="" SET RTN("entry",IDX,"resource","manufacturer","display")=$GET(IMM("manufacturer"))
 SET SRC=$GET(IMM("route"))
 IF SRC'="" SET RTN("entry",IDX,"resource","route","text")=$SELECT($PIECE(SRC,"^",2)'="":$PIECE(SRC,"^",2),1:SRC)
 SET SITE=$GET(IMM("bodySite"))
 IF SITE'="" SET RTN("entry",IDX,"resource","site","text")=$SELECT($PIECE(SITE,"^",2)'="":$PIECE(SITE,"^",2),1:SITE)
 SET DOSE=$GET(IMM("dose")),UNITS=$GET(IMM("units"))
 IF $$ISNUM(DOSE) DO
 . SET RTN("entry",IDX,"resource","doseQuantity","value")=+DOSE
 . IF UNITS'="" SET RTN("entry",IDX,"resource","doseQuantity","unit")=UNITS
 IF $GET(IMM("series"))'="" SET RTN("entry",IDX,"resource","protocolApplied",1,"seriesDosesString")=$GET(IMM("series"))
 IF $GET(IMM("reaction"))'="" SET RTN("entry",IDX,"resource","note",1,"text")="Reaction: "_$GET(IMM("reaction"))
 IF $GET(IMM("comment"))'="" SET RTN("entry",IDX,"resource","note",2,"text")=$GET(IMM("comment"))
 IF $GET(IMM("source"))'="" DO
 . SET SRC=$SELECT($PIECE($GET(IMM("source")),"^",2)'="":$PIECE($GET(IMM("source")),"^",2),$PIECE($GET(IMM("source")),"^",1)'="":$PIECE($GET(IMM("source")),"^",1),1:$GET(IMM("source")))
 . SET RTN("entry",IDX,"resource","note",3,"text")="Source: "_SRC
 QUIT
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations (chemistry + micro)
 NEW CNT,LRDFN
 DO ENSUREENV
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
 DO GETLBSUB(.RTN,DFN,BEG,END,MAX,"CH",.CNT,LRDFN)
 IF CNT<MAX DO GETLBSUB(.RTN,DFN,BEG,END,MAX,"MI",.CNT,LRDFN)
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN) ; Extract one lab subdomain
 NEW LIM,LINE,ORD,VPRIDT,VPRP
 SET LIM=MAX-CNT
 IF LIM<1 QUIT
 KILL ^TMP("LRRR",$J,DFN)
 DO RR^LR7OR1(DFN,,BEG,END,SUB,,,LIM)
 SET VPRIDT=0
 FOR  SET VPRIDT=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT)) Q:VPRIDT<1!(CNT'<MAX)  DO
 . SET VPRP=0
 . FOR  SET VPRP=$ORDER(^TMP("LRRR",$J,DFN,SUB,VPRIDT,VPRP)) Q:VPRP<1!(CNT'<MAX)  DO
 .. SET ORD=""
 .. SET LINE=$S(SUB="CH":$$CH^VPRDLR,1:$$MI^VPRDLR)
 .. IF LINE="" QUIT
 .. DO SETLAB(.RTN,LINE,SUB,DFN,$GET(ORD))
 .. SET CNT=CNT+1
 KILL ^TMP("LRRR",$J,DFN)
 QUIT
 ;
SETLAB(RTN,LINE,SUB,DFN,ORD) ; Map one VPR lab line to FHIR Observation
 NEW ID,IDX,LOINC,NAME,RES,RID,UNIT,VUID
 SET ID=$PIECE($GET(LINE),"^",1)
 IF ID="" QUIT
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
 IF $$ISNUM(RES) DO  QUIT
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+RES
 . IF UNIT'="" SET RTN("entry",IDX,"resource","valueQuantity","unit")=UNIT
 . DO LABMETA(.RTN,IDX,LINE,ORD)
 IF RES'="" SET RTN("entry",IDX,"resource","valueString")=RES
 DO LABMETA(.RTN,IDX,LINE,ORD)
 QUIT
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
GETFHIR(RTN,FILTER) ; Web service entry point
 ; FILTER contains URL parameters, for example FILTER("dfn")=12345
 ; RTN returns JSON output nodes from ENCODE^XLFJSON
 NEW ERR,REQ,TMP
 DO ENSUREENV
 KILL RTN
 DO MAPFILT(.FILTER,.REQ)
 IF $GET(REQ("DFN"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Missing required URL parameter: dfn",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 SET REQ("MODE")=$$REQMODE(.REQ)
 IF $GET(REQ("MODE"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Cannot determine request mode from URL parameters",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 DO GETBNDLJ(.REQ,.RTN,.ERR)
 IF $DATA(ERR) DO
 . DO ERR^C0FHIRBU("JSON encoding failed in ENCODE^XLFJSON",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 QUIT
 ;
GETBNDL(REQ,OUT) ; Return one Bundle response structure for a request
 ; REQ("MODE")="ENCOUNTER" or "DATERANGE"
 ; REQ(...) contains request parameters (DFN, encounter/date filters, etc.)
 NEW MODE
 DO ENSUREENV
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" DO BYENC^C0FHIRBU(.REQ,.OUT) QUIT
 IF MODE="DATERANGE" DO BYDATE^C0FHIRBU(.REQ,.OUT) QUIT
 DO ERR^C0FHIRBU("Unsupported bundle mode: "_MODE,.OUT)
 QUIT
 ;
GETBNDLJ(REQ,OUT,ERR) ; Return one Bundle response encoded as JSON
 ; OUT returns JSON output nodes from ENCODE^XLFJSON
 ; ERR returns encoder errors, if any
 NEW BUNDLE
 DO GETBNDL(.REQ,.BUNDLE)
 DO TOJSON^C0FHIRBU(.BUNDLE,.OUT,.ERR)
 QUIT
 ;
MAPFILT(FILTER,REQ) ; Map URL parameters into request structure
 NEW ENDVAL,STARTVAL
 KILL REQ
 SET REQ("DFN")=$SELECT($GET(FILTER("dfn"))'="":$GET(FILTER("dfn")),1:$GET(FILTER("DFN")))
 SET REQ("ENCOUNTER")=$SELECT($GET(FILTER("encounter"))'="":$GET(FILTER("encounter")),1:$GET(FILTER("ENCOUNTER")))
 SET STARTVAL=$$PARSEFM($SELECT($GET(FILTER("start"))'="":$GET(FILTER("start")),1:$GET(FILTER("START"))))
 IF STARTVAL'="" SET REQ("START_DT")=STARTVAL
 SET ENDVAL=$$PARSEFM($SELECT($GET(FILTER("end"))'="":$GET(FILTER("end")),1:$GET(FILTER("END"))))
 IF ENDVAL'="" SET REQ("END_DT")=ENDVAL
 SET REQ("MODE")=$$UPCASE($SELECT($GET(FILTER("mode"))'="":$GET(FILTER("mode")),1:$GET(FILTER("MODE"))))
 SET REQ("MAX")=$SELECT($GET(FILTER("max"))'="":+$GET(FILTER("max")),1:+$GET(FILTER("MAX")))
 QUIT
 ;
REQMODE(REQ) ; Resolve request mode from mapped parameters
 NEW MODE
 SET MODE=$GET(REQ("MODE"))
 IF MODE="ENCOUNTER" QUIT "ENCOUNTER"
 IF MODE="DATERANGE" QUIT "DATERANGE"
 IF MODE'="" QUIT ""
 IF $GET(REQ("ENCOUNTER"))'="" QUIT "ENCOUNTER"
 IF $GET(REQ("START_DT"))'="" QUIT "DATERANGE"
 IF $GET(REQ("END_DT"))'="" QUIT "DATERANGE"
 ; Default behavior: if no encounter/date filters are supplied,
 ; return all encounters for the patient.
 QUIT "DATERANGE"
 ;
UPCASE(X) ; Upper-case helper without external dependencies
 NEW C,I,Y
 SET Y=""
 FOR I=1:1:$LENGTH($GET(X)) DO
 . SET C=$EXTRACT(X,I)
 . IF C?1L SET C=$CHAR($ASCII(C)-32)
 . SET Y=Y_C
 QUIT Y
 ;
GENDER(X) ; Map VistA sex code to FHIR gender
 SET X=$$UPCASE($GET(X))
 IF X="M" QUIT "male"
 IF X="F" QUIT "female"
 IF X="U" QUIT "unknown"
 QUIT "unknown"
 ;
TRIM(X) ; Remove leading and trailing spaces
 NEW Y
 SET Y=$GET(X)
 FOR  QUIT:$EXTRACT(Y,1)'=" "  SET Y=$EXTRACT(Y,2,$LENGTH(Y))
 FOR  QUIT:$EXTRACT(Y,$LENGTH(Y))'=" "  SET Y=$EXTRACT(Y,1,$LENGTH(Y)-1)
 QUIT Y
 ;
ENSUREENV ; Ensure legacy VPR runtime variables are available
 ; Many legacy VPR/PX routines assume U and DT are defined.
 IF $GET(U)="" SET U="^"
 IF '$DATA(DT) SET DT=$$DT^XLFDT
 QUIT
 ;
PARSEFM(X) ; Parse URL date value to FileMan date/time
 ; Supports direct FM numbers and expressions like T, T-30, NOW.
 NEW %DT,Y
 SET X=$$TRIM($GET(X))
 IF X="" QUIT ""
 IF X?1.N QUIT X
 SET %DT="TS"
 DO ^%DT
 IF Y>0 QUIT Y
 QUIT ""
