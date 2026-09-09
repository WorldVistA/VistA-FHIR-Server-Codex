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
 DO GETENCDX(.RTN,DFN,BEG,END,MAX,.CNT)
 QUIT
 ;
GETENCDX(RTN,DFN,BEG,END,MAX,CNT) ; Add encounter-diagnosis Conditions from V POV
 NEW AABEG,AAEND,IDT,IEN,VDT,VID,X
 SET DFN=+$GET(DFN) QUIT:DFN<1
 SET BEG=+$GET(BEG) IF BEG<1 SET BEG=1410101
 SET END=$GET(END) IF END="" SET END=4141015
 IF END'["." SET END=END_".24"
 SET MAX=+$GET(MAX) IF MAX<1 SET MAX=200
 SET CNT=+$GET(CNT)
 SET VDT=END
 FOR  SET VDT=$ORDER(^AUPNVSIT("AET",DFN,VDT),-1) Q:VDT=""!(VDT<BEG)!(CNT'<MAX)  DO
 . NEW LOC SET LOC=0
 . FOR  SET LOC=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC)) Q:LOC=""!(LOC<1)!(CNT'<MAX)  DO
 .. SET VID=0
 .. FOR  SET VID=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC,"P",VID)) Q:VID=""!(VID<1)!(CNT'<MAX)  DO
 ... DO ADDPVIS(.RTN,VID,DFN,.CNT,MAX)
 SET X=BEG,AABEG=(9999999-$PIECE(END,".")),AAEND=(9999999-$PIECE(X,"."))_".2359"
 SET IDT=AABEG
 FOR  SET IDT=$ORDER(^AUPNVSIT("AA",DFN,IDT)) Q:IDT<1!(IDT>AAEND)!(CNT'<MAX)  DO
 . SET VID=0
 . FOR  SET VID=$ORDER(^AUPNVSIT("AA",DFN,IDT,VID)) Q:VID<1!(CNT'<MAX)  DO
 .. IF $PIECE($GET(^AUPNVSIT(VID,150)),"^",3)'="","CS"[$PIECE($GET(^AUPNVSIT(VID,150)),"^",3) QUIT
 .. DO ADDPVIS(.RTN,VID,DFN,.CNT,MAX)
 QUIT
 ;
ADDPVIS(RTN,VID,DFN,CNT,MAX) ; Add V POV Conditions for one visit
 NEW IEN
 SET VID=+$GET(VID) QUIT:VID<1
 SET IEN=0
 FOR  SET IEN=$ORDER(^AUPNVPOV("AD",VID,IEN)) Q:IEN<1!(CNT'<MAX)  DO
 . IF $DATA(RTN("index","Condition|CED"_IEN)) QUIT
 . DO SETENCDX(.RTN,IEN,VID,DFN)
 . IF $DATA(RTN("index","Condition|CED"_IEN)) SET CNT=+$GET(CNT)+1
 QUIT
 ;
SETENCDX(RTN,IEN,VID,DFN) ; Map one V POV row to encounter-diagnosis Condition
 NEW CODE,CSI,DISP,FHIRDT,IDX,NARR,RID,SYS,VDT,X0
 SET IEN=+$GET(IEN),VID=+$GET(VID),DFN=+$GET(DFN)
 IF IEN<1!(VID<1)!(DFN<1) QUIT
 SET X0=$GET(^AUPNVPOV(IEN,0))
 IF +$PIECE(X0,"^",2)'=DFN QUIT
 IF +$PIECE(X0,"^",3)>0 SET VID=+$PIECE(X0,"^",3)
 SET CODE=$$CODEC^ICDEX(80,+$PIECE(X0,"^"))
 IF CODE="" QUIT
 IF $EXTRACT(CODE,$LENGTH(CODE))="." SET CODE=$EXTRACT(CODE,1,$LENGTH(CODE)-1)
 SET CSI=+$$CSI^ICDEX(80,+$PIECE(X0,"^"))
 SET SYS=$SELECT(CSI=30:"http://hl7.org/fhir/sid/icd-10-cm",1:"http://hl7.org/fhir/sid/icd-9-cm")
 SET DISP=$$VSTD^ICDEX(+$PIECE(X0,"^"),+$HOROLOG)
 SET NARR=$PIECE($GET(^AUTNPOV(+$PIECE(X0,"^",4),0)),"^")
 IF NARR="" SET NARR=DISP
 IF NARR="" SET NARR=CODE
 SET RID="CED"_IEN
 DO ADDRES^C0FHIRBU(.RTN,"Condition",RID,.IDX)
 IF IDX="" QUIT
 SET RTN("entry",IDX,"resource","resourceType")="Condition"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-condition-encounter-diagnosis"
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">Encounter diagnosis: "_$$XMLESC(NARR)_"</div>"
 ; Finished historical visit diagnoses are point-in-time; mark resolved with abatement.
 SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-clinical"
 SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="resolved"
 SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-ver-status"
 SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="confirmed"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="encounter-diagnosis"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Encounter Diagnosis"
 SET RTN("entry",IDX,"resource","category",1,"text")="Encounter Diagnosis"
 SET RTN("entry",IDX,"resource","code","coding",1,"system")=SYS
 SET RTN("entry",IDX,"resource","code","coding",1,"code")=CODE
 IF DISP'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=DISP
 SET RTN("entry",IDX,"resource","code","text")=NARR
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_DFN
 SET RTN("entry",IDX,"resource","encounter","reference")="Encounter/E"_VID
 SET VDT=+$PIECE($GET(^AUPNVSIT(VID,0)),"^")
 IF VDT<1 SET VDT=+$PIECE($GET(^AUPNVSIT(VID,0)),"^",2)
 IF VDT>0 DO
 . SET FHIRDT=$$FM2FHIR^C0FHIRBU(VDT)
 . SET RTN("entry",IDX,"resource","onsetDateTime")=FHIRDT
 . SET RTN("entry",IDX,"resource","abatementDateTime")=FHIRDT
 . SET RTN("entry",IDX,"resource","recordedDate")=FHIRDT
 . SET RTN("entry",IDX,"resource","extension",1,"url")="http://hl7.org/fhir/StructureDefinition/condition-assertedDate"
 . SET RTN("entry",IDX,"resource","extension",1,"valueDateTime")=FHIRDT
 ; Ensure the referenced Encounter is present for Inferno reference resolution.
 IF '$DATA(RTN("index","Encounter|E"_VID)) DO GETENC^C0FHIR(.RTN,VID,DFN)
 QUIT
 ;
XMLESC(X) ; Escape XML special characters for narrative text
 NEW Y
 SET Y=$GET(X)
 IF Y["&" SET Y=$PIECE(Y,"&",1)_"&amp;"_$PIECE(Y,"&",2,99)
 IF Y["<" SET Y=$PIECE(Y,"<",1)_"&lt;"_$PIECE(Y,"<",2,99)
 IF Y[">" SET Y=$PIECE(Y,">",1)_"&gt;"_$PIECE(Y,">",2,99)
 QUIT Y
 ;
SETCOND(RTN,PROB,DFN) ; Map one VPR problem to a FHIR Condition resource
 NEW ADT,CODESYS,ID,IDX,SCT,STATUS,TXT
 SET ID=+$GET(PROB("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Condition","C"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Condition"
 SET RTN("entry",IDX,"resource","id")="C"_ID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-condition-problems-health-concerns"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="problem-list-item"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Problem List Item"
 SET RTN("entry",IDX,"resource","category",1,"text")="Problem List Item"
 ; USQC MS slice Condition.category:screening-assessment — emit once per patient graph.
 IF '$DATA(RTN("index","cond-sa")) DO
 . SET RTN("index","cond-sa")=1
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"system")="http://hl7.org/fhir/us/core/CodeSystem/us-core-category"
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"code")="sdoh"
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"display")="SDOH"
 . SET RTN("entry",IDX,"resource","category",2,"text")="SDOH"
 SET STATUS=$PIECE($GET(PROB("status")),"^")
 ; con-4: abatement requires clinicalStatus inactive|resolved|remission.
 ; Prefer resolved when a resolved date exists, even if VPR status is still A.
 SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-clinical"
 IF +$GET(PROB("resolved"))>0!(STATUS="R") DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="resolved"
 IF STATUS="I",+$GET(PROB("resolved"))<1 DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="inactive"
 IF STATUS="A",+$GET(PROB("resolved"))<1 DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="active"
 IF '$DATA(RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")) DO
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")=$SELECT(STATUS="I":"inactive",1:"active")
 IF $GET(PROB("unverified"))=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-ver-status"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="unconfirmed"
 IF $GET(PROB("unverified"))'=1 DO
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-ver-status"
 . SET RTN("entry",IDX,"resource","verificationStatus","coding",1,"code")="confirmed"
 ; USQC USCDI+ Quality Must Support: Condition.severity (SNOMED VS)
 SET RTN("entry",IDX,"resource","severity","coding",1,"system")="http://snomed.info/sct"
 SET RTN("entry",IDX,"resource","severity","coding",1,"code")="6736007"
 SET RTN("entry",IDX,"resource","severity","coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","severity","coding",1,"display")="Moderate (severity modifier)"
 SET RTN("entry",IDX,"resource","severity","text")="Moderate"
 SET TXT=$GET(PROB("name"))
 IF TXT'="" SET RTN("entry",IDX,"resource","code","text")=TXT
 ; Prefer numeric SNOMED ids. VPR may park ICD codes in sctc — only pure
 ; numerics are SCT. Never run CONDSYS on the code value ("10" substring bug).
 SET SCT=$GET(PROB("sctc"))
 IF SCT'="",SCT'?1.N SET SCT=""
 IF SCT="" SET SCT=$$SCTFROM($GET(PROB("icd")),TXT)
 IF SCT'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://snomed.info/sct"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=SCT
 . SET RTN("entry",IDX,"resource","code","coding",1,"code","\s")=""
 . ; Never attach ICD display text to an SCT coding (Inferno display binding).
 . IF $GET(PROB("sctt"))'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$GET(PROB("sctt"))
 . E  IF $$SCTDISP(TXT)'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$$SCTDISP(TXT)
 IF SCT="" DO
 . SET SCT=$SELECT($GET(PROB("icd"))'="":$GET(PROB("icd")),$GET(PROB("sctc"))'="":$GET(PROB("sctc")),1:"")
 . IF SCT="" QUIT
 . SET CODESYS=$$CODESYS(SCT,$GET(PROB("codingSystem")))
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")=CODESYS
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=SCT
 . SET RTN("entry",IDX,"resource","code","coding",1,"code","\s")=""
 . IF $GET(PROB("icdd"))'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$GET(PROB("icdd"))
 . E  IF $GET(PROB("sctt"))'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=$GET(PROB("sctt"))
 IF +$GET(PROB("onset"))>0 SET RTN("entry",IDX,"resource","onsetDateTime")=$$FM2FHIR^C0FHIRBU($GET(PROB("onset")))
 IF +$GET(PROB("entered"))>0 SET RTN("entry",IDX,"resource","recordedDate")=$$FM2FHIR^C0FHIRBU($GET(PROB("entered")))
 IF +$GET(PROB("resolved"))>0 DO
 . SET RTN("entry",IDX,"resource","abatementDateTime")=$$FM2FHIR^C0FHIRBU($GET(PROB("resolved")))
 . ; Safety net for con-4 if status mapping above missed.
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"system")="http://terminology.hl7.org/CodeSystem/condition-clinical"
 . SET RTN("entry",IDX,"resource","clinicalStatus","coding",1,"code")="resolved"
 ; assertedDate MS extension: prefer entered, else onset.
 SET ADT=+$GET(PROB("entered"))
 IF ADT<1 SET ADT=+$GET(PROB("onset"))
 IF ADT>0 DO
 . SET RTN("entry",IDX,"resource","extension",1,"url")="http://hl7.org/fhir/StructureDefinition/condition-assertedDate"
 . SET RTN("entry",IDX,"resource","extension",1,"valueDateTime")=$$FM2FHIR^C0FHIRBU(ADT)
 DO CONDNOTE(.RTN,.PROB,IDX)
 QUIT
 ;
SCTDISP(TXT) ; $$ - problem name without trailing "(SCT nnn)" for coding.display
 NEW T
 SET T=$$TRIM^C0FHIR($GET(TXT))
 IF T[" (SCT " SET T=$$TRIM^C0FHIR($PIECE(T," (SCT ",1))
 IF T["(SCT " SET T=$$TRIM^C0FHIR($PIECE(T,"(SCT ",1))
 QUIT T
 ;
CODESYS(CODE,TOKEN) ; $$ - FHIR Coding.system from code shape + optional VPR token
 NEW C,Y
 SET C=$$TRIM^C0FHIR($GET(CODE)),Y=$$UPCASE^C0FHIR($GET(TOKEN))
 IF C?.N QUIT "http://snomed.info/sct"
 IF Y["SNOMED"!(Y="SCT")!(Y["SNM") QUIT "http://snomed.info/sct"
 ; ICD-10-CM style: starts with a letter (F45.22, R97.20, I10)
 IF C?1U.E QUIT "http://hl7.org/fhir/sid/icd-10-cm"
 IF Y["ICD-10"!(Y["ICD10")!(Y["10-CM")!(Y="I10") QUIT "http://hl7.org/fhir/sid/icd-10-cm"
 IF Y["ICD" QUIT "http://hl7.org/fhir/sid/icd-9-cm"
 IF C?1.N1"."1.N QUIT "http://hl7.org/fhir/sid/icd-9-cm"
 QUIT "http://hl7.org/fhir/sid/icd-9-cm"
 ;
CONDSYS(X) ; Map VPR coding system token to FHIR system URL
 QUIT $$CODESYS("",$GET(X))
 ;
SCTFROM(CODE,TXT) ; $$ - SNOMED code from misfiled ICD field or "(SCT n)" text
 NEW P,X
 SET X=$$TRIM^C0FHIR($GET(CODE))
 IF X?1.N,$LENGTH(X)>5 QUIT X
 SET P=$FIND($$UPCASE^C0FHIR($GET(TXT)),"(SCT ")
 IF P<1 QUIT ""
 SET X=$EXTRACT($GET(TXT),P,P+31)
 SET X=$PIECE($PIECE(X,")",1)," ",1)
 SET X=$$TRIM^C0FHIR(X)
 IF X?1.N,$LENGTH(X)>5 QUIT X
 QUIT ""
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
 IF $$RPMS^C0FWVIT() DO  QUIT
 . DO GETRMSR^C0FWVIT(.RTN,DFN,BEG,END,MAX)
 . DO GETSMOK(.RTN,DFN,BEG,END)
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
 DO GETSMOK(.RTN,DFN,BEG,END)
 QUIT
 ;
GETSMOK(RTN,DFN,BEG,END) ; Emit US Core smoking-status Observation from V Health Factors
 NEW BEST,CMT,DT,HFIEN,IEN,NAME,VID,X0
 SET DFN=+$GET(DFN) QUIT:DFN<1
 SET BEG=+$GET(BEG) IF BEG<1 SET BEG=1410101
 SET END=$GET(END) IF END="" SET END=4141015 IF END'["." SET END=END_".24"
 SET (BEST,IEN)=""
 FOR  SET IEN=$ORDER(^AUPNVHF("C",DFN,IEN)) QUIT:IEN<1  DO
 . SET X0=$GET(^AUPNVHF(IEN,0)) QUIT:X0=""
 . SET HFIEN=+X0,VID=+$PIECE(X0,U,3)
 . SET NAME=$PIECE($GET(^AUTTHF(HFIEN,0)),U) QUIT:NAME=""
 . QUIT:$$SMOKMAP(NAME)=""
 . SET DT=0 IF VID>0 SET DT=+$PIECE($GET(^AUPNVSIT(VID,0)),U)
 . IF DT>0,(DT<BEG!(DT>END)) QUIT
 . IF BEST'="",DT'>+$PIECE(BEST,U) QUIT
 . SET CMT=$PIECE($GET(^AUPNVHF(IEN,811)),U)
 . SET BEST=DT_U_IEN_U_NAME_U_VID_U_CMT
 QUIT:BEST=""
 DO SETSMOK(.RTN,DFN,BEST)
 QUIT
 ;
SMOKMAP(NAME) ; $$ - SNOMED smoking-status code^display for HF name
 SET NAME=$$UPCASE^C0FHIR($$TRIM^C0FHIR($GET(NAME)))
 ; Displays must match SCT preferred terms for US Core smokingstatus validation.
 IF NAME="LCS CURRENT SMOKER"!(NAME="CURRENT SMOKER")!(NAME="ONS TOBACCO USE CURRENT") QUIT "449868002^Smokes tobacco daily"
 IF NAME="LCS FORMER SMOKER"!(NAME="PREVIOUS SMOKER")!(NAME="FORMER SMOKER - <100 LIFETIME CIGARETTES") QUIT "8517006^Ex-smoker"
 IF NAME="LCS LIFETIME NON-SMOKER"!(NAME="LIFETIME NON-SMOKER")!(NAME="LIFETIME NON-TOBACCO USER")!(NAME="ONS TOBACCO LIFETIME NON-USER") QUIT "266919005^Never smoked tobacco"
 QUIT ""
 ;
SETSMOK(RTN,DFN,BEST) ; Build one smoking-status Observation; BEST=DT^IEN^NAME^VID^CMT
 NEW CMT,CODE,DISP,DT,IDX,MAP,NAME,RID,VID
 SET DFN=+$GET(DFN) QUIT:DFN<1
 SET DT=$PIECE($GET(BEST),U),RID="SMK-"_+$PIECE(BEST,U,2)
 SET NAME=$PIECE(BEST,U,3),VID=+$PIECE(BEST,U,4),CMT=$PIECE(BEST,U,5)
 SET MAP=$$SMOKMAP(NAME),CODE=$PIECE(MAP,U),DISP=$PIECE(MAP,U,2)
 QUIT:CODE=""
 IF $DATA(RTN("index","Observation|"_RID)) QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Observation",RID,.IDX) QUIT:IDX=""
 SET RTN("entry",IDX,"resource","resourceType")="Observation"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://hl7.org/fhir/us/core/StructureDefinition/us-core-smokingstatus"
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="social-history"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","code","coding",1,"code")="72166-2"
 SET RTN("entry",IDX,"resource","code","coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","code","coding",1,"display")="Tobacco smoking status NHIS"
 SET RTN("entry",IDX,"resource","code","text")="Tobacco smoking status"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_DFN
 IF DT>0 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$FM2FHIR^C0FHIRBU(DT)
 IF VID>0 SET RTN("entry",IDX,"resource","encounter","reference")="Encounter/E"_VID
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"system")="http://snomed.info/sct"
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"code")=CODE
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","valueCodeableConcept","coding",1,"display")=DISP
 SET RTN("entry",IDX,"resource","valueCodeableConcept","text")=DISP
 IF CMT'="" SET RTN("entry",IDX,"resource","note",1,"text")=NAME_": "_CMT
 QUIT
 ;
GETCP(RTN,DFN,BEG,END,MAX) ; Emit US Quality Core CarePlan from SYN CP V Health Factors
 NEW CNT,CMT,CODE,DISP,DT,HFIEN,IEN,NAME,VID,X0
 IF $GET(U)="" SET U="^"
 SET DFN=+$GET(DFN) QUIT:DFN<1
 SET BEG=+$GET(BEG) IF BEG<1 SET BEG=1410101
 SET END=$GET(END) IF END="" SET END=4141015 IF END'["." SET END=END_".24"
 SET MAX=+$GET(MAX) IF MAX<1 SET MAX=200
 SET (CNT,IEN)=0
 FOR  SET IEN=$ORDER(^AUPNVHF("C",DFN,IEN)) QUIT:IEN<1!(CNT'<MAX)  DO
 . SET X0=$GET(^AUPNVHF(IEN,0)) QUIT:X0=""
 . SET HFIEN=+X0,VID=+$PIECE(X0,U,3)
 . SET NAME=$PIECE($GET(^AUTTHF(HFIEN,0)),U) QUIT:NAME=""
 . QUIT:'$$ISCPHF(NAME)
 . SET DT=0 IF VID>0 SET DT=+$PIECE($GET(^AUPNVSIT(VID,0)),U)
 . IF DT>0,(DT<BEG!(DT>END)) QUIT
 . SET CMT=$PIECE($GET(^AUPNVHF(IEN,811)),U)
 . SET CODE=$$CPSCT(NAME),DISP=$$CPDISP(NAME)
 . DO SETCP(.RTN,DFN,IEN,NAME,VID,DT,CMT,CODE,DISP)
 . SET CNT=CNT+1
 QUIT
 ;
ISCPHF(NAME) ; $$ - true if AUTTHF name is a SYN CarePlan (not CPCAT/ACT/ADDR/GOAL)
 SET NAME=$$UPCASE^C0FHIR($$TRIM^C0FHIR($GET(NAME)))
 IF $EXTRACT(NAME,1,7)="SYN CP " QUIT 1
 QUIT 0
 ;
CPSCT(NAME) ; $$ - numeric SNOMED from "… (SCT:nnn)"; skip ASSESS-PLAN tokens
 NEW P,C
 SET NAME=$GET(NAME),P=$FIND(NAME,"(SCT:")
 IF P<1 QUIT ""
 SET C=$$TRIM^C0FHIR($PIECE($EXTRACT(NAME,P,$LENGTH(NAME)),")",1))
 IF C'?1.N QUIT ""
 QUIT C
 ;
CPDISP(NAME) ; $$ - CarePlan display text between "SYN CP " and " (SCT:"
 NEW T
 SET NAME=$GET(NAME)
 SET T=$PIECE($PIECE(NAME,"SYN CP ",2)," (SCT:",1)
 SET T=$$TRIM^C0FHIR(T)
 IF T="" SET T="Assessment and Plan of Treatment"
 QUIT T
 ;
CPSTAT(CMT) ; $$ - FHIR CarePlan status from HF comment Status: token
 NEW S,U
 SET S=$$TRIM^C0FHIR($PIECE($PIECE($GET(CMT),"Status:",2)," ",1))
 SET U=$$UPCASE^C0FHIR(S)
 IF U="DRAFT"!(U="ACTIVE")!(U="ON-HOLD")!(U="REVOKED")!(U="COMPLETED")!(U="ENTERED-IN-ERROR")!(U="UNKNOWN") QUIT $$LOW^XLFSTR(U)
 IF U="ONHOLD" QUIT "on-hold"
 IF U="ENTEREDINERROR" QUIT "entered-in-error"
 QUIT "active"
 ;
SETCP(RTN,DFN,IEN,NAME,VID,DT,CMT,CODE,DISP) ; Build one CarePlan; id CP-{AUPNVHF IEN}
 NEW DIV,EDT,IDX,RID,SDT,STAT,TXT
 SET DFN=+$GET(DFN),IEN=+$GET(IEN) QUIT:DFN<1!(IEN<1)
 SET RID="CP-"_IEN
 IF $DATA(RTN("index","CarePlan|"_RID)) QUIT
 DO ADDRES^C0FHIRBU(.RTN,"CarePlan",RID,.IDX) QUIT:IDX=""
 SET DISP=$GET(DISP) IF DISP="" SET DISP=$$CPDISP($GET(NAME))
 SET STAT=$$CPSTAT($GET(CMT))
 SET RTN("entry",IDX,"resource","resourceType")="CarePlan"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-careplan"
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","intent")="plan"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_DFN
 ; US Core / USQC Must Support AssessPlan category slice
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://hl7.org/fhir/us/core/CodeSystem/careplan-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="assess-plan"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Assessment and Plan of Treatment"
 SET RTN("entry",IDX,"resource","category",1,"text")="Assessment and Plan of Treatment"
 IF $GET(CODE)'="" DO
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"system")="http://snomed.info/sct"
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"code")=CODE
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"code","\s")=""
 . SET RTN("entry",IDX,"resource","category",2,"coding",1,"display")=DISP
 . SET RTN("entry",IDX,"resource","category",2,"text")=DISP
 IF +$GET(VID)>0 SET RTN("entry",IDX,"resource","encounter","reference")="Encounter/E"_VID
 SET SDT=$$TRIM^C0FHIR($PIECE($PIECE($GET(CMT),"Start: ",2)," ",1))
 SET EDT=$$TRIM^C0FHIR($PIECE($PIECE($GET(CMT),"End: ",2)," ",1))
 IF SDT?5.7N1".".N!(SDT?5.7N) SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(+SDT)
 IF EDT?5.7N1".".N!(EDT?5.7N),+EDT>0 SET RTN("entry",IDX,"resource","period","end")=$$FM2FHIR^C0FHIRBU(+EDT)
 IF '$DATA(RTN("entry",IDX,"resource","period","start")),+$GET(DT)>0 DO
 . SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(DT)
 SET TXT=DISP
 IF $GET(CMT)'="" SET TXT=TXT_" - "_CMT
 SET DIV="<div xmlns=""http://www.w3.org/1999/xhtml"">"_$$XMLESC(TXT)_"</div>"
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")=DIV
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
 DO VLOINC(.RTN,IDX,NAME)
 DO VPROFILE(.RTN,IDX,NAME)
 IF NAME'="" SET RTN("entry",IDX,"resource","code","text")=NAME
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 IF +$GET(VIT("taken"))>0 SET RTN("entry",IDX,"resource","effectiveDateTime")=$$FM2FHIR^C0FHIRBU($GET(VIT("taken")))
 IF +$GET(VIT("entered"))>0 SET RTN("entry",IDX,"resource","issued")=$$FM2FHIR^C0FHIRBU($GET(VIT("entered")))
 SET RES=$PIECE(M0,"^",4),UNIT=$PIECE(M0,"^",5),MRES=$PIECE(M0,"^",6),MUNT=$PIECE(M0,"^",7)
 DO BPCOMP(.RTN,IDX,NAME,RES,MRES,UNIT,MUNT)
 IF $$ISBP($GET(NAME)) QUIT
 IF UNIT="" SET UNIT=$$VDEFU(NAME)
 IF MUNT="" SET MUNT=$$VDEFU(NAME)
 IF $$ISNUM(MRES) DO  QUIT
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+MRES
 . DO QTYUNIT(.RTN,$NAME(RTN("entry",IDX,"resource","valueQuantity")),MUNT)
 IF $$ISNUM(RES) DO  QUIT
 . SET RTN("entry",IDX,"resource","valueQuantity","value")=+RES
 . DO QTYUNIT(.RTN,$NAME(RTN("entry",IDX,"resource","valueQuantity")),UNIT)
 IF RES'="" DO
 . SET RTN("entry",IDX,"resource","valueString")=RES_""
 . SET RTN("entry",IDX,"resource","valueString","\s")=""
 QUIT
 ;
VPROFILE(RTN,IDX,NAME) ; Add US Core vital profile when known
 NEW CODE,PROF
 SET CODE=$PIECE($$VLCODE($GET(NAME)),"^")
 IF CODE="85354-9" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-blood-pressure|6.1.0"
 IF CODE="8302-2" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-body-height|6.1.0"
 IF CODE="29463-7" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-body-weight|6.1.0"
 IF CODE="8310-5" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-body-temperature|6.1.0"
 IF CODE="8867-4" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-heart-rate|6.1.0"
 IF CODE="9279-1" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-respiratory-rate|6.1.0"
 IF CODE="59408-5" SET PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-pulse-oximetry|6.1.0"
 IF $GET(PROF)'="" SET RTN("entry",IDX,"resource","meta","profile",1)=PROF
 QUIT
 ;
VLOINC(RTN,IDX,NAME) ; Add LOINC coding for known VistA vital types
 NEW CODE,DISPLAY,N
 SET CODE=$$VLCODE($GET(NAME))
 IF CODE="" QUIT
 SET DISPLAY=$PIECE(CODE,"^",2),CODE=$PIECE(CODE,"^")
 SET N=$ORDER(RTN("entry",IDX,"resource","code","coding",""),-1)+1
 SET RTN("entry",IDX,"resource","code","coding",N,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","code","coding",N,"code")=CODE
 IF DISPLAY'="" SET RTN("entry",IDX,"resource","code","coding",N,"display")=DISPLAY
 IF CODE="59408-5" DO
 . SET N=$ORDER(RTN("entry",IDX,"resource","code","coding",""),-1)+1
 . SET RTN("entry",IDX,"resource","code","coding",N,"system")="http://loinc.org"
 . SET RTN("entry",IDX,"resource","code","coding",N,"code")="2708-6"
 . SET RTN("entry",IDX,"resource","code","coding",N,"display")="Oxygen saturation in Arterial blood"
 QUIT
 ;
VLCODE(NAME) ; $$ - LOINC code^display for known vital display names
 NEW X
 SET X=$$UPCASE^C0FHIR($GET(NAME))
 IF X["BLOOD"&(X["PRESSURE") QUIT "85354-9^Blood pressure panel with all children optional"
 IF X["TEMP" QUIT "8310-5^Body temperature"
 IF X["O2 SAT" QUIT "59408-5^Oxygen saturation in Arterial blood by Pulse oximetry"
 IF X["PULSE OX" QUIT "59408-5^Oxygen saturation in Arterial blood by Pulse oximetry"
 IF X["OXIM" QUIT "59408-5^Oxygen saturation in Arterial blood by Pulse oximetry"
 IF X["PULSE" QUIT "8867-4^Heart rate"
 IF X["HEART RATE" QUIT "8867-4^Heart rate"
 IF X["RESP" QUIT "9279-1^Respiratory rate"
 IF X["HEIGHT" QUIT "8302-2^Body height"
 IF X["WEIGHT" QUIT "29463-7^Body weight"
 IF X["PAIN" QUIT "72514-3^Pain severity - 0-10 verbal numeric rating [Score] - Reported"
 QUIT ""
 ;
BPCOMP(RTN,IDX,NAME,RES,MRES,UNIT,MUNT) ; Add systolic/diastolic components for paired BP values
 NEW BP,DIA,SYS,U
 IF '$$ISBP($GET(NAME)) QUIT
 SET BP=$SELECT($GET(MRES)["/":$GET(MRES),$GET(RES)["/":$GET(RES),1:"")
 IF BP="" QUIT
 SET SYS=$PIECE(BP,"/",1),DIA=$PIECE(BP,"/",2)
 IF '$$ISNUM(SYS)!('$$ISNUM(DIA)) QUIT
 SET U=$SELECT($GET(MUNT)'="":$GET(MUNT),$GET(UNIT)'="":$GET(UNIT),1:"mm[Hg]")
 SET RTN("entry",IDX,"resource","component",1,"code","coding",1,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","component",1,"code","coding",1,"code")="8480-6"
 SET RTN("entry",IDX,"resource","component",1,"code","coding",1,"display")="Systolic blood pressure"
 SET RTN("entry",IDX,"resource","component",1,"valueQuantity","value")=+SYS
 DO QTYUNIT(.RTN,$NAME(RTN("entry",IDX,"resource","component",1,"valueQuantity")),U)
 SET RTN("entry",IDX,"resource","component",2,"code","coding",1,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","component",2,"code","coding",1,"code")="8462-4"
 SET RTN("entry",IDX,"resource","component",2,"code","coding",1,"display")="Diastolic blood pressure"
 SET RTN("entry",IDX,"resource","component",2,"valueQuantity","value")=+DIA
 DO QTYUNIT(.RTN,$NAME(RTN("entry",IDX,"resource","component",2,"valueQuantity")),U)
 QUIT
 ;
QTYUNIT(RTN,NODE,UNIT) ; Populate UCUM unit fields for Quantity
 NEW CODE,U
 SET U=$$TRIM^C0FHIR($GET(UNIT)) QUIT:U=""
 SET CODE=$$UCUM(U)
 SET @NODE@("unit")=$S(CODE'="":CODE,1:U)
 IF CODE'="" SET @NODE@("system")="http://unitsofmeasure.org",@NODE@("code")=CODE
 QUIT
 ;
VDEFU(NAME) ; $$ - default UCUM unit when VistA vital unit is blank
 NEW X
 SET X=$$UPCASE^C0FHIR($GET(NAME))
 IF X["PAIN" QUIT "{score}"
 IF X["PULSE OX"!(X["OXIM")!(X["O2 SAT") QUIT "%"
 IF X["TEMP" QUIT "[degF]"
 IF X["PULSE"!(X["HEART RATE")!(X["RESP") QUIT "/min"
 IF X["HEIGHT" QUIT "cm"
 IF X["WEIGHT" QUIT "kg"
 QUIT ""
 ;
UCUM(UNIT) ; $$ - normalize common VistA/RPMS vital/lab units to UCUM code
 NEW U
 SET U=$$UPCASE^C0FHIR($$TRIM^C0FHIR($GET(UNIT)))
 IF U="KG" QUIT "kg"
 IF U="CM" QUIT "cm"
 IF U="LB"!(U="LBS") QUIT "[lb_av]"
 IF U="IN"!(U="INCH")!(U="INCHES") QUIT "[in_i]"
 IF U="MM[HG]"!(U="MMHG") QUIT "mm[Hg]"
 IF U="DEGF"!(U="F") QUIT "[degF]"
 IF U="DEGC"!(U="CEL")!(U="C") QUIT "Cel"
 IF U="%"!(U="PERCENT")!(U="PCT") QUIT "%"
 IF U="{SCORE}"!(U="SCORE") QUIT "{score}"
 IF U="/MIN"!(U="BPM")!(U="/MIN.") QUIT "/min"
 IF U="MG/DL"!(U="MG/DL.") QUIT "mg/dL"
 IF U="MMOL/L" QUIT "mmol/L"
 IF U="G/DL" QUIT "g/dL"
 IF U="MEQ/L"!(U="MEQ/L.") QUIT "meq/L"
 IF U="U/L" QUIT "U/L"
 IF U="IU/L" QUIT "[IU]/L"
 IF U="NG/ML" QUIT "ng/mL"
 IF U="UG/ML" QUIT "ug/mL"
 IF U="ML/MIN"!(U="ML/MIN/1.73M2")!(U="ML/MIN/1.73 M2") QUIT "mL/min"
 IF U="10*3/UL"!(U="K/UL")!(U="X10 3/UL")!(U="X10*3/UL")!(U="K/CMM")!(U="K/CMM.") QUIT "10*3/uL"
 IF U="10*6/UL"!(U="M/UL")!(U="X10*6/UL")!(U="M/CMM")!(U="M/CMM.") QUIT "10*6/uL"
 IF U="FL" QUIT "fL"
 IF U="PG" QUIT "pg"
 IF U="SECONDS"!(U="SEC")!(U="S") QUIT "s"
 ; Unknown units: no UCUM claim (empty). Callers keep display unit text only.
 QUIT ""
 ;
ISBP(NAME) ; $$ - true for blood pressure vital names
 NEW X
 SET X=$$UPCASE^C0FHIR($GET(NAME))
 QUIT $S(X["BLOOD"&(X["PRESSURE"):1,1:0)
 ;
ISNUM(X) ; True if X is numeric
 NEW Y
 SET Y=$$TRIM^C0FHIR($GET(X))
 IF Y="" QUIT 0
 IF Y?1.N QUIT 1
 IF Y?1"."1.N QUIT 1
 IF Y?1.N1"."1.N QUIT 1
 IF Y?1"-".N QUIT 1
 IF Y?1"-"1"."1.N QUIT 1
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
 SET RTN("entry",IDX,"resource","patient","reference")="Patient/"_+$GET(DFN)
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
 NEW AUTHOR,DT,I,TXT
 SET I=0
 FOR  SET I=$ORDER(REAC("comment",I)) Q:I<1  DO
 . SET DT=+$PIECE($GET(REAC("comment",I)),"^",2)
 . SET AUTHOR=$PIECE($GET(REAC("comment",I)),"^",1)
 . SET TXT=$PIECE($GET(REAC("comment",I)),"^",4,99)
 . DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT,DT,AUTHOR)
 QUIT
 ;
CONDNOTE(RTN,PROB,IDX) ; Add problem comments as note entries
 NEW AUTHOR,DT,I,TXT
 SET I=0
 FOR  SET I=$ORDER(PROB("comment",I)) Q:I<1  DO
 . SET DT=+$PIECE($GET(PROB("comment",I)),"^",1)
 . SET AUTHOR=$PIECE($GET(PROB("comment",I)),"^",2)
 . SET TXT=$PIECE($GET(PROB("comment",I)),"^",3,99)
 . DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT,DT,AUTHOR)
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
GETSRQ(RTN,DFN,BEG,END,MAX) ; Add ServiceRequest resources (radiology orders)
 DO GETSRQ^C0FHIRQ(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
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
