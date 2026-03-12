C0FHIRD ; VAMC/JS - Domain resource builders for C0FHIR
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETCOND(RTN,DFN,BEG,END,MAX) ; Add Condition resources for patient/date range
 NEW CNT,I,IEN,ONSET,PLIST,PROB
 DO ENVINIT^C0FHIR
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
 SET Y=$$UPCASE^C0FHIR($GET(X))
 IF Y["10" QUIT "http://hl7.org/fhir/sid/icd-10-cm"
 IF Y["SNOMED" QUIT "http://snomed.info/sct"
 QUIT "http://hl7.org/fhir/sid/icd-9-cm"
 ;
GETOBS(RTN,DFN,BEG,END,MAX) ; Add Observation resources (vitals) for patient/date range
 NEW CNT,GMRVSTR,IDT,IEN,TYPE,VIT
 DO ENVINIT^C0FHIR
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
 DO ENVINIT^C0FHIR
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
 SET Y=$$UPCASE^C0FHIR($GET(X))
 IF Y["SEVERE" QUIT "severe"
 IF Y["MODERATE" QUIT "moderate"
 IF Y["MILD" QUIT "mild"
 QUIT ""
 ;
GETMED(RTN,DFN,BEG,END,MAX) ; Add MedicationRequest resources
 DO GETMED^C0FHIRM(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETMED(RTN,MED,DFN) ; Map one VPR medication entry to FHIR MedicationRequest
 DO SETMED^C0FHIRM(.RTN,.MED,$GET(DFN))
 QUIT
 ;
MEDCODE(RTN,MED,IDX) ; Add medication coding details when available
 DO MEDCODE^C0FHIRM(.RTN,.MED,$GET(IDX))
 QUIT
 ;
MEDSTAT(X) ; Map VPR medication status to FHIR MedicationRequest status
 QUIT $$MEDSTAT^C0FHIRM($GET(X))
 ;
GETIMM(RTN,DFN,BEG,END,MAX) ; Add Immunization resources
 DO GETIMM^C0FHIRM(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETIMM(RTN,IMM,DFN) ; Map one VPR immunization entry to FHIR Immunization
 DO SETIMM^C0FHIRM(.RTN,.IMM,$GET(DFN))
 QUIT
 ;
GETPROC(RTN,DFN,BEG,END,MAX) ; Add Procedure resources
 DO GETPROC^C0FHIRP(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations (chemistry + micro)
 DO GETLAB^C0FHIRL(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN) ; Extract one lab subdomain
 DO GETLBSUB^C0FHIRL(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX),$GET(SUB),.CNT,$GET(LRDFN))
 QUIT
 ;
LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP) ; Build normalized line from ^TMP("LRRR")
 QUIT $$LABLINE^C0FHIRL($GET(SUB),+$GET(DFN),+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP))
 ;
CHLINE(LRDFN,VPRIDT,VPRP,X0) ; Return normalized chemistry line
 QUIT $$CHLINE^C0FHIRL(+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
MILINE(VPRIDT,VPRP,X0) ; Return normalized microbiology line
 QUIT $$MILINE^C0FHIRL(+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
SETLAB(RTN,LINE,SUB,DFN,ORD) ; Map one VPR lab line to FHIR Observation
 DO SETLAB^C0FHIRL(.RTN,$GET(LINE),$GET(SUB),$GET(DFN),$GET(ORD))
 QUIT
 ;
LABMETA(RTN,IDX,LINE,ORD) ; Add lab interpretation/range/order metadata
 DO LABMETA^C0FHIRL(.RTN,$GET(IDX),$GET(LINE),$GET(ORD))
 QUIT
 ;
LABDT(X) ; Convert inverse FM date piece from lab id to FHIR dateTime
 QUIT $$LABDT^C0FHIRL($GET(X))
 ;
LABID(X) ; Normalize lab id to FHIR-safe id
 QUIT $$LABID^C0FHIRL($GET(X))
 ;
