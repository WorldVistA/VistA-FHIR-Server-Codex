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
 QUIT 0
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
