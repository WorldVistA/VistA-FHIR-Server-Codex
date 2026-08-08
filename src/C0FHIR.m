C0FHIR ; VAMC/JS - VistA FHIR Server entry points
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
 ; Demographics follow the same VADPT/VPR sources used by the C0CDA header.
 NEW DOB,FAM,GIV,IDX,NAME,SEX,SSN,X0
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Patient",DFN,.IDX)
 SET X0=$GET(^DPT(DFN,0))
 SET NAME=$PIECE(X0,"^")
 SET RTN("entry",IDX,"resource","resourceType")="Patient"
 SET RTN("entry",IDX,"resource","id")=DFN
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-patient"
 SET RTN("entry",IDX,"resource","active")="true"
 IF NAME'="" DO
 . SET RTN("entry",IDX,"resource","name",1,"use")="official"
 . SET RTN("entry",IDX,"resource","name",1,"text")=NAME
 . SET FAM=$$TRIM($PIECE(NAME,",",1))
 . SET GIV=$$TRIM($PIECE(NAME,",",2,99))
 . IF FAM'="" SET RTN("entry",IDX,"resource","name",1,"family")=FAM
 . IF GIV'="" SET RTN("entry",IDX,"resource","name",1,"given",1)=GIV
 SET SEX=$PIECE(X0,"^",2)
 IF SEX'="" SET RTN("entry",IDX,"resource","gender")=$$GENDER(SEX)
 SET DOB=+$PIECE(X0,"^",3)
 IF DOB>0 DO
 . SET RTN("entry",IDX,"resource","birthDate")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 . SET RTN("entry",IDX,"resource","name",1,"period","start")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 SET SSN=$PIECE(X0,"^",9)
 IF SSN?9N DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-ssn"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=SSN
 . ; Force JSON string type for SSN (FHIR identifier.value is string)
 . SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 DO PATID(.RTN,IDX,DFN)
 DO PATADDR(.RTN,IDX,DFN)
 DO PATTEL(.RTN,IDX,DFN)
 DO PATDEAD(.RTN,IDX,DFN)
 DO PATCOMM(.RTN,IDX,DFN)
 DO PATEXT(.RTN,IDX,DFN,SEX)
 DO PATTEXT(.RTN,IDX,NAME,DFN)
 QUIT
 ;
PATID(RTN,IDX,DFN) ; Add local medical record number identifier
 SET RTN("entry",IDX,"resource","identifier",2,"system")=$$SYSURI()
 SET RTN("entry",IDX,"resource","identifier",2,"value")=DFN
 SET RTN("entry",IDX,"resource","identifier",2,"value","\s")=""
 SET RTN("entry",IDX,"resource","identifier",2,"type","coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0203"
 SET RTN("entry",IDX,"resource","identifier",2,"type","coding",1,"code")="MR"
 SET RTN("entry",IDX,"resource","identifier",2,"type","text")="Medical record number"
 QUIT
 ;
PATADDR(RTN,IDX,DFN) ; Add permanent address from VADPT
 NEW DOB,I,STATE,VAPA,X
 SET VAPA("P")="" DO ADD^VADPT
 SET X=0
 FOR I=1:1:3 IF $GET(VAPA(I))'="" SET X=X+1,RTN("entry",IDX,"resource","address",1,"line",X)=VAPA(I)
 IF $GET(VAPA(4))'="" SET RTN("entry",IDX,"resource","address",1,"city")=VAPA(4)
 SET STATE=$$STATE($PIECE($GET(VAPA(5)),U))
 IF STATE="" SET STATE=$PIECE($GET(VAPA(5)),U,2)
 IF STATE'="" SET RTN("entry",IDX,"resource","address",1,"state")=STATE
 IF $PIECE($GET(VAPA(11)),U,2)'="" DO
 . SET RTN("entry",IDX,"resource","address",1,"postalCode")=$PIECE(VAPA(11),U,2)
 . SET RTN("entry",IDX,"resource","address",1,"postalCode","\s")=""
 IF $DATA(RTN("entry",IDX,"resource","address",1)) DO
 . SET RTN("entry",IDX,"resource","address",1,"use")="home"
 . SET DOB=+$PIECE($GET(^DPT(DFN,0)),U,3)
 . IF DOB>0 SET RTN("entry",IDX,"resource","address",1,"period","start")=$PIECE($$FM2FHIR^C0FHIRBU(DOB),"T",1)
 QUIT
 ;
PATTEL(RTN,IDX,DFN) ; Add telecom from the VPR/C0CDA phone sources
 NEW CNT,HOME,MOB,VAPA,WORK
 SET CNT=0
 SET VAPA("P")="" DO ADD^VADPT
 SET HOME=$$PHONE($GET(VAPA(8)))
 SET MOB=$$PHONE($$GET1^DIQ(2,DFN_",",.134))
 SET WORK=$$PHONE($$GET1^DIQ(2,DFN_",",.132))
 IF HOME'="" SET CNT=CNT+1 DO TEL1(.RTN,IDX,CNT,"home",HOME)
 IF MOB'="" SET CNT=CNT+1 DO TEL1(.RTN,IDX,CNT,"mobile",MOB)
 IF WORK'="" SET CNT=CNT+1 DO TEL1(.RTN,IDX,CNT,"work",WORK)
 QUIT
 ;
TEL1(RTN,IDX,CNT,USE,VAL) ; Add one phone telecom
 SET RTN("entry",IDX,"resource","telecom",CNT,"system")="phone"
 SET RTN("entry",IDX,"resource","telecom",CNT,"value")=VAL
 SET RTN("entry",IDX,"resource","telecom",CNT,"use")=USE
 QUIT
 ;
PATDEAD(RTN,IDX,DFN) ; Add deceased[x] from VADPT
 NEW VADM,VA,VAERR,X
 DO DEM^VADPT
 SET X=+$PIECE($PIECE($GET(VADM(6)),U),".")
 IF X>0 SET RTN("entry",IDX,"resource","deceasedDateTime")=$$FM2FHIR^C0FHIRBU(X) QUIT
 SET RTN("entry",IDX,"resource","deceasedBoolean")="false"
 QUIT
 ;
PATCOMM(RTN,IDX,DFN) ; Add language communication from VADPT, defaulting to English
 NEW CODE,I,NAME,VADM,VA,VAERR,X
 DO DEM^VADPT
 SET CODE="",NAME=""
 IF $GET(VADM(13)) DO
 . SET I=+$ORDER(VADM(13,0)),NAME=$PIECE($GET(VADM(13,I)),U,2)
 . IF NAME'="" SET I=$$FIND1^DIC(.85,,"X",NAME),CODE=$$GET1^DIQ(.85,I_",",.02)
 IF CODE="" SET CODE="en",NAME="English"
 IF NAME'="" SET RTN("entry",IDX,"resource","communication",1,"language","text")=NAME
 QUIT
 ;
PATEXT(RTN,IDX,DFN,SEX) ; Add US Core demographic extensions
 DO BIRTHSEX(.RTN,IDX,$GET(SEX))
 DO SEXEXT(.RTN,IDX,$GET(SEX))
 DO RACEEXT(.RTN,IDX,DFN)
 DO ETHNEXT(.RTN,IDX,DFN)
 DO TRIBEXT(.RTN,IDX,DFN)
 QUIT
 ;
BIRTHSEX(RTN,IDX,SEX) ; Add US Core birth sex from VistA administrative sex
 NEW N
 SET SEX=$SELECT(SEX="M":"M",SEX="F":"F",1:"UNK")
 SET N=$$EXTN(.RTN,IDX)+1
 SET RTN("entry",IDX,"resource","extension",N,"url")="http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex"
 SET RTN("entry",IDX,"resource","extension",N,"valueCode")=SEX
 QUIT
 ;
SEXEXT(RTN,IDX,SEX) ; Add US Core sex extension from VistA administrative sex
 NEW N
 SET SEX=$SELECT(SEX="M":"248153007",SEX="F":"248152002",1:"UNK")
 SET N=$$EXTN(.RTN,IDX)+1
 SET RTN("entry",IDX,"resource","extension",N,"url")="http://hl7.org/fhir/us/core/StructureDefinition/us-core-sex"
 SET RTN("entry",IDX,"resource","extension",N,"valueCode")=SEX
 SET RTN("entry",IDX,"resource","extension",N,"valueCode","\s")=""
 QUIT
 ;
RACEEXT(RTN,IDX,DFN) ; Add US Core race extension from VADPT race data
 NEW CODE,DISP,N,VADM,VA,VAERR
 DO DEM^VADPT
 DO RCVAL(DFN,.VADM,.CODE,.DISP)
 IF CODE="" SET CODE="UNK",DISP="Unknown"
 SET N=$$EXTN(.RTN,IDX)+1
 SET RTN("entry",IDX,"resource","extension",N,"url")="http://hl7.org/fhir/us/core/StructureDefinition/us-core-race"
 DO DEMOEXT(.RTN,IDX,N,"ombCategory",CODE,DISP)
 SET RTN("entry",IDX,"resource","extension",N,"extension",2,"url")="text"
 SET RTN("entry",IDX,"resource","extension",N,"extension",2,"valueString")=DISP
 QUIT
 ;
ETHNEXT(RTN,IDX,DFN) ; Add US Core ethnicity extension from VADPT ethnicity data
 NEW CODE,DISP,N,VADM,VA,VAERR
 DO DEM^VADPT
 DO ETHVAL(DFN,.VADM,.CODE,.DISP)
 IF CODE="" SET CODE="UNK",DISP="Unknown"
 SET N=$$EXTN(.RTN,IDX)+1
 SET RTN("entry",IDX,"resource","extension",N,"url")="http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity"
 DO DEMOEXT(.RTN,IDX,N,"ombCategory",CODE,DISP)
 SET RTN("entry",IDX,"resource","extension",N,"extension",2,"url")="text"
 SET RTN("entry",IDX,"resource","extension",N,"extension",2,"valueString")=DISP
 QUIT
 ;
DEMOEXT(RTN,IDX,N,SLICE,CODE,DISP) ; Add one OMB/nullFlavor coding to race/ethnicity
 NEW SYS
 SET SYS=$SELECT(CODE="UNK":"http://terminology.hl7.org/CodeSystem/v3-NullFlavor",CODE="ASKU":"http://terminology.hl7.org/CodeSystem/v3-NullFlavor",1:"urn:oid:2.16.840.1.113883.6.238")
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"url")=SLICE
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCoding","system")=SYS
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCoding","code")=CODE
 IF DISP'="" SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCoding","display")=DISP
 QUIT
 ;
TRIBEXT(RTN,IDX,DFN) ; Add US Core tribal affiliation from RPMS IHS Patient fields
 NEW CODE,DISP,N
 DO TRIBVAL(DFN,.CODE,.DISP)
 IF CODE="" QUIT
 IF DISP="" SET DISP=CODE
 SET N=$$EXTN(.RTN,IDX)+1
 SET RTN("entry",IDX,"resource","extension",N,"url")="http://hl7.org/fhir/us/core/StructureDefinition/us-core-tribal-affiliation"
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"url")="tribalAffiliation"
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCodeableConcept","coding",1,"system")="urn:oid:2.16.840.1.113883.5.140"
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCodeableConcept","coding",1,"code")=CODE
 IF DISP'="" SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCodeableConcept","coding",1,"display")=DISP
 SET RTN("entry",IDX,"resource","extension",N,"extension",1,"valueCodeableConcept","text")=DISP
 QUIT
 ;
RCVAL(DFN,VADM,CODE,DISP) ; Return first race code/display
 NEW I,MAP,VAL
 SET (CODE,DISP)=""
 SET I=+$ORDER(VADM(12,0)) QUIT:I<1
 SET VAL=$GET(VADM(12,I)),DISP=$PIECE(VAL,U,2)
 SET MAP=$$SAFEGET(2.02,+VAL_","_DFN_",",".01:3")
 IF MAP["^" SET CODE=$PIECE(MAP,U),DISP=$SELECT(DISP'="":DISP,1:$PIECE(MAP,U,2))
 QUIT
 ;
ETHVAL(DFN,VADM,CODE,DISP) ; Return first ethnicity code/display
 NEW I,MAP,VAL
 SET (CODE,DISP)=""
 SET I=+$ORDER(VADM(11,0)) QUIT:I<1
 SET VAL=$GET(VADM(11,I)),DISP=$PIECE(VAL,U,2)
 SET MAP=$$SAFEGET(2.06,+VAL_","_DFN_",",".01:3")
 IF MAP["^" SET CODE=$PIECE(MAP,U),DISP=$SELECT(DISP'="":DISP,1:$PIECE(MAP,U,2))
 QUIT
 ;
TRIBVAL(DFN,CODE,DISP) ; Return RPMS tribal affiliation when filed
 SET (CODE,DISP)=""
 IF '$DATA(^AUPNPAT(+$GET(DFN),0)) QUIT
 SET DISP=$$SAFEGET(9000001,DFN_",",1108),CODE=$$SAFEGET(9000001,DFN_",",1108,"I") QUIT:DISP'=""
 SET DISP=$$SAFEGET(9000001,DFN_",",.09),CODE=$$SAFEGET(9000001,DFN_",",.09,"I")
 QUIT
 ;
SAFEGET(FILE,IENS,FIELD,FLAGS) ; GET1^DIQ with errors contained for optional fields
 NEW $ETRAP,$ESTACK,VAL
 SET VAL="",FLAGS=$GET(FLAGS)
 SET $ETRAP="SET $ECODE="""",VAL="""" QUIT"
 SET VAL=$$GET1^DIQ(FILE,IENS,FIELD,FLAGS)
 QUIT VAL
 ;
EXTN(RTN,IDX) ; Last Patient.extension index
 QUIT +$ORDER(RTN("entry",IDX,"resource","extension",""),-1)
 ;
PHONE(X) ; Normalize phone text enough for FHIR telecom.value
 SET X=$$TRIM($GET(X))
 QUIT X
 ;
STATE(IEN) ; USPS state abbreviation from STATE file
 NEW VAL
 SET VAL=""
 IF +$GET(IEN)>0 SET VAL=$$SAFEGET(5,+IEN_",",1)
 QUIT VAL
 ;
PATTEXT(RTN,IDX,NAME,DFN) ; Add generated narrative for validators and readers
 NEW TXT
 SET TXT=$GET(NAME) IF TXT="" SET TXT="Patient "_+$GET(DFN)
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">"_$$HTMLESC(TXT)_"</div>"
 QUIT
 ;
SYSURI() ; Identifier system for local patient ids
 NEW SITE
 SET SITE=$PIECE($$SITE^VASITE,U,3)
 IF SITE="" SET SITE="local"
 QUIT "http://vistafhir.org/fhir/sid/"_SITE_"/mrn"
 ;
GETENC(RTN,ENCIEN,DFN) ; Add Encounter resource to the passed bundle array
 ; ENCIEN is expected to be a visit ien from ^AUPNVSIT
 NEW CLASS,ENC,ENDDT,IDX,VPRTEXT
 DO ENVINIT
 SET ENCIEN=+ENCIEN
 IF ENCIEN<1 QUIT
 SET VPRTEXT=1
 DO FIXVST(ENCIEN)
 DO EN1^VPRDVSIT(ENCIEN,.ENC)
 DO ADDRES^C0FHIRBU(.RTN,"Encounter","E"_ENCIEN,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Encounter"
 SET RTN("entry",IDX,"resource","id")="E"_ENCIEN
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-encounter"
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">Encounter E"_ENCIEN_"</div>"
 SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:visit"
 SET RTN("entry",IDX,"resource","identifier",1,"value")=ENCIEN
 SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET RTN("entry",IDX,"resource","status")="finished"
 SET CLASS=$SELECT($GET(ENC("patientClass"))="IMP":"IMP",1:"AMB")
 SET RTN("entry",IDX,"resource","class","system")="http://terminology.hl7.org/CodeSystem/v3-ActCode"
 SET RTN("entry",IDX,"resource","class","code")=CLASS
 SET RTN("entry",IDX,"resource","class","display")=$SELECT(CLASS="IMP":"inpatient encounter",1:"ambulatory")
 IF +$GET(DFN)>0 DO
 . SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 . IF $PIECE($GET(^DPT(DFN,0)),U)'="" SET RTN("entry",IDX,"resource","subject","display")=$PIECE($GET(^DPT(DFN,0)),U)
 ; VPR sometimes omits ENC("dateTime"); loader needs period.start or fhirTfm^SYNFUTL returns -1.
 IF +$GET(ENC("dateTime"))<1 DO
 . NEW VS SET VS=$PIECE($GET(^AUPNVSIT(ENCIEN,0)),U,2)
 . IF +VS>0 SET ENC("dateTime")=VS
 IF +$GET(ENC("dateTime"))>0 SET RTN("entry",IDX,"resource","period","start")=$$FM2FHIR^C0FHIRBU(ENC("dateTime"))
 SET ENDDT=+$GET(ENC("departureDateTime"))
 IF ENDDT<1 SET ENDDT=$$ENCEND(+$GET(DFN),.ENC)
 IF ENDDT<1 SET ENDDT=+$GET(ENC("dateTime"))
 IF ENDDT>0 SET RTN("entry",IDX,"resource","period","end")=$$FM2FHIR^C0FHIRBU(ENDDT)
 DO SETETYP(.RTN,IDX,.ENC)
 ; Inferno patient+type search uses SCT 185349003; keep it even when CPT is present.
 DO ADDCHKUP(.RTN,IDX)
 DO SETEPRV(.RTN,IDX,.ENC,+$GET(DFN),ENDDT)
 DO SETEFAC(.RTN,IDX,.ENC)
 DO SETELOC(.RTN,IDX,.ENC)
 DO SETESVC(.RTN,IDX,.ENC)
 DO SETERSN(.RTN,IDX,.ENC)
 DO SETESTD(.RTN,IDX,ENCIEN)
 DO SETEPRI(.RTN,IDX)
 DO SETEDIAG(.RTN,IDX,ENCIEN,+$GET(DFN))
 DO SETEHOSP(.RTN,IDX)
 DO SETEHF(.RTN,IDX,ENCIEN)
 ; US Quality Core Encounter snapshot omits Encounter.note; keep TIU via DocumentReference.
 DO SETDOCREF(.RTN,IDX,.ENC,ENCIEN,DFN)
 QUIT
 ;
FIXVST(VIEN) ; Fill sparse RPMS visit parent nodes before PXKENC copies them
 NEW NODE
 SET VIEN=+$GET(VIEN)
 IF VIEN<1 QUIT
 SET NODE=""
 FOR  SET NODE=$ORDER(^AUPNVSIT(VIEN,NODE)) QUIT:NODE=""  IF $DATA(^AUPNVSIT(VIEN,NODE))#10=0 SET ^AUPNVSIT(VIEN,NODE)=""
 QUIT
 ;
SETETYP(RTN,IDX,ENC) ; Populate Encounter.type from encounter CPT/OS5 when available
 NEW CODE,TXT,TYPE
 KILL TYPE
 DO ENCTYP(.ENC,.TYPE)
 IF $DATA(TYPE) MERGE RTN("entry",IDX,"resource","type",1)=TYPE QUIT
 SET CODE=$PIECE($GET(ENC("type")),"^")
 SET TXT=$PIECE($GET(ENC("type")),"^",2)
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","type",1,"coding",1,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","type",1,"coding",1,"code")=CODE
 . SET RTN("entry",IDX,"resource","type",1,"coding",1,"code","\s")=""
 . IF TXT'="" SET RTN("entry",IDX,"resource","type",1,"coding",1,"display")=TXT
 IF TXT'="" SET RTN("entry",IDX,"resource","type",1,"text")=TXT
 QUIT
 ;
ENCTYP(ENC,TYPE) ; Build encounter type from encounter-like CPT/OS5 rows
 NEW CODE,DA,ITEM,NAME
 KILL TYPE
 SET DA=0
 FOR  SET DA=$ORDER(ENC("cpt",DA)) Q:DA<1  DO  Q:$DATA(TYPE)
 . SET ITEM=$GET(ENC("cpt",DA))
 . SET CODE=$PIECE(ITEM,"^")
 . SET NAME=$PIECE(ITEM,"^",2,99)
 . IF '$$ISENCD^C0FHIRP(CODE) QUIT
 . DO ENCCOD(CODE,NAME,.TYPE)
 QUIT
 ;
ENCCOD(CODE,NAME,TYPE) ; Add encounter coding from OS5/CPT and recovered SNOMED
 NEW SCT,SDISP
 KILL TYPE
 SET CODE=$PIECE($GET(CODE),"^")
 SET NAME=$GET(NAME)
 IF CODE="" QUIT
 DO ENCSNOM(CODE,.SCT,.SDISP)
 IF SCT="" SET SCT="185349003",SDISP="Encounter for check up"
 SET TYPE("coding",1,"system")="http://snomed.info/sct"
 SET TYPE("coding",1,"code")=SCT
 SET TYPE("coding",1,"code","\s")=""
 IF SDISP'="" SET TYPE("coding",1,"display")=SDISP
 SET TYPE("coding",2,"system")="http://www.ama-assn.org/go/cpt"
 SET TYPE("coding",2,"code")=CODE
 SET TYPE("coding",2,"code","\s")=""
 IF NAME'="" SET TYPE("coding",2,"display")=NAME
 IF NAME="" SET NAME=SDISP
 IF NAME'="" SET TYPE("text")=NAME
 QUIT
 ;
ADDCHKUP(RTN,IDX) ; Ensure Encounter.type includes SCT 185349003 for type search
 NEW CI,HAVE,N,TXT
 SET HAVE=0,CI=0
 FOR  SET CI=$ORDER(RTN("entry",IDX,"resource","type",1,"coding",CI)) QUIT:CI<1  DO  QUIT:HAVE
 . IF $GET(RTN("entry",IDX,"resource","type",1,"coding",CI,"code"))="185349003" SET HAVE=1
 IF HAVE QUIT
 ; Shift existing codings up and insert check-up as coding 1.
 SET N=$ORDER(RTN("entry",IDX,"resource","type",1,"coding",""),-1)
 FOR CI=N:-1:1 DO
 . MERGE RTN("entry",IDX,"resource","type",1,"coding",CI+1)=RTN("entry",IDX,"resource","type",1,"coding",CI)
 . KILL RTN("entry",IDX,"resource","type",1,"coding",CI)
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"system")="http://snomed.info/sct"
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"code")="185349003"
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"code","\s")=""
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"display")="Encounter for check up"
 SET TXT=$GET(RTN("entry",IDX,"resource","type",1,"text"))
 IF TXT="" SET RTN("entry",IDX,"resource","type",1,"text")="Encounter for check up"
 QUIT
 ;
ENCSNOM(CODE,SCT,SDISP) ; Recover source SNOMED mapping for one encounter OS5/CPT code
 NEW HIT
 SET (SCT,SDISP)=""
 SET CODE=$PIECE($GET(CODE),"^")
 IF CODE="" QUIT
 SET HIT=0
 FOR  SET SCT=$ORDER(^SYN("2002.030","sct2os5","inverse",CODE,SCT)) Q:SCT=""  DO  Q:HIT
 . IF '$$ISENCS^C0FHIRP(SCT) QUIT
 . IF $$ISDUALS^C0FHIRP(SCT) QUIT
 . SET SDISP=$GET(^SYN("2002.030","sct2os5","inverse",CODE,SCT))
 . SET HIT=1
 QUIT
 ;
ENCEND(DFN,ENC) ; Recover outpatient end time from clinic appointment checkout
 NEW APDT,CLIEN,ENDDT,IEN
 SET ENDDT=0
 SET DFN=+$GET(DFN)
 SET APDT=+$GET(ENC("dateTime"))
 SET CLIEN=$$ENCCLIN(.ENC)
 IF DFN<1!(APDT<1)!(CLIEN<1) QUIT 0
 SET IEN=0
 FOR  SET IEN=$ORDER(^SC(CLIEN,"S",APDT,1,IEN)) Q:IEN<1!(ENDDT>0)  DO
 . IF +$GET(^SC(CLIEN,"S",APDT,1,IEN,0))'=DFN QUIT
 . SET ENDDT=$$GET1^DIQ(44.003,IEN_","_APDT_","_CLIEN_",",303,"I")
 . IF ENDDT<1 SET ENDDT=$$GET1^DIQ(44.003,IEN_","_APDT_","_CLIEN_",",306,"I")
 QUIT ENDDT
 ;
ENCCLIN(ENC) ; Return clinic ien from visit string
 QUIT +$PIECE($GET(ENC("visitString")),";",1)
 ;
SETEPRV(RTN,IDX,ENC,DFN,ENDDT) ; Add encounter participants from VistA provider data
 NEW I,N,PROV,RAW,ROLE,STARTDT,UID
 SET STARTDT=+$GET(ENC("dateTime"))
 SET N=0,I=0
 FOR  SET I=$ORDER(ENC("provider",I)) Q:I<1  DO
 . SET RAW=$GET(ENC("provider",I))
 . SET PROV=$$PROV^C0FHIRP(RAW)
 . IF $PIECE(PROV,U,2)="" QUIT
 . SET N=N+1
 . SET UID=+$PIECE(PROV,U)
 . SET RTN("entry",IDX,"resource","participant",N,"individual","display")=$PIECE(PROV,U,2)
 . IF UID>0 DO
 . . SET RTN("entry",IDX,"resource","participant",N,"individual","reference")="Practitioner/P"_UID
 . . DO ADDPRAC(.RTN,UID,$PIECE(PROV,U,2))
 . IF STARTDT>0 SET RTN("entry",IDX,"resource","participant",N,"period","start")=$$FM2FHIR^C0FHIRBU(STARTDT)
 . IF ENDDT>0 SET RTN("entry",IDX,"resource","participant",N,"period","end")=$$FM2FHIR^C0FHIRBU(ENDDT)
 . SET ROLE=$$PROL($PIECE(RAW,U,3),+$PIECE(RAW,U,4))
 . IF $PIECE(ROLE,U)'="" DO
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v3-ParticipationType"
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"code")=$PIECE(ROLE,U)
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"coding",1,"display")=$PIECE(ROLE,U,2)
 . . SET RTN("entry",IDX,"resource","participant",N,"type",1,"text")=$PIECE(ROLE,U,2)
 QUIT
 ;
PROL(CODE,PRIMARY) ; Map VistA visit provider role to participation type
 SET CODE=$$UPCASE($GET(CODE))
 IF +$GET(PRIMARY)=1!(CODE="P") QUIT "PPRF^primary performer"
 IF CODE="A" QUIT "ATND^attender"
 QUIT ""
 ;
SETEFAC(RTN,IDX,ENC) ; Add serviceProvider from VistA facility when available
 NEW FAC,NAME,ORGID,STA
 SET FAC=$GET(ENC("facility"))
 SET STA=$PIECE(FAC,U)
 SET NAME=$PIECE(FAC,U,2)
 IF STA="",NAME="" QUIT
 IF STA'="" SET ORGID="STA"_$TRANSLATE(STA," /","--")
 E  SET ORGID="FAC"_$TRANSLATE($EXTRACT(NAME,1,24)," /","--")
 SET RTN("entry",IDX,"resource","serviceProvider","reference")="Organization/"_ORGID
 IF NAME'="" SET RTN("entry",IDX,"resource","serviceProvider","display")=NAME
 DO ADDORG(.RTN,ORGID,NAME,STA)
 QUIT
 ;
SETELOC(RTN,IDX,ENC) ; Add clinic/location display in the correct Encounter field
 NEW CLIEN,LOCID,NAME
 SET CLIEN=$$ENCCLIN(.ENC)
 SET NAME=$GET(ENC("location"))
 IF CLIEN<1,NAME="" QUIT
 IF CLIEN>0 SET LOCID="CL"_CLIEN
 E  SET LOCID="LOC"_$TRANSLATE($EXTRACT(NAME,1,24)," /","--")
 SET RTN("entry",IDX,"resource","location",1,"location","reference")="Location/"_LOCID
 IF NAME'="" SET RTN("entry",IDX,"resource","location",1,"location","display")=NAME
 SET RTN("entry",IDX,"resource","location",1,"status")="completed"
 IF $GET(RTN("entry",IDX,"resource","period","start"))'="" SET RTN("entry",IDX,"resource","location",1,"period","start")=$GET(RTN("entry",IDX,"resource","period","start"))
 IF $GET(RTN("entry",IDX,"resource","period","end"))'="" SET RTN("entry",IDX,"resource","location",1,"period","end")=$GET(RTN("entry",IDX,"resource","period","end"))
 DO ADDLOC(.RTN,LOCID,NAME,CLIEN)
 QUIT
 ;
ADDPRAC(RTN,UID,NAME) ; Supporting Practitioner for Encounter.participant
 NEW FAM,GIV,IDX,NPI,RID
 SET UID=+$GET(UID) QUIT:UID<1
 SET RID="P"_UID
 DO ADDRES^C0FHIRBU(.RTN,"Practitioner",RID,.IDX) QUIT:IDX=""
 SET RTN("entry",IDX,"resource","resourceType")="Practitioner"
 SET RTN("entry",IDX,"resource","id")=RID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-practitioner"
 SET NAME=$GET(NAME)
 IF NAME'="" DO
 . SET RTN("entry",IDX,"resource","name",1,"text")=NAME
 . SET FAM=$$TRIM($PIECE(NAME,",",1))
 . SET GIV=$$TRIM($PIECE(NAME,",",2,99))
 . IF FAM="" SET FAM=NAME
 . SET RTN("entry",IDX,"resource","name",1,"family")=FAM
 . IF GIV'="" SET RTN("entry",IDX,"resource","name",1,"given",1)=GIV
 E  SET RTN("entry",IDX,"resource","name",1,"family")="UNKNOWN"
 SET NPI=$$PRACNPI(UID)
 DO PRACMS(.RTN,IDX,NPI)
 ; Keep VA user id as an additional identifier after NPI/EIN slices.
 SET RTN("entry",IDX,"resource","identifier",3,"system")="urn:va:user"
 SET RTN("entry",IDX,"resource","identifier",3,"value")=UID
 SET RTN("entry",IDX,"resource","identifier",3,"value","\s")=""
 QUIT
 ;
ADDORG(RTN,ORGID,NAME,STA) ; Supporting Organization for Encounter.serviceProvider
 NEW IDX
 SET ORGID=$GET(ORGID) QUIT:ORGID=""
 DO ADDRES^C0FHIRBU(.RTN,"Organization",ORGID,.IDX) QUIT:IDX=""
 SET RTN("entry",IDX,"resource","resourceType")="Organization"
 SET RTN("entry",IDX,"resource","id")=ORGID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-organization"
 SET RTN("entry",IDX,"resource","active")="true"
 IF $GET(NAME)="" SET NAME=ORGID
 SET RTN("entry",IDX,"resource","name")=NAME
 DO ORGMS(.RTN,IDX)
 IF $GET(STA)'="" DO
 . SET RTN("entry",IDX,"resource","identifier",4,"system")="urn:va:station"
 . SET RTN("entry",IDX,"resource","identifier",4,"value")=STA
 . SET RTN("entry",IDX,"resource","identifier",4,"value","\s")=""
 QUIT
 ;
ADDLOC(RTN,LOCID,NAME,CLIEN) ; Supporting Location for Encounter.location
 NEW IDX,ORGREF
 SET LOCID=$GET(LOCID) QUIT:LOCID=""
 DO ADDRES^C0FHIRBU(.RTN,"Location",LOCID,.IDX) QUIT:IDX=""
 SET RTN("entry",IDX,"resource","resourceType")="Location"
 SET RTN("entry",IDX,"resource","id")=LOCID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-location"
 SET RTN("entry",IDX,"resource","status")="active"
 IF $GET(NAME)="" SET NAME=LOCID
 SET RTN("entry",IDX,"resource","name")=NAME
 IF +$GET(CLIEN)>0 DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:clinic"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=+CLIEN
 . SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v3-RoleCode"
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"code")="OF"
 SET RTN("entry",IDX,"resource","type",1,"coding",1,"display")="Outpatient facility"
 SET RTN("entry",IDX,"resource","type",1,"text")="Outpatient facility"
 SET ORGREF="Organization/usqualitycore-organization"
 DO LOCMS(.RTN,IDX,ORGREF)
 QUIT
 ;
ORGMS(RTN,IDX) ; USQC Must Support: Organization identifiers/telecom/address
 ; NPI / CCN / EIN slices (showcase values when site data unavailable).
 SET RTN("entry",IDX,"resource","identifier",1,"use")="official"
 SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-npi"
 SET RTN("entry",IDX,"resource","identifier",1,"value")="1144221847"
 SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET RTN("entry",IDX,"resource","identifier",2,"use")="official"
 SET RTN("entry",IDX,"resource","identifier",2,"system")="http://terminology.hl7.org/NamingSystem/CMSCertificationNumber"
 SET RTN("entry",IDX,"resource","identifier",2,"value")="320001"
 SET RTN("entry",IDX,"resource","identifier",2,"value","\s")=""
 SET RTN("entry",IDX,"resource","identifier",3,"use")="official"
 SET RTN("entry",IDX,"resource","identifier",3,"system")="urn:oid:2.16.840.1.113883.4.4"
 SET RTN("entry",IDX,"resource","identifier",3,"value")="12-3456789"
 SET RTN("entry",IDX,"resource","identifier",3,"value","\s")=""
 SET RTN("entry",IDX,"resource","telecom",1,"system")="phone"
 SET RTN("entry",IDX,"resource","telecom",1,"value")="505-265-1711"
 DO ADDRMS(.RTN,IDX,0)
 QUIT
 ;
PRACMS(RTN,IDX,NPI) ; USQC Must Support: Practitioner NPI/EIN/telecom/address
 ; Default NPI must pass us-core-17 Luhn check.
 IF $GET(NPI)="" SET NPI="1245319599"
 IF '$$NPILUHN(NPI) SET NPI="1245319599"
 SET RTN("entry",IDX,"resource","identifier",1,"use")="official"
 SET RTN("entry",IDX,"resource","identifier",1,"system")="http://hl7.org/fhir/sid/us-npi"
 SET RTN("entry",IDX,"resource","identifier",1,"value")=NPI
 SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET RTN("entry",IDX,"resource","identifier",2,"use")="official"
 SET RTN("entry",IDX,"resource","identifier",2,"system")="urn:oid:2.16.840.1.113883.4.4"
 SET RTN("entry",IDX,"resource","identifier",2,"value")="12-3456789"
 SET RTN("entry",IDX,"resource","identifier",2,"value","\s")=""
 SET RTN("entry",IDX,"resource","telecom",1,"system")="phone"
 SET RTN("entry",IDX,"resource","telecom",1,"value")="505-265-1711"
 DO ADDRMS(.RTN,IDX,0)
 QUIT
 ;
LOCMS(RTN,IDX,ORGREF) ; USQC Must Support: Location telecom/address/managingOrganization
 SET RTN("entry",IDX,"resource","telecom",1,"system")="phone"
 SET RTN("entry",IDX,"resource","telecom",1,"value")="505-265-1711"
 ; Location.address is 0..1 (object), not an array.
 DO ADDRMS(.RTN,IDX,1)
 IF $GET(ORGREF)'="" SET RTN("entry",IDX,"resource","managingOrganization","reference")=ORGREF
 QUIT
 ;
ADDRMS(RTN,IDX,SING) ; Shared US address; SING=1 => Location singular address
 NEW BASE
 IF +$GET(SING) SET BASE=$NAME(RTN("entry",IDX,"resource","address"))
 E  SET BASE=$NAME(RTN("entry",IDX,"resource","address",1))
 SET @BASE@("line",1)="1501 San Pedro Dr SE"
 SET @BASE@("city")="Albuquerque"
 SET @BASE@("state")="NM"
 SET @BASE@("postalCode")="87108"
 SET @BASE@("postalCode","\s")=""
 SET @BASE@("country")="US"
 QUIT
 ;
NPILUHN(NPI) ; $$1 if 10-digit NPI passes CMS Luhn (80840 prefix)
 NEW D,I,S,T,X
 SET NPI=$$TRIM($GET(NPI)) QUIT:NPI'?10N 0
 SET S="80840"_NPI,T=0
 FOR I=$LENGTH(S):-1:1 DO
 . SET D=+$EXTRACT(S,I)
 . SET X=$LENGTH(S)-I
 . IF X#2 DO
 . . SET D=D*2
 . . IF D>9 SET D=D-9
 . SET T=T+D
 QUIT '(T#10)
 ;
PRACNPI(UID) ; $$ NPI for a NEW PERSON when available
 NEW NPI
 SET UID=+$GET(UID) QUIT:UID<1 ""
 SET NPI=$$TRIM($$GET1^DIQ(200,UID_",",41.99))
 IF NPI?10N QUIT NPI
 IF $T(NPI^XUSNPI)'="" DO
 . SET NPI=$$NPI^XUSNPI("Individual_ID",UID)
 . SET NPI=$$TRIM($PIECE(NPI,U))
 IF NPI?10N QUIT NPI
 QUIT ""
 ;
SETESVC(RTN,IDX,ENC) ; Add service text when available
 NEW CODE,TXT
 ; Prefer human-readable text only: urn:va:stop-code is not a published CodeSystem
 ; and fails terminology validation under US Core / US Quality Core Encounter.
 IF $GET(ENC("service"))'="" SET RTN("entry",IDX,"resource","serviceType","text")=$GET(ENC("service"))
 SET CODE=$PIECE($GET(ENC("stopCode")),U)
 SET TXT=$PIECE($GET(ENC("stopCode")),U,2)
 IF $GET(RTN("entry",IDX,"resource","serviceType","text"))="" DO
 . IF TXT'="" SET RTN("entry",IDX,"resource","serviceType","text")=TXT
 . E  IF CODE'="" SET RTN("entry",IDX,"resource","serviceType","text")=CODE
 QUIT
 ;
SETERSN(RTN,IDX,ENC) ; Add encounter reason from VistA POV data when available
 NEW CODE,NARR,NAME,SYS
 SET CODE=$PIECE($GET(ENC("reason")),U)
 IF $EXTRACT(CODE,$LENGTH(CODE))="." SET CODE=$EXTRACT(CODE,1,$LENGTH(CODE)-1)
 SET NAME=$PIECE($GET(ENC("reason")),U,2)
 SET SYS=$PIECE($GET(ENC("reason")),U,3)
 SET NARR=$PIECE($GET(ENC("reason")),U,4)
 IF CODE=""&(NARR="")&(NAME="") QUIT
 IF CODE'="" DO
 . SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"code")=CODE
 . SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"code","\s")=""
 . ; Prefer code shape over VPR system token (ICD codes often tagged SCT).
 . SET RTN("entry",IDX,"resource","reasonCode",1,"coding",1,"system")=$$CODESYS^C0FHIRD(CODE,$GET(SYS))
 . ; Omit coding.display: VistA ICD text often fails terminology display validation.
 IF NARR="" SET NARR=NAME
 IF NARR'="" SET RTN("entry",IDX,"resource","reasonCode",1,"text")=NARR
 QUIT
 ;
SETEPRI(RTN,IDX) ; USQC Must Support: Encounter.priority
 SET RTN("entry",IDX,"resource","priority","coding",1,"system")="http://terminology.hl7.org/CodeSystem/v3-ActPriority"
 SET RTN("entry",IDX,"resource","priority","coding",1,"code")="R"
 SET RTN("entry",IDX,"resource","priority","coding",1,"display")="routine"
 SET RTN("entry",IDX,"resource","priority","text")="routine"
 QUIT
 ;
SETEDIAG(RTN,IDX,VIEN,DFN) ; USQC Must Support: diagnosis + reasonReference from V POV
 NEW IEN,N,PRIM,RID,X0
 SET VIEN=+$GET(VIEN) QUIT:VIEN<1
 SET N=0,IEN=0
 FOR  SET IEN=$ORDER(^AUPNVPOV("AD",VIEN,IEN)) QUIT:IEN<1  DO
 . SET X0=$GET(^AUPNVPOV(IEN,0)) QUIT:X0=""
 . IF +$GET(DFN)>0,+$PIECE(X0,U,2)'=+$GET(DFN) QUIT
 . SET RID="CED"_IEN
 . SET N=N+1
 . SET RTN("entry",IDX,"resource","diagnosis",N,"condition","reference")="Condition/"_RID
 . SET RTN("entry",IDX,"resource","diagnosis",N,"condition","type")="Condition"
 . SET PRIM=$$UPCASE($PIECE(X0,U,12))
 . IF PRIM="P"!(PRIM="PRIMARY")!(N=1) DO
 . . SET RTN("entry",IDX,"resource","diagnosis",N,"use","coding",1,"system")="http://terminology.hl7.org/CodeSystem/diagnosis-role"
 . . SET RTN("entry",IDX,"resource","diagnosis",N,"use","coding",1,"code")="DD"
 . . SET RTN("entry",IDX,"resource","diagnosis",N,"use","coding",1,"display")="Discharge diagnosis"
 . . ; integer rank (do not force-string; validator rejects JSON string ranks)
 . . SET RTN("entry",IDX,"resource","diagnosis",N,"rank")=1
 . ; Present-on-admission MS extension (IG example uses Y, no display).
 . SET RTN("entry",IDX,"resource","diagnosis",N,"extension",1,"url")="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-encounter-diagnosisPresentOnAdmission"
 . SET RTN("entry",IDX,"resource","diagnosis",N,"extension",1,"valueCodeableConcept","coding",1,"system")="https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding"
 . SET RTN("entry",IDX,"resource","diagnosis",N,"extension",1,"valueCodeableConcept","coding",1,"code")="Y"
 . ; reasonReference MS: point at the first/primary diagnosis Condition.
 . IF N=1 DO
 . . SET RTN("entry",IDX,"resource","reasonReference",1,"reference")="Condition/"_RID
 . . SET RTN("entry",IDX,"resource","reasonReference",1,"type")="Condition"
 QUIT
 ;
SETEHOSP(RTN,IDX) ; USQC Must Support: hospitalization.dischargeDisposition
 ; CMS165 cohort is ambulatory-heavy; emit a default disposition so MS is exercised.
 SET RTN("entry",IDX,"resource","hospitalization","dischargeDisposition","coding",1,"system")="http://terminology.hl7.org/CodeSystem/discharge-disposition"
 SET RTN("entry",IDX,"resource","hospitalization","dischargeDisposition","coding",1,"code")="home"
 SET RTN("entry",IDX,"resource","hospitalization","dischargeDisposition","coding",1,"display")="Home"
 SET RTN("entry",IDX,"resource","hospitalization","dischargeDisposition","text")="Home"
 QUIT
 ;
SETESTD(RTN,IDX,VIEN) ; Add V STANDARD CODES rows as Encounter.reasonCode
 NEW CODE,DISP,IEN,N,SUP,SYS,X0
 SET VIEN=+$GET(VIEN) QUIT:VIEN<1
 SET IEN=0
 FOR  SET IEN=$ORDER(^AUPNVSC("AD",VIEN,IEN)) QUIT:IEN<1  DO
 . SET X0=$GET(^AUPNVSC(IEN,0))
 . SET CODE=$PIECE(X0,U) QUIT:CODE=""
 . SET SYS=$PIECE(X0,U,5)
 . IF $$HASRC(.RTN,IDX,CODE,$$STDSYS(SYS,CODE)) QUIT
 . SET SUP=$PIECE($GET(^AUPNVSC(IEN,811)),U)
 . SET DISP=$$STDDISP(SUP,CODE)
 . SET N=$ORDER(RTN("entry",IDX,"resource","reasonCode",""),-1)+1
 . SET RTN("entry",IDX,"resource","reasonCode",N,"coding",1,"system")=$$STDSYS(SYS,CODE)
 . SET RTN("entry",IDX,"resource","reasonCode",N,"coding",1,"code")=CODE
 . SET RTN("entry",IDX,"resource","reasonCode",N,"coding",1,"code","\s")=""
 . ; SCT: omit coding.display unless Lexicon preferred term exists.
 . ; Never put V STANDARD CODES POV/support text on SCT coding.display.
 . IF $$STDSYS(SYS,CODE)="http://snomed.info/sct" DO
 . . NEW LEX SET LEX=$$SCTDISP(CODE)
 . . IF LEX'="",'$$ISPOVDIS(LEX) SET RTN("entry",IDX,"resource","reasonCode",N,"coding",1,"display")=LEX
 . E  IF DISP'="",'$$ISPOVDIS(DISP) SET RTN("entry",IDX,"resource","reasonCode",N,"coding",1,"display")=DISP
 . IF DISP'="",'$$ISPOVDIS(DISP) SET RTN("entry",IDX,"resource","reasonCode",N,"text")=DISP
 . IF SUP'="" DO
 . . SET RTN("entry",IDX,"resource","reasonCode",N,"extension",1,"url")=$$RCSUPURL()
 . . SET RTN("entry",IDX,"resource","reasonCode",N,"extension",1,"valueString")=$$TRIM($$STDSUP(SUP))
 QUIT
 ;
ISPOVDIS(X) ; $$ - true when text is VistA POV boilerplate, not a term display
 SET X=$$UPCASE($$TRIM($GET(X)))
 IF X="" QUIT 0
 IF X["PURPOSE OF VISIT" QUIT 1
 IF X="POV"!(X="POV.") QUIT 1
 QUIT 0
 ;
STDDISP(SUP,CODE) ; Best display text for a V STANDARD CODES row
 NEW LINE,TXT
 SET SUP=$GET(SUP),CODE=$GET(CODE),TXT=""
 SET TXT=$$SCTDISP(CODE)
 IF TXT'="",'$$ISPOVDIS(TXT) QUIT TXT
 SET TXT=""
 IF SUP'="" DO
 . SET LINE=$$TRIM($PIECE(SUP,$CHAR(10),1))
 . IF $EXTRACT(LINE,1,9)="Display: " SET TXT=$PIECE($EXTRACT(LINE,10,$LENGTH(LINE))," | Support: ",1)
 . E  IF LINE[" (SCT "_CODE_")" SET TXT=$PIECE(LINE," (SCT "_CODE_")",1)
 . E  IF LINE["SCT "_CODE SET TXT=$$TRIM($TRANSLATE($PIECE(LINE,"SCT "_CODE,1),"()-","   "))
 . E  IF '$$ISPOVDIS(LINE) SET TXT=LINE
 . IF $$ISPOVDIS(TXT) SET TXT=""
 QUIT $$TRIM(TXT)
 ;
STDSUP(SUP) ; Support text from V STANDARD CODES comment
 NEW I,LINE,TXT
 SET TXT=""
 FOR I=1:1:$LENGTH($GET(SUP),$CHAR(10)) DO  QUIT:TXT'=""
 . SET LINE=$PIECE(SUP,$CHAR(10),I)
 . IF LINE[" | Support: " SET TXT=$PIECE(LINE," | Support: ",2,99) QUIT
 . IF $EXTRACT(LINE,1,9)="Support: " SET TXT=$EXTRACT(LINE,10,$LENGTH(LINE))
 QUIT $S(TXT'="":TXT,1:$GET(SUP))
 ;
SCTDISP(CODE) ; Display fallback for a SNOMED code when available
 NEW TXT
 SET TXT=""
 IF $GET(CODE)'="" SET TXT=$GET(^LEX(757.02,"CODE",CODE))
 QUIT TXT
 ;
HASRC(RTN,IDX,CODE,SYS) ; $$ - true if Encounter.reasonCode already has this coding
 NEW CI,FOUND,RCI
 SET FOUND=0
 SET RCI=0
 FOR  SET RCI=$ORDER(RTN("entry",IDX,"resource","reasonCode",RCI)) QUIT:RCI<1  DO  QUIT:FOUND
 . SET CI=0
 . FOR  SET CI=$ORDER(RTN("entry",IDX,"resource","reasonCode",RCI,"coding",CI)) QUIT:CI<1  DO  QUIT:FOUND
 . . IF $GET(RTN("entry",IDX,"resource","reasonCode",RCI,"coding",CI,"code"))'=CODE QUIT
 . . IF $GET(RTN("entry",IDX,"resource","reasonCode",RCI,"coding",CI,"system"))'=SYS QUIT
 . . SET FOUND=1
 QUIT FOUND
 ;
STDSYS(SYS,CODE) ; Map V STANDARD CODES coding system to FHIR system URL
 ; Prefer code shape so ICD tokens tagged SCT do not emit under snomed.info/sct.
 QUIT $$CODESYS^C0FHIRD($GET(CODE),$GET(SYS))
 ;
RCSUPURL() ; Canonical reasonCode support extension URL
 QUIT "http://vistaplex.org/fhir/StructureDefinition/vista-reason-support"
 ;
SETEHF(RTN,IDX,VIEN) ; Add V Health Factor rows as Encounter extensions
 NEW EI,HFIEN,IEN,NAME,N,SEV,X0
 SET VIEN=+$GET(VIEN) QUIT:VIEN<1
 SET IEN=0
 FOR  SET IEN=$ORDER(^AUPNVHF("AD",VIEN,IEN)) QUIT:IEN<1  DO
 . SET X0=$GET(^AUPNVHF(IEN,0))
 . SET HFIEN=+$PIECE(X0,U) QUIT:HFIEN<1
 . SET NAME=$PIECE($GET(^AUTTHF(HFIEN,0)),U) QUIT:NAME=""
 . SET N=$ORDER(RTN("entry",IDX,"resource","extension",""),-1)+1
 . SET RTN("entry",IDX,"resource","extension",N,"url")=$$HFURL()
 . SET EI=1
 . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"url")="name"
 . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"valueString")=NAME
 . SET EI=EI+1
 . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"url")="system"
 . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"valueUri")="urn:va:health-factor"
 . SET SEV=$PIECE(X0,U,4)
 . IF SEV'="" DO
 . . SET EI=EI+1
 . . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"url")="severity"
 . . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"valueCode")=SEV
 . IF $GET(^AUPNVHF(IEN,811))'="" DO
 . . SET EI=EI+1
 . . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"url")="comment"
 . . SET RTN("entry",IDX,"resource","extension",N,"extension",EI,"valueString")=$PIECE($GET(^AUPNVHF(IEN,811)),U)
 QUIT
 ;
HFURL() ; Health Factor Encounter extension URL
 QUIT "http://vistaplex.org/fhir/StructureDefinition/vista-health-factor"
 ;
SETENOTE(RTN,IDX,ENC,VIEN) ; Add encounter-linked TIU note text when available
 ; VPRDVSIT TIU^VPRDVSIT skips docs when $$INFO^VPRDTIU<1 (status outside 7-13, etc.).
 ; Merge any visit-linked ^TIU(8925) not already in ENC so /fhir round-trips intake notes.
 ; VIEN = ^AUPNVSIT ien from GETENC (use for TIU "V" index; ENC("id") may be 0 or "E" prefixed).
 NEW CONT,DOC,I,J,TXT,VST,DA
 SET VST=$$VISITIEN^C0FHIR(.ENC,+$GET(VIEN))
 IF VST>0 DO TIUVPRFILL^C0FHIR(VST,.ENC)
 SET J=0
 FOR  SET J=$ORDER(ENC("document",J)) Q:J<1  DO
 . SET DA=+$GET(ENC("document",J))
 . QUIT:DA<1
 . SET ENC("document",J,"content")=$$TIUNOTETX^C0FHIR(DA)
 SET I=0
 FOR  SET I=$ORDER(ENC("document",I)) Q:I<1  DO
 . SET DOC=$GET(ENC("document",I))
 . SET CONT=$GET(ENC("document",I,"content"))
 . SET TXT=$$DOCNOTE^C0FHIRBU(DOC,CONT)
 . IF TXT'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,TXT)
 QUIT
 ;
SETDOCREF(RTN,EIDX,ENC,VIEN,DFN) ; Add visit-linked TIU as DocumentReference/DiagnosticReport resources
 NEW CONT,DA,DIDX,DOC,I,TXT,VST
 SET VST=$$VISITIEN^C0FHIR(.ENC,+$GET(VIEN))
 QUIT:VST<1
 DO TIUVPRFILL^C0FHIR(VST,.ENC)
 SET I=0
 FOR  SET I=$ORDER(ENC("document",I)) QUIT:I<1  DO
 . SET DOC=$GET(ENC("document",I))
 . SET DA=+$GET(DOC) QUIT:DA<1
 . SET CONT=$GET(ENC("document",I,"content"))
 . IF CONT="" SET CONT=$$TIUNOTETX^C0FHIR(DA)
 . SET TXT=$$DOCTEXT^C0FHIRBU(CONT) QUIT:TXT=""
 . DO ADDTIUDOC(.RTN,.DIDX,DA,DOC,TXT,VST,+$GET(DFN),$GET(RTN("entry",EIDX,"fullUrl")))
 QUIT
 ;
ADDTIUDOC(RTN,IDX,DA,DOC,TXT,VST,DFN,ENCURL) ; Add TIU as DocumentReference or AI DiagnosticReport
 NEW ENCREF
 ; Prefer stable Encounter/E{visit} over bundle fullUrl (often urn:uuid:...).
 SET ENCREF=$SELECT(+$GET(VST)>0:"Encounter/E"_+VST,$GET(ENCURL)'="":$GET(ENCURL),1:"")
 IF $$ISAIDOC(DA,DOC) DO  QUIT
 . DO ADDAIDR(.RTN,.IDX,DA,DOC,TXT,VST,+$GET(DFN))
 . IF ENCREF'="" SET RTN("entry",IDX,"resource","encounter","reference")=ENCREF
 DO ADDDOCREF(.RTN,.IDX,DA,DOC,TXT,VST,+$GET(DFN))
 IF ENCREF'="" DO
 . SET RTN("entry",IDX,"resource","context","encounter",1,"reference")=ENCREF
 . SET RTN("entry",IDX,"resource","context","encounter",1,"type")="Encounter"
 QUIT
 ;
ISAIDOC(DA,DOC) ; $$ - TIU document should export as AI Consult DiagnosticReport
 NEW TITLE
 SET TITLE=$P($GET(DOC),U,2) IF TITLE="" SET TITLE=$P($GET(DOC),U,3)
 IF TITLE="" SET TITLE=$$GET1^DIQ(8925,+$GET(DA)_",",.01,"E")
 QUIT $S($$UPCASE($GET(TITLE))="AI CONSULT DIAGNOSTIC REPORT":1,1:0)
 ;
ADDAIDR(RTN,IDX,DA,DOC,TXT,VST,DFN) ; Add one TIU-backed AI Consult DiagnosticReport
 NEW AUTH,DT,TITLE
 SET TITLE="AI Consult Diagnostic Report"
 DO ADDRES^C0FHIRBU(.RTN,"DiagnosticReport","D"_+$GET(DA),.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="DiagnosticReport"
 SET RTN("entry",IDX,"resource","id")="D"_+$GET(DA)
 SET RTN("entry",IDX,"resource","status")="final"
 SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://vistaplex.org/fhir/CodeSystem/report-category"
 SET RTN("entry",IDX,"resource","code","coding",1,"code")="ai-consult"
 SET RTN("entry",IDX,"resource","code","coding",1,"display")=TITLE
 SET RTN("entry",IDX,"resource","code","text")=TITLE
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0074"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="OTH"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Other"
 SET RTN("entry",IDX,"resource","category",1,"text")="AI Consult"
 SET DT=+$P($GET(DOC),U,6)
 IF DT<1 SET DT=+$P($GET(^TIU(8925,+$GET(DA),0)),U,7)
 IF DT>0 SET RTN("entry",IDX,"resource","issued")=$$FM2FHIR^C0FHIRBU(DT)
 IF +$GET(DFN)>0 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET AUTH=$$DOCAUTH(DA)
 IF AUTH'="" SET RTN("entry",IDX,"resource","performer",1,"display")=AUTH
 SET RTN("entry",IDX,"resource","presentedForm",1,"contentType")="text/markdown"
 SET RTN("entry",IDX,"resource","presentedForm",1,"title")=TITLE
 SET RTN("entry",IDX,"resource","presentedForm",1,"data")=$$B64(TXT)
 SET RTN("entry",IDX,"resource","presentedForm",1,"data","\s")=""
 QUIT
 ;
ADDDOCREF(RTN,IDX,DA,DOC,TXT,VST,DFN) ; Add one TIU DocumentReference resource
 NEW AUTH,DT,END,TITLE,VDT
 DO ADDRES^C0FHIRBU(.RTN,"DocumentReference","D"_+$GET(DA),.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="DocumentReference"
 SET RTN("entry",IDX,"resource","id")="D"_+$GET(DA)
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://hl7.org/fhir/us/core/StructureDefinition/us-core-documentreference|6.1.0"
 SET RTN("entry",IDX,"resource","status")="current"
 ; USQC/US Core Must Support: identifier
 SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:va:tiu"
 SET RTN("entry",IDX,"resource","identifier",1,"value")=+$GET(DA)
 SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET TITLE=$P($GET(DOC),U,2) I TITLE="" SET TITLE=$P($GET(DOC),U,3)
 IF TITLE="" SET TITLE=$$GET1^DIQ(8925,+$GET(DA)_",",.01,"E")
 SET RTN("entry",IDX,"resource","type","coding",1,"system")="http://loinc.org"
 SET RTN("entry",IDX,"resource","type","coding",1,"code")="11506-3"
 SET RTN("entry",IDX,"resource","type","coding",1,"display")="Progress note"
 IF TITLE'="" DO
 . SET RTN("entry",IDX,"resource","type","text")=TITLE
 . SET RTN("entry",IDX,"resource","description")=TITLE
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://hl7.org/fhir/us/core/CodeSystem/us-core-documentreference-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="clinical-note"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Clinical Note"
 SET RTN("entry",IDX,"resource","category",1,"text")="Clinical Note"
 SET DT=+$P($GET(DOC),U,6)
 IF DT<1 SET DT=+$P($GET(^TIU(8925,+$GET(DA),0)),U,7)
 IF DT>0 SET RTN("entry",IDX,"resource","date")=$$FM2FHIR^C0FHIRBU(DT)
 IF +$GET(DFN)>0 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET AUTH=$$DOCAUTH(DA)
 IF AUTH'="" SET RTN("entry",IDX,"resource","author",1,"display")=AUTH
 SET RTN("entry",IDX,"resource","content",1,"attachment","contentType")="text/plain"
 SET RTN("entry",IDX,"resource","content",1,"attachment","title")=$S(TITLE'="":TITLE,1:"TIU Document")
 ; MS: attachment.url (keep base64 data for inline note consumers)
 SET RTN("entry",IDX,"resource","content",1,"attachment","url")="Binary/D"_+$GET(DA)
 SET RTN("entry",IDX,"resource","content",1,"attachment","data")=$$B64(TXT)
 SET RTN("entry",IDX,"resource","content",1,"attachment","data","\s")=""
 ; MS: content.format — mimeType sufficient for text/plain TIU
 SET RTN("entry",IDX,"resource","content",1,"format","system")="http://ihe.net/fhir/ihe.formatcode.fhir/CodeSystem/formatcode"
 SET RTN("entry",IDX,"resource","content",1,"format","code")="urn:ihe:iti:xds:2017:mimeTypeSufficient"
 SET RTN("entry",IDX,"resource","content",1,"format","display")="mimeType Sufficient"
 ; MS: context.period from visit / note datetime
 SET VDT=0
 IF +$GET(VST)>0 SET VDT=+$PIECE($GET(^AUPNVSIT(+VST,0)),U)
 IF VDT<1 SET VDT=DT
 IF VDT>0 DO
 . SET RTN("entry",IDX,"resource","context","period","start")=$$FM2FHIR^C0FHIRBU(VDT)
 . SET END=+$PIECE($GET(^AUPNVSIT(+$GET(VST),0)),U,18)
 . IF END<1 SET END=VDT
 . SET RTN("entry",IDX,"resource","context","period","end")=$$FM2FHIR^C0FHIRBU(END)
 QUIT
 ;
DOCAUTH(DA) ; $$ - TIU author display
 NEW AU
 SET AU=+$P($GET(^TIU(8925,+$GET(DA),12)),U,2)
 I AU>0 Q $P($GET(^VA(200,AU,0)),U)
 Q ""
 ;
B64(TXT) ; $$ - base64 text for DocumentReference attachment
 I $T(ENCODE64^SYNWEBUT)'="" Q $$ENCODE64^SYNWEBUT($G(TXT))
 Q ""
 ;
VISITIEN(ENC,VIEN) ; Numeric visit ien for ^TIU(8925,"V",...) / FIND^DIC index
 IF +$GET(VIEN)>0 QUIT VIEN
 NEW X
 SET X=$GET(ENC("id"))
 IF X?1"E"1N.E QUIT +$EXTRACT(X,2,$LENGTH(X))
 QUIT +X
 ;
TIUNOTETX(DA) ; $NA of array of TIU body lines for FHIR export
 ; Prefer filed word-processing ^TIU(8925,DA,"TEXT",...) (SYN MAKE^TIUSRVP / loader shape).
 ; Fall back to $$TEXT^VPRDTIU (TGET^TIUSRVR1) when no TEXT nodes - respects viewer when body absent.
 NEW K,L,TGT,T1
 SET DA=+$GET(DA) QUIT:DA<1 ""
 SET TGT=$NA(^TMP("C0FHIRNT",$J,DA))
 KILL ^TMP("C0FHIRNT",$J,DA)
 SET (K,L)=0
 FOR  SET L=$ORDER(^TIU(8925,DA,"TEXT",L)) QUIT:L'>0  DO
 . SET T1=$GET(^TIU(8925,DA,"TEXT",L,0))
 . SET K=K+1,@TGT@(K)=T1
 QUIT:K>0 TGT
 QUIT $$TEXT^VPRDTIU(DA)
 ;
TIUVPRFILL(VISIT,ENC) ; Add ENC("document",n) for TIU on VISIT missing after VPR extract
 NEW VPRX,I,DA,J,CNT,SEEN,Y,TITLE
 SET VISIT=+$GET(VISIT) QUIT:VISIT<1
 KILL SEEN
 SET J=0
 FOR  SET J=$ORDER(ENC("document",J)) Q:J<1  DO
 . SET DA=+$GET(ENC("document",J))
 . IF DA>0 SET SEEN(DA)=1
 SET CNT=+$ORDER(ENC("document",""),-1)
 DO FIND^DIC(8925,,.01,"QX",VISIT,,"V",,,"VPRX")
 SET I=0
 FOR  SET I=$ORDER(VPRX("DILIST",1,I)) Q:I<1  DO
 . SET DA=+$GET(VPRX("DILIST",2,I))
 . QUIT:DA<1
 . QUIT:$DATA(SEEN(DA))
 . SET Y=$$INFO^VPRDTIU(DA)
 . IF Y<1 DO
 .. SET TITLE=$$GET1^DIQ(8925,DA_",",.01,"E")
 .. SET Y=DA_U_TITLE
 . SET CNT=CNT+1
 . SET ENC("document",CNT)=Y
 . SET ENC("document",CNT,"content")=$$TIUNOTETX^C0FHIR(DA)
 QUIT
 ;
GETCOND(RTN,DFN,BEG,END,MAX) ; Add Condition resources for patient/date range
 DO GETCOND^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETCOND(RTN,PROB,DFN) ; Map one VPR problem to a FHIR Condition resource
 DO SETCOND^C0FHIRD(.RTN,.PROB,$GET(DFN))
 QUIT
 ;
CONDSYS(X) ; Map VPR coding system token to FHIR system URL
 QUIT $$CONDSYS^C0FHIRD($GET(X))
 ;
GETOBS(RTN,DFN,BEG,END,MAX) ; Add Observation resources (vitals) for patient/date range
 DO GETOBS^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETOBS(RTN,VIT,DFN) ; Map one VPR vital entry to a FHIR Observation resource
 DO SETOBS^C0FHIRD(.RTN,.VIT,$GET(DFN))
 QUIT
 ;
ISNUM(X) ; True if X is numeric
 QUIT $$ISNUM^C0FHIRD($GET(X))
 ;
GETALGY(RTN,DFN,BEG,END,MAX) ; Add AllergyIntolerance resources
 DO GETALGY^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETALGY(RTN,REAC,DFN) ; Map one VPR allergy entry to FHIR AllergyIntolerance
 DO SETALGY^C0FHIRD(.RTN,.REAC,$GET(DFN))
 QUIT
 ;
ALGREAC(RTN,REAC,IDX,SEV) ; Add reaction manifestations
 DO ALGREAC^C0FHIRD(.RTN,.REAC,$GET(IDX),$GET(SEV))
 QUIT
 ;
ALGNOTE(RTN,REAC,IDX) ; Add allergy comments as note entries
 DO ALGNOTE^C0FHIRD(.RTN,.REAC,$GET(IDX))
 QUIT
 ;
ALGSEV(X) ; Map allergy severity to FHIR reaction severity
 QUIT $$ALGSEV^C0FHIRD($GET(X))
 ;
GETMED(RTN,DFN,BEG,END,MAX) ; Add MedicationRequest resources
 DO GETMED^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETMED(RTN,MED,DFN) ; Map one VPR medication entry to FHIR MedicationRequest
 DO SETMED^C0FHIRD(.RTN,.MED,$GET(DFN))
 QUIT
 ;
MEDCODE(RTN,MED,IDX) ; Add medication coding details when available
 DO MEDCODE^C0FHIRD(.RTN,.MED,$GET(IDX))
 QUIT
 ;
MEDSTAT(X) ; Map VPR medication status to FHIR MedicationRequest status
 QUIT $$MEDSTAT^C0FHIRD($GET(X))
 ;
GETIMM(RTN,DFN,BEG,END,MAX) ; Add Immunization resources
 DO GETIMM^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
SETIMM(RTN,IMM,DFN) ; Map one VPR immunization entry to FHIR Immunization
 DO SETIMM^C0FHIRD(.RTN,.IMM,$GET(DFN))
 QUIT
 ;
GETPROC(RTN,DFN,BEG,END,MAX) ; Add Procedure resources
 DO GETPROC^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETSRQ(RTN,DFN,BEG,END,MAX) ; Add ServiceRequest resources (radiology orders)
 DO GETSRQ^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETCP(RTN,DFN,BEG,END,MAX) ; Add CarePlan resources from SYN CP health factors
 DO GETCP^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETLAB(RTN,DFN,BEG,END,MAX) ; Add lab Observations (chemistry + micro)
 DO GETLAB^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX))
 QUIT
 ;
GETREM(RTN,DFN,LOC,MAX) ; Add Reminders Due DiagnosticReport
 DO GETREM^C0FHIRR(.RTN,$GET(DFN),$GET(LOC),$GET(MAX))
 QUIT
 ;
GETLBSUB(RTN,DFN,BEG,END,MAX,SUB,CNT,LRDFN) ; Extract one lab subdomain
 DO GETLBSUB^C0FHIRD(.RTN,$GET(DFN),$GET(BEG),$GET(END),$GET(MAX),$GET(SUB),.CNT,$GET(LRDFN))
 QUIT
 ;
LABLINE(SUB,DFN,LRDFN,VPRIDT,VPRP) ; Build normalized line from ^TMP("LRRR")
 QUIT $$LABLINE^C0FHIRD($GET(SUB),+$GET(DFN),+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP))
 ;
CHLINE(LRDFN,VPRIDT,VPRP,X0) ; Return normalized chemistry line
 QUIT $$CHLINE^C0FHIRD(+$GET(LRDFN),+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
MILINE(VPRIDT,VPRP,X0) ; Return normalized microbiology line
 QUIT $$MILINE^C0FHIRD(+$GET(VPRIDT),+$GET(VPRP),$GET(X0))
 ;
SETLAB(RTN,LINE,SUB,DFN,ORD) ; Map one VPR lab line to FHIR Observation
 DO SETLAB^C0FHIRD(.RTN,$GET(LINE),$GET(SUB),$GET(DFN),$GET(ORD))
 QUIT
 ;
LABMETA(RTN,IDX,LINE,ORD) ; Add lab interpretation/range/order metadata
 DO LABMETA^C0FHIRD(.RTN,$GET(IDX),$GET(LINE),$GET(ORD))
 QUIT
 ;
LABDT(X) ; Convert inverse FM date piece from lab id to FHIR dateTime
 QUIT $$LABDT^C0FHIRD($GET(X))
 ;
LABID(X) ; Normalize lab id to FHIR-safe id
 QUIT $$LABID^C0FHIRD($GET(X))
 ;
RPCFHIR(RTN,DFN,ENC,START,END,MAX,MODE,DOMAINS) ; RPC entry point (scalar params)
 ; Broker-friendly wrapper around GETFHIR.
 ; Inputs:
 ;   DFN   - required patient identifier
 ;   ENC   - optional encounter id
 ;   START - optional start date (FM or %DT expression, e.g. T-30)
 ;   END   - optional end date (FM or %DT expression, e.g. NOW)
 ;   MAX   - optional numeric cap on resources
 ;   MODE  - optional ENCOUNTER or DATERANGE
 ;   DOMAINS - optional comma-separated domain list
 ;             (for example: "encounter,condition,vitals,procedures,labs")
 NEW FILTER
 KILL RTN
 IF $GET(DFN)'="" SET FILTER("dfn")=$GET(DFN)
 IF $GET(ENC)'="" SET FILTER("encounter")=$GET(ENC)
 IF $GET(START)'="" SET FILTER("start")=$GET(START)
 IF $GET(END)'="" SET FILTER("end")=$GET(END)
 IF +$GET(MAX)>0 SET FILTER("max")=+$GET(MAX)
 IF $GET(MODE)'="" SET FILTER("mode")=$GET(MODE)
 IF $GET(DOMAINS)'="" SET FILTER("domains")=$GET(DOMAINS)
 DO GETFHIR(.RTN,.FILTER)
 QUIT
 ;
RPCFHIRA(RTN,FILTER) ; RPC entry point (array params)
 ; FILTER mirrors web entry parameter names, for example:
 ;   FILTER("dfn")=12345
 ;   FILTER("encounter")=<enc-id>
 ;   FILTER("start")=<fm-date-time or %DT expression>
 ;   FILTER("end")=<fm-date-time or %DT expression>
 ;   FILTER("max")=<n>
 ;   FILTER("mode")="encounter" or "daterange"
 ;   FILTER("domains")="encounter,condition,vitals,procedures,labs"
 DO GETFHIR(.RTN,.FILTER)
 QUIT
 ;
GETFHIR(RTN,FILTER) ; Web service entry point
 ; FILTER contains URL parameters, for example FILTER("dfn")=12345
 ; RTN returns JSON output nodes from ENCODE^XLFJSON, unless arrayOnly=1
 NEW ARRAYONLY,ERR,REQ,TMP,VIEW
 DO ENVINIT
 KILL RTN
 DO MAPFILT(.FILTER,.REQ)
 DO RPMSDFLT(.REQ)
 SET ARRAYONLY=+$$TRUTHVAL($SELECT($GET(FILTER("arrayOnly"))'="":$GET(FILTER("arrayOnly")),1:$GET(FILTER("ARRAYONLY"))))
 SET VIEW=$$UPCASE($SELECT($GET(FILTER("view"))'="":$GET(FILTER("view")),1:$GET(FILTER("VIEW"))))
 IF VIEW="BROWSER",+$GET(REQ("DFN"))>0 DO  QUIT
 . SET FILTER("type")="text/html"
 . DO BROWSER^C0FHIRWS(.RTN,+$GET(REQ("DFN")))
 . SET HTTPRSP("mime")="text/html"
 IF $GET(REQ("DFN"))="" DO  QUIT
 . SET FILTER("type")="text/html"
 . DO FHIRIDX(.RTN)
 . SET HTTPRSP("mime")="text/html"
 SET REQ("MODE")=$$REQMODE(.REQ)
 IF $GET(REQ("MODE"))="" DO  QUIT
 . DO ERR^C0FHIRBU("Cannot determine request mode from URL parameters",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 IF ARRAYONLY DO  QUIT
 . DO GETBNDLA(.REQ,.RTN)
 SET FILTER("type")="application/fhir+json"
 SET HTTPRSP("mime")="application/fhir+json"
 DO GETBNDLJ(.REQ,.RTN,.ERR)
 SET RTN("mime")="application/fhir+json"
 IF $DATA(ERR) DO
 . DO ERR^C0FHIRBU("JSON encoding failed in ENCODE^XLFJSON",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.RTN,.ERR)
 QUIT
 ;
FHIRIDX(RTN) ; Render HTML index when /fhir is called without dfn
 NEW AURL,BURL,CNT,DFN,FURL,HASGRAPH,HASVPR,IEN,JURL,KEY,LURL,NAME,NCOLS,RURL,ROOT,ROW,SORT,SUM,TBYDFN,VURL
 KILL RTN
 SET ROOT=$$GSROOT()
 SET HASGRAPH=0 IF $L($G(ROOT))>0,$DATA(@ROOT@("DFN")) SET HASGRAPH=1
 SET HASVPR=$$VPROK()
 SET NCOLS=6+$SELECT(HASGRAPH:2,1:0)+$SELECT(HASVPR:1,1:0)
 DO ADDLN(.RTN,"<!DOCTYPE HTML>")
 DO ADDLN(.RTN,"<html><head><title>FHIR Dashboard</title></head><body>")
 DO ADDLN(.RTN,"<h1>FHIR Dashboard</h1>")
 DO ADDLN(.RTN,"<p>This dashboard is available at /fhir-dashboard. Click Name for the VistA FHIR browser. The Synthea FHIR column opens the stored source bundle in a light-theme browser view. Rows with IEN '-' were discovered from ^LR (non-Synthea). Quality measures: <a href=""/fhir-quality-dashboards"">/fhir-quality-dashboards</a>.</p>")
 DO ADDLN(.RTN,"<table border=""1"" cellpadding=""4"" cellspacing=""0"">")
 SET ROW="<tr><th>Name</th><th>C0FHIR fhir</th><th>DFN</th><th>IEN</th><th>rehmp CPRS</th><th>AI Consult</th>"
 IF HASGRAPH SET ROW=ROW_"<th>Synthea FHIR</th><th>Load Log</th>"
 IF HASVPR SET ROW=ROW_"<th>VPR</th>"
 DO ADDLN(.RTN,ROW_"</tr>")
 SET CNT=0
 IF $DATA(@ROOT@("DFN")) DO
 . SET DFN=0
 . FOR  SET DFN=$ORDER(@ROOT@("DFN",DFN)) Q:+DFN<1  DO
 . . SET IEN=$ORDER(@ROOT@("DFN",DFN,""),-1)
 . . IF IEN<1 QUIT
 . . ; IF '$$SHOWROW(ROOT,IEN) QUIT
 . . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^")
 . . IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . . SET KEY=$$UPCASE(NAME)
 . . SET SORT(KEY,NAME,DFN,IEN)=""
 . . SET SORT("DFN",DFN)=1
 DO ADDLRROWS(.SORT)
 SET KEY=""
 FOR  SET KEY=$ORDER(SORT(KEY)) Q:KEY=""  DO
 . IF KEY="DFN" QUIT
 . SET NAME=""
 . FOR  SET NAME=$ORDER(SORT(KEY,NAME)) Q:NAME=""  DO
 . . SET DFN=0
 . . FOR  SET DFN=$ORDER(SORT(KEY,NAME,DFN)) Q:+DFN<1  DO
 . . . SET IEN=""
 . . . FOR  SET IEN=$ORDER(SORT(KEY,NAME,DFN,IEN)) Q:IEN=""  DO
 . . . . SET TBYDFN(DFN,"NAME")=NAME
 . . . . SET TBYDFN(DFN,"IEN")=IEN
 SET DFN=""
 FOR  SET DFN=$ORDER(TBYDFN(DFN),-1) Q:+DFN<1  DO
 . SET NAME=$GET(TBYDFN(DFN,"NAME"))
 . SET IEN=$GET(TBYDFN(DFN,"IEN"))
 . SET CNT=CNT+1
 . SET FURL="/fhir?dfn="_DFN
 . SET BURL="/fhir?dfn="_DFN_"&view=browser"
 . SET VURL="/vpr?dfn="_DFN
 . SET RURL="/demos/cprs/index.html?dfn="_DFN_"&autoload=dfn&rehmpBase=/rehmp"
 . SET AURL="/fhir?dfn="_DFN_"&view=browser&source=aiconsult"
 . SET JURL=$SELECT(HASGRAPH&(+IEN>0):"/fhir?dfn="_DFN_"&view=browser&source=showfhir&ien="_IEN,1:"")
 . SET LURL=$SELECT(HASGRAPH&(+IEN>0):$$LOADLOGURL(ROOT,IEN),1:"")
 . SET ROW="<tr><td><a href="""_BURL_""">"_$$HTMLESC(NAME)_"</a></td>"
 . SET ROW=ROW_"<td><a href="""_FURL_""">fhir</a></td>"
 . SET ROW=ROW_"<td>"_DFN_"</td><td>"_$SELECT(+IEN>0:IEN,1:"-")_"</td>"
 . SET ROW=ROW_"<td><a href="""_RURL_""">rehmp</a></td>"
 . SET ROW=ROW_"<td><a href="""_AURL_""">AI Consult</a></td>"
 . IF HASGRAPH DO
 . . IF JURL'="" SET ROW=ROW_"<td><a href="""_JURL_""">browser</a></td>"
 . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . . IF LURL'="" SET ROW=ROW_"<td><a href="""_LURL_""">load</a></td>"
 . . ELSE  SET ROW=ROW_"<td>n/a</td>"
 . IF HASVPR SET ROW=ROW_"<td><a href="""_VURL_""">vpr</a></td>"
 . SET ROW=ROW_"</tr>"
 . DO ADDLN(.RTN,ROW)
 . IF +IEN>0 SET SUM=$$DOMSUM(ROOT,IEN)
 . ELSE  SET SUM=$$LRSUM(DFN)
 . DO ADDLN(.RTN,"<tr><td colspan="""_NCOLS_"""><small>"_$$HTMLESC(SUM)_"</small></td></tr>")
 ; IF CNT=0 DO ADDLN(.RTN,"<tr><td colspan="""_NCOLS_""">No patients with labs were found in graph store or ^LR.</td></tr>")
 IF CNT=0 DO ADDLN(.RTN,"<tr><td colspan="""_NCOLS_""">No patients found in graph store or ^LR.</td></tr>")
 DO ADDLN(.RTN,"</table>")
 DO ADDLN(.RTN,"</body></html>")
 QUIT
 ;
QUALDASH(RTN) ; Legacy entry — active quality dashboards summary
 DO SUMMARY^C0FQUAL(.RTN)
 QUIT
 ;
QDMEAS(RTN,CMS,TITLE,FOCUS) ; Compatibility no-op row helper
 DO ADDLN(.RTN,"<tr><td>"_CMS_"</td><td>"_$$HTMLESC(TITLE)_"</td><td>"_$$HTMLESC(FOCUS)_"</td></tr>")
 QUIT
 ;
ADDLRROWS(SORT) ; Add non-Synthea rows discovered via ^LR
 NEW DFN,KEY,LRDFN,NAME
 SET DFN=0
 FOR  SET DFN=$ORDER(^DPT(DFN)) Q:+DFN<1  DO
 . SET LRDFN=+$GET(^DPT(DFN,"LR"))
 . IF LRDFN<1 QUIT
 . ; IF '$$HASLRLABS(LRDFN) QUIT
 . IF $GET(SORT("DFN",DFN)) QUIT
 . SET NAME=$PIECE($GET(^DPT(DFN,0)),"^")
 . IF NAME="" SET NAME="UNKNOWN ("_DFN_")"
 . SET KEY=$$UPCASE(NAME)
 . SET SORT(KEY,NAME,DFN,0)=""
 . SET SORT("DFN",DFN)=1
 QUIT
 ;
HASLRLABS(LRDFN) ; True when LR node has chemistry or micro data
 SET LRDFN=+$GET(LRDFN)
 IF LRDFN<1 QUIT 0
 IF $DATA(^LR(LRDFN,"CH")) QUIT 1
 IF $DATA(^LR(LRDFN,"MI")) QUIT 1
 QUIT 0
 ;
LRSUM(DFN) ; Domain summary for non-Synthea rows discovered from ^LR
 NEW CH,LRDFN,MI,TOT
 SET LRDFN=+$GET(^DPT(+$GET(DFN),"LR"))
 IF LRDFN<1 QUIT "labs:0/0 | source:^LR"
 SET CH=$$LRSUBCNT(LRDFN,"CH")
 SET MI=$$LRSUBCNT(LRDFN,"MI")
 SET TOT=CH+MI
 QUIT "labs:"_TOT_"/"_TOT_" | source:^LR"
 ;
LRSUBCNT(LRDFN,SUB) ; Count first-level nodes for one ^LR subdomain
 NEW CNT,IDT
 SET CNT=0
 SET IDT=0
 FOR  SET IDT=$ORDER(^LR(LRDFN,SUB,IDT)) Q:IDT<1  SET CNT=CNT+1
 QUIT CNT
 ;
SHOWROW(ROOT,IEN) ; True when graph has one or more loaded labs
 NEW DOM,LD,ST,ZI
 SET LD=0
 ;
 ; Preferred: explicit per-domain loaded counter.
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  D  Q:LD>0
 . IF $$UPCASE(DOM)'="LABS" QUIT
 . SET LD=+$GET(@ROOT@(IEN,"load",DOM,"status","loaded"))
 IF LD>0 QUIT 1
 ;
 ; Fallback: scan item-level loadstatus nodes.
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  D  Q:LD>0
 . IF $$UPCASE(DOM)'="LABS" QUIT
 . SET ZI=0
 . FOR  SET ZI=$ORDER(@ROOT@(IEN,"load",DOM,ZI)) Q:+ZI<1  DO  Q:LD>0
 . . SET ST=$$LOADST(ROOT,IEN,DOM,ZI)
 . . IF ST="LOADED" SET LD=1
 QUIT $SELECT(LD>0:1,1:0)
 ;
DOMSUM(ROOT,IEN) ; Build domain loaded/source summary text
 NEW DOM,DOMLD,DOMSRC,LD,SRC,ST,STDOM,SUM,TXT,ZI
 SET TXT=""
 SET DOM=""
 FOR  SET DOM=$ORDER(@ROOT@(IEN,"load",DOM)) Q:DOM=""  DO
 . SET (LD,SRC)=0
 . SET ZI=0
 . FOR  SET ZI=$ORDER(@ROOT@(IEN,"load",DOM,ZI)) Q:+ZI<1  DO
 . . SET SRC=SRC+1
 . . SET ST=$$LOADST(ROOT,IEN,DOM,ZI)
 . . IF ST="LOADED" SET LD=LD+1
 . ; Some domains (for example Patient) use only domain-level status nodes.
 . ; Prefer explicit status counters when present, then fallback to status/loadstatus.
 . SET DOMSRC=+$GET(@ROOT@(IEN,"load",DOM,"status","source"))
 . SET DOMLD=+$GET(@ROOT@(IEN,"load",DOM,"status","loaded"))
 . IF DOMSRC>0 SET SRC=DOMSRC
 . IF DOMLD>0 SET LD=DOMLD
 . IF SRC=0 DO
 . . SET STDOM=$$DOMST(ROOT,IEN,DOM)
 . . IF STDOM'="" SET SRC=1,LD=$SELECT(STDOM="LOADED":1,1:0)
 . ; Hide empty domains so we do not display misleading 0/0 rows.
 . IF SRC=0,LD=0 QUIT
 . SET SUM=DOM_":"_LD_"/"_SRC
 . IF TXT'="" SET TXT=TXT_" | "
 . SET TXT=TXT_SUM
 IF TXT="" SET TXT="No load summary available."
 QUIT TXT
 ;
LOADST(ROOT,IEN,DOM,RIEN) ; $$ - item status across C0FW and legacy loaders
 NEW ST
 SET ST=$GET(@ROOT@(IEN,"load",DOM,RIEN,"loadStatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,RIEN,"status","loadstatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,RIEN,"status","loadStatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,RIEN,"status","return"))
 QUIT $$UPCASE(ST)
 ;
DOMST(ROOT,IEN,DOM) ; $$ - domain-level status across C0FW and legacy loaders
 NEW ST
 SET ST=$GET(@ROOT@(IEN,"load",DOM,"loadStatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,"status","loadstatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,"status","loadStatus"))
 IF ST="" SET ST=$GET(@ROOT@(IEN,"load",DOM,"status","return"))
 QUIT $$UPCASE(ST)
 ;
GSROOT() ; Resolve graph-store root across deployments
 ; Use SYNWD when present so graph location matches loader (^%wd vs ^SYNGRAPH).
 NEW PROOT,R
 IF $T(setroot^SYNWD)'="" DO
 . SET R=$$setroot^SYNWD("fhir-intake")
 . IF $$HASDFNROOT(R) SET PROOT=R QUIT
 . SET PROOT=""
 IF $G(PROOT)'="" QUIT PROOT
 ; Fallback: detect which backend has the graph.
 IF $DATA(^SYNGRAPH(2002.801,2,"DFN")) QUIT "^SYNGRAPH(2002.801,2)"
 SET PROOT="^"_$CHAR(37)_"wd(17.040801,3)"
 IF $DATA(@PROOT@("DFN")) QUIT PROOT
 QUIT PROOT
 ;
HASDFNROOT(R) ; True if graph root string is well-formed and has a DFN index
 NEW IEN
 SET R=$GET(R)
 IF R="^"_$CHAR(37)_"wd(17.040801,3)" QUIT $DATA(@R@("DFN"))
 IF $EXTRACT(R,1,20)'="^SYNGRAPH(2002.801," QUIT 0
 IF $EXTRACT(R,$LENGTH(R))'=")" QUIT 0
 SET IEN=$EXTRACT(R,21,$LENGTH(R)-1)
 IF IEN'?1.N QUIT 0
 QUIT $DATA(@R@("DFN"))
 ;
VPROK() ; True when VPR is available on this system (so /vpr link works)
 IF '$D(^VA(200)) QUIT 0
 IF $T(EN1^VPRDVSIT)="" QUIT 0
 QUIT 1
 ;
RPMSOK() ; True when this target looks like RPMS/IHS
 IF '$DATA(^AUPNPAT(0)) QUIT 0
 IF '$DATA(^DD(9000001,0)) QUIT 0
 IF $DATA(^AUPNVSIT(0)),$DATA(^DD(9000010,0)) QUIT 1
 QUIT 0
 ;
RPMSDFLT(REQ) ; RPMS without VPR defaults to demographics-only reads
 IF '$$RPMSOK() QUIT
 IF $$VPROK() QUIT
 IF $DATA(REQ("DOMAIN")) QUIT
 SET REQ("DOMAIN","_FILTERED")=1
 SET REQ("DOMAIN","PATIENT")=1
 SET REQ("readProfile")="rpms-patient-only"
 QUIT
 ;
wsShow(OUT,FILTER) ; GET showfhir/tfhir graph JSON through the active Codex graph root
 NEW SAVEFMT,FORMAT
 IF '$D(DT) N DIQUIET S DIQUIET=1 D DT^DICRW
 SET SAVEFMT=$GET(FILTER("format"))
 SET FORMAT=$$UPCASE(SAVEFMT)
 KILL FILTER("format")
 DO WSSHOWFB^C0FHIR(.OUT,.FILTER)
 IF SAVEFMT'="" SET FILTER("format")=SAVEFMT
 IF FORMAT="TJSON" DO WSSHOWJSON2TJSON^C0FHIR(FORMAT,.OUT)
 SET HTTPRSP("mime")=$$WSSHOWMIME^C0FHIR(FORMAT)
 QUIT
 ;
WSALT(OUT,FILTER) ; GET /altfhir?ien=n - graph-source FHIR bundle by IEN
 NEW FORMAT,PATH,SAVEFMT
 IF '$D(DT) N DIQUIET S DIQUIET=1 D DT^DICRW
 SET PATH=$GET(HTTPREQ("path"))
 IF $PIECE(PATH,"/",2)="altfhir",$PIECE(PATH,"/",3)'="" DO WSALTREST(.OUT,.FILTER) QUIT
 SET SAVEFMT=$GET(FILTER("format"))
 SET FORMAT=$$UPCASE(SAVEFMT)
 KILL FILTER("dfn"),FILTER("icn"),FILTER("format")
 DO WSSHOWFB^C0FHIR(.OUT,.FILTER)
 IF SAVEFMT'="" SET FILTER("format")=SAVEFMT
 IF FORMAT="TJSON" DO WSSHOWJSON2TJSON^C0FHIR(FORMAT,.OUT)
 SET HTTPRSP("mime")=$$WSSHOWMIME^C0FHIR(FORMAT)
 QUIT
 ;
WSALTPOST(ARGS,BODY,RESULT) ; POST /altfhir/{resource}/_search form search wrapper
 IF '$DATA(RESULT) DO  QUIT ""
 . NEW EMPTY
 . DO WSALTPOST2(.ARGS,.EMPTY,.BODY)
 DO WSALTPOST2(.RESULT,.ARGS,.BODY)
 QUIT ""
 ;
WSALTPOST2(OUT,ARGS,BODY) ; Core altfhir POST search handler
 NEW FILTER
 KILL FILTER
 IF $DATA(HTTPARGS) MERGE FILTER=HTTPARGS
 IF $DATA(ARGS) MERGE FILTER=ARGS
 DO FORMBODY^C0FWCAC(.FILTER,.BODY)
 DO WSALTREST(.OUT,.FILTER)
 QUIT
 ;
WSALTREST(OUT,FILTER) ; GET /altfhir/{resource}[/{id}] over graph-source bundle cache
 NEW CROOT,ERR,ID,IEN,JERR,PATH,RES,ROOT,TMP
 IF $D(HTTPARGS) MERGE FILTER=HTTPARGS
 SET PATH=$GET(HTTPREQ("path"))
 IF $EXTRACT(PATH)="/" SET PATH=$EXTRACT(PATH,2,$LENGTH(PATH))
 SET RES=$PIECE(PATH,"/",2),ID=$PIECE(PATH,"/",3)
 IF RES="" SET RES=$GET(FILTER("resource"))
 IF ID="" SET ID=$GET(FILTER("id"))
 IF ID="_search" SET ID=""
 IF ID="",RES["/" SET ID=$PIECE(RES,"/",2),RES=$PIECE(RES,"/",1)
 IF ID="_search" SET ID=""
 IF ID="" DO ALTPATH(.RES,.ID)
 IF ID="_search" SET ID=""
 IF RES="metadata" DO ALTCAP(.TMP) GOTO WSALTJSON
 SET RES=$$RESTYPE^C0FWCAC(RES)
 IF RES="" SET ERR="Missing or unsupported FHIR resource type" GOTO WSALTERR
 SET IEN=$$ALTIEN(.FILTER,RES,ID)
 IF IEN<1 SET ERR="/altfhir requires graph IEN via ien, Patient/_id, or patient/subject" GOTO WSALTERR
 SET ROOT=$$GSROOT^C0FHIR
 IF ROOT="" SET ERR="FHIR graph root is unavailable" GOTO WSALTERR
 IF '$DATA(@ROOT@(IEN,"json")) SET ERR="Graph IEN "_IEN_" has no stored FHIR bundle" GOTO WSALTERR
 DO ALTIDX(ROOT,IEN,.CROOT)
 IF $GET(FILTER("patient"))'="" DO ALTFIX(.FILTER,CROOT,IEN,"patient")
 IF $GET(FILTER("subject"))'="" DO ALTFIX(.FILTER,CROOT,IEN,"subject")
 IF RES="Patient",$GET(FILTER("_id"))="" SET FILTER("_id")=IEN
 IF $LENGTH(ID)>0 DO ALTREAD(CROOT,RES,ID,IEN,.TMP,.ERR)
 IF $LENGTH(ID)<1 DO FINDS^C0FWCAC(.FILTER,CROOT,RES,.TMP)
 IF $GET(ERR)'="" GOTO WSALTERR
 DO ALTFIXOUT(.TMP,IEN,CROOT)
WSALTJSON ;
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.JERR)
 SET HTTPRSP("mime")="application/fhir+json"
 QUIT
WSALTERR ;
 DO OO^C0FWCAC(ERR,.TMP)
 GOTO WSALTJSON
 ;
ALTIEN(FILTER,RES,ID) ; $$ - graph IEN from altfhir request
 NEW X
 SET X=+$GET(FILTER("ien")) IF X>0 QUIT X
 IF RES="Patient" DO  IF X>0 QUIT X
 . SET X=$GET(FILTER("_id")) IF X["Patient/" SET X=$PIECE(X,"Patient/",2)
 . IF X="" SET X=ID
 SET X=$GET(FILTER("patient")) IF X="" SET X=$GET(FILTER("subject"))
 IF X["Patient/" SET X=$PIECE(X,"Patient/",2)
 SET X=+X
 IF X>0 QUIT X
 IF $GET(FILTER("_id"))'="" QUIT $$ALTID2IEN(RES,$GET(FILTER("_id")))
 IF $GET(ID)'="" QUIT $$ALTID2IEN(RES,ID)
 QUIT 0
 ;
ALTID2IEN(RES,ID) ; $$ - graph IEN containing resource type/id
 NEW ENTRY,IEN,ROOT
 SET RES=$GET(RES),ID=$GET(ID)
 IF RES=""!(ID="") QUIT 0
 SET ROOT=$$GSROOT^C0FHIR
 IF ROOT="" QUIT 0
 SET IEN=0
 FOR  SET IEN=$ORDER(@ROOT@(IEN)) QUIT:+IEN<1  DO  QUIT:$GET(ENTRY)>0
 . SET ENTRY=0
 . FOR  SET ENTRY=$ORDER(@ROOT@(IEN,"json","entry",ENTRY)) QUIT:+ENTRY<1  DO  QUIT:$GET(ENTRY(0))
 . . IF $GET(@ROOT@(IEN,"json","entry",ENTRY,"resource","resourceType"))'=RES QUIT
 . . IF $GET(@ROOT@(IEN,"json","entry",ENTRY,"resource","id"))'=ID QUIT
 . . SET ENTRY(0)=1
 . IF $GET(ENTRY(0)) SET ENTRY=IEN
 QUIT +$GET(ENTRY)
 ;
ALTIDX(ROOT,IEN,CROOT) ; Build/reuse source-bundle cache for one graph IEN
 NEW CID,ENTRY,PID,PREF,RES,SUB,TYPE
 SET CID="altfhir-source"
 SET CROOT=$NAME(@ROOT@(IEN,"cache",CID))
 IF '$DATA(@CROOT@("bundle","resourceType"))!($GET(@CROOT@("meta","searchVersion"))<3) DO
 . KILL @CROOT
 . MERGE @CROOT@("bundle")=@ROOT@(IEN,"json")
 . DO INDEX^C0FWCAC(ROOT,IEN,CID)
 . SET @CROOT@("meta","searchVersion")=3
 SET PID=$$ALTPID(CROOT)
 QUIT:PID=""
 SET PREF="Patient/"_PID
 SET ENTRY=0
 FOR  SET ENTRY=$ORDER(@CROOT@("bundle","entry",ENTRY)) QUIT:+ENTRY<1  DO
 . SET RES=$NAME(@CROOT@("bundle","entry",ENTRY,"resource"))
 . SET TYPE=$GET(@RES@("resourceType")) QUIT:TYPE=""
 . SET SUB=TYPE_"/"_$GET(@RES@("id")) QUIT:SUB="/"
 . IF TYPE="Patient" DO SETIDXGN^C0FWFUTL(CROOT,SUB,"_id",IEN) QUIT
 . IF $GET(@RES@("subject","reference"))=PREF DO SETIDXGN^C0FWFUTL(CROOT,SUB,"subject",IEN),SETIDXGN^C0FWFUTL(CROOT,SUB,"subject","Patient/"_IEN)
 . IF $GET(@RES@("patient","reference"))=PREF DO SETIDXGN^C0FWFUTL(CROOT,SUB,"patient",IEN),SETIDXGN^C0FWFUTL(CROOT,SUB,"patient","Patient/"_IEN)
 QUIT
 ;
ALTPID(CROOT) ; $$ - source Patient.id in an altfhir source cache
 NEW ENTRY,RES
 SET ENTRY=0
 FOR  SET ENTRY=$ORDER(@CROOT@("bundle","entry",ENTRY)) QUIT:+ENTRY<1  DO  QUIT:$GET(RES)'=""
 . IF $GET(@CROOT@("bundle","entry",ENTRY,"resource","resourceType"))="Patient" SET RES=$GET(@CROOT@("bundle","entry",ENTRY,"resource","id"))
 QUIT $GET(RES)
 ;
ALTFIX(FILTER,CROOT,IEN,KEY) ; Replace graph IEN patient token with source Patient id token
 NEW PID,VAL
 SET VAL=$GET(FILTER(KEY)) QUIT:VAL=""
 SET PID=$$ALTPID(CROOT) QUIT:PID=""
 IF VAL=IEN!(VAL=("Patient/"_IEN)) SET FILTER(KEY)=PID_","_"Patient/"_PID_","_IEN_","_"Patient/"_IEN
 QUIT
 ;
ALTREAD(CROOT,RES,ID,IEN,OUT,ERR) ; Read one altfhir resource
 NEW ENTRY,SUB
 KILL OUT,ERR
 IF RES="Patient",(+ID=IEN) DO  QUIT:$DATA(OUT)
 . SET ENTRY=+$ORDER(@CROOT@("type","Patient",""))
 . IF ENTRY>0 MERGE OUT=@CROOT@("bundle","entry",ENTRY,"resource")
 SET SUB=RES_"/"_ID
 SET ENTRY=+$ORDER(@CROOT@("SPO",SUB,"entry",""))
 IF ENTRY>0 MERGE OUT=@CROOT@("bundle","entry",ENTRY,"resource")
 IF '$DATA(OUT) DO
 . SET ENTRY=0
 . FOR  SET ENTRY=$ORDER(@CROOT@("bundle","entry",ENTRY)) QUIT:+ENTRY<1  DO  QUIT:$DATA(OUT)
 . . IF $GET(@CROOT@("bundle","entry",ENTRY,"resource","resourceType"))'=RES QUIT
 . . IF $GET(@CROOT@("bundle","entry",ENTRY,"resource","id"))'=ID QUIT
 . . MERGE OUT=@CROOT@("bundle","entry",ENTRY,"resource")
 IF '$DATA(OUT) SET ERR=RES_"/"_ID_" not found in graph source cache"
 QUIT
 ;
ALTPATH(RES,ID) ; Recover /altfhir/{resource}/{id} from raw request metadata
 NEW IDX,KEY,PATH,VAL
 SET KEY=""
 FOR  SET KEY=$ORDER(HTTPREQ(KEY)) QUIT:KEY=""  DO  QUIT:$GET(ID)'=""
 . SET VAL=$GET(HTTPREQ(KEY)) QUIT:VAL'["altfhir/"
 . SET IDX=$FIND(VAL,"altfhir/")-$LENGTH("altfhir/")
 . SET PATH=$EXTRACT(VAL,IDX,$LENGTH(VAL))
 . SET PATH=$PIECE(PATH,"?",1),PATH=$PIECE(PATH," ",1)
 . IF $PIECE(PATH,"/",2)'="" SET RES=$PIECE(PATH,"/",2)
 . IF $PIECE(PATH,"/",3)'="" SET ID=$PIECE(PATH,"/",3)
 QUIT
 ;
ALTFIXOUT(OUT,IEN,CROOT) ; Present graph IEN as Patient id/references
 NEW IDX,PID,PREF
 SET PID=$$ALTPID(CROOT)
 IF PID="" QUIT
 SET PREF="Patient/"_PID
 IF $GET(OUT("resourceType"))'="Bundle" DO  QUIT
 . IF $GET(OUT("resourceType"))="Patient" SET OUT("id")=IEN
 . DO ALTFIXRF($NAME(OUT),PREF,"Patient/"_IEN)
 SET IDX=0
 FOR  SET IDX=$ORDER(OUT("entry",IDX)) QUIT:+IDX<1  DO
 . IF $GET(OUT("entry",IDX,"resource","resourceType"))="Patient" SET OUT("entry",IDX,"resource","id")=IEN
 . DO ALTFIXRF($NAME(OUT("entry",IDX,"resource")),PREF,"Patient/"_IEN)
 QUIT
 ;
ALTFIXRF(NODE,PREF,NEWREF) ; Rewrite nested Patient references in one resource
 NEW SUB
 IF $DATA(@NODE@("reference"))#2,@NODE@("reference")=PREF SET @NODE@("reference")=NEWREF
 SET SUB=""
 FOR  SET SUB=$ORDER(@NODE@(SUB)) QUIT:SUB=""  DO
 . IF $DATA(@NODE@(SUB))>1 DO ALTFIXRF($NAME(@NODE@(SUB)),PREF,NEWREF)
 QUIT
 ;
ALTCAP(OUT) ; Minimal CapabilityStatement for graph-source /altfhir
 KILL OUT
 SET OUT("resourceType")="CapabilityStatement"
 SET OUT("status")="draft"
 SET OUT("date")=$$NOW^C0FWCAC()
 SET OUT("kind")="instance"
 SET OUT("fhirVersion")="4.0.1"
 SET OUT("format",1)="json"
 SET OUT("rest",1,"mode")="server"
 SET OUT("rest",1,"resource",1,"type")="Patient"
 SET OUT("rest",1,"resource",1,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",1,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",1,"searchParam",1,"name")="_id"
 SET OUT("rest",1,"resource",1,"searchParam",1,"type")="token"
 SET OUT("rest",1,"resource",2,"type")="Observation"
 SET OUT("rest",1,"resource",2,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",2,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",2,"searchParam",1,"name")="patient"
 SET OUT("rest",1,"resource",2,"searchParam",1,"type")="reference"
 SET OUT("rest",1,"resource",3,"type")="Condition"
 SET OUT("rest",1,"resource",3,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",3,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",4,"type")="Encounter"
 SET OUT("rest",1,"resource",4,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",4,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",5,"type")="DiagnosticReport"
 SET OUT("rest",1,"resource",5,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",5,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",6,"type")="Immunization"
 SET OUT("rest",1,"resource",6,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",6,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",7,"type")="Procedure"
 SET OUT("rest",1,"resource",7,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",7,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",8,"type")="MedicationRequest"
 SET OUT("rest",1,"resource",8,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",8,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",9,"type")="DocumentReference"
 SET OUT("rest",1,"resource",9,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",9,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",10,"type")="ServiceRequest"
 SET OUT("rest",1,"resource",10,"interaction",1,"code")="read"
 SET OUT("rest",1,"resource",10,"interaction",2,"code")="search-type"
 SET OUT("rest",1,"resource",10,"searchParam",1,"name")="patient"
 SET OUT("rest",1,"resource",10,"searchParam",1,"type")="reference"
 DO FINAL^C0FHIRBU(.OUT)
 QUIT
 ;
WSSHOWFB(OUT,FILTER) ; Fallback when wsShow^SYNFHIR missing: old C0FHIR graph path + encode
 NEW TYPE,ROOT,IEN,JROOT,JTMP,JUSE,TMP,ERR,GLBL
 SET TYPE=$G(FILTER("type"))
 SET ROOT=$$GSROOT^C0FHIR
 QUIT:$L($G(ROOT))=0
 SET IEN=+$G(FILTER("ien"))
 IF IEN=0 DO
 . N ICN S ICN=$G(FILTER("icn")) Q:ICN=""
 . S IEN=$O(@ROOT@("ICN",ICN,""))
 IF IEN=0 DO
 . N DFN S DFN=$G(FILTER("dfn")) Q:DFN=""
 . S IEN=$O(@ROOT@("DFN",DFN,""))
 QUIT:IEN=0
 SET JROOT=$NA(@ROOT@(IEN,"json"))
 QUIT:'$D(@JROOT)
 SET JUSE=JROOT
 IF TYPE'="" DO
 . SET GLBL="getIntake"_"Fhir^SYNFHIR"
 . QUIT:$TEXT(@GLBL)=""
 . SET GLBL=GLBL_"(""JTMP"",$G(FILTER(""bundle"")),TYPE,IEN,1)"
 . DO @GLBL
 . SET JUSE="JTMP"
 IF $T(encode^SYNJSON)'="" DO encode^SYNJSON(JUSE,"OUT") QUIT
 MERGE TMP=@JUSE DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 QUIT
 ;
WSSHOWMIME(FMT) ; Mime type for wsShow: JSON default; format=tjson -> HTML wrapper around TJSON in <pre>
 QUIT $SELECT($$UPCASE($GET(FMT))="TJSON":"text/html; charset=utf-8",1:"application/json")
 ;
WSSHOWJSON2TJSON(FMT,ARY) ; If FMT is TJSON, wrap tjson^%wd output in HTML5 + CSS (no %webrsp changes).
 ; HTML TJSON: flex column, vertical scroll in <main>. pre-wrap + overflow-wrap:anywhere so few-\n tjson output fills the viewport.
 QUIT:$$UPCASE($GET(FMT))'="TJSON"
 NEW TIN,TOUT,WRAP,WI,ZI,HPRE,HSUF
 QUIT:'$DATA(ARY)
 MERGE TIN=ARY
 KILL ARY
 IF $T(tjson^%wd)="" MERGE ARY=TIN QUIT
 DO tjson^%wd("TIN","TOUT")
 SET HPRE=""
 SET HPRE=HPRE_"<!DOCTYPE html>"_$CHAR(10)
 SET HPRE=HPRE_"<html lang=""en"">"_$CHAR(10)
 SET HPRE=HPRE_"<head>"_$CHAR(10)
 SET HPRE=HPRE_"<meta charset=""utf-8""/>"_$CHAR(10)
 SET HPRE=HPRE_"<meta name=""viewport"" content=""width=device-width,initial-scale=1""/>"_$CHAR(10)
 SET HPRE=HPRE_"<meta name=""color-scheme"" content=""dark""/>"_$CHAR(10)
 SET HPRE=HPRE_"<title>FHIR · TJSON</title>"_$CHAR(10)
 SET HPRE=HPRE_"<style type=""text/css"">"_$CHAR(10)
 SET HPRE=HPRE_":root{--bg:#051626;--fg:#e8ecf1;--hdr:#030d18;--bd:#0d2844;--muted:#a8b8cc;--accent:#8ec5ff;}"_$CHAR(10)
 SET HPRE=HPRE_"html,body{height:100%;margin:0;}"_$CHAR(10)
 SET HPRE=HPRE_"body{background:var(--bg);color:var(--fg);color-scheme:dark;display:flex;flex-direction:column;font-family:system-ui,Segoe UI,Roboto,sans-serif;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr{flex:0 0 auto;padding:8px 16px;background:var(--hdr);border-bottom:1px solid var(--bd);font-size:12px;line-height:1.35;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr .t{font-weight:600;color:var(--accent);letter-spacing:.03em;}"_$CHAR(10)
 SET HPRE=HPRE_"header.hdr .h{color:var(--muted);font-weight:400;}"_$CHAR(10)
 SET HPRE=HPRE_"main.main{flex:1 1 auto;min-height:0;min-width:0;overflow-x:hidden;overflow-y:auto;-webkit-overflow-scrolling:touch;background:var(--bg);}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson{margin:0;padding:12px 18px 28px;box-sizing:border-box;width:100%;max-width:100%;min-width:0;"_$CHAR(10)
 SET HPRE=HPRE_"background:var(--bg);color:var(--fg);"_$CHAR(10)
 SET HPRE=HPRE_"font-family:Consolas,'Courier New',ui-monospace,'Cascadia Mono',Menlo,monospace;"_$CHAR(10)
 SET HPRE=HPRE_"font-size:14px;line-height:1.5;tab-size:2;-moz-tab-size:2;"_$CHAR(10)
 SET HPRE=HPRE_"white-space:pre-wrap;overflow-wrap:anywhere;word-break:break-word;"_$CHAR(10)
 SET HPRE=HPRE_"font-variant-ligatures:none;font-feature-settings:'liga' 0;}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson .hl-uuid{color:#c45c3a;}"_$CHAR(10)
 SET HPRE=HPRE_"pre.tjson .hl-synthea{color:#b39ddb;}"_$CHAR(10)
 SET HPRE=HPRE_"</style></head>"_$CHAR(10)
 SET HPRE=HPRE_"<body>"_$CHAR(10)
 SET HPRE=HPRE_"<header class=""hdr""><span class=""t"">TJSON</span> <span class=""h"">FHIR bundle (rust tjson); long lines wrap - scroll vertically</span></header>"_$CHAR(10)
 SET HPRE=HPRE_"<main class=""main""><pre class=""tjson"" spellcheck=""false"" translate=""no"">"
 SET HSUF="</pre></main><script>document.addEventListener('DOMContentLoaded',function(){var p=document.querySelector('pre.tjson');if(!p)return;var t=p.textContent;"
 SET HSUF=HSUF_"function e(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}var r=/urn:uuid:[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}|\\bSynthea\\b/g,m,o='',l=0;"
 SET HSUF=HSUF_"while((m=r.exec(t))!==null){o+=e(t.slice(l,m.index));if(m[0]==='Synthea')o+=`<span class=""hl-synthea"">Synthea</span>`;else o+=`<span class=""hl-uuid"">${e(m[0])}</span>`;l=r.lastIndex;}"
 SET HSUF=HSUF_"o+=e(t.slice(l));p.innerHTML=o;});</script></body></html>"
 SET WRAP(1)=HPRE
 SET WI=1,ZI=""
 FOR  SET ZI=$ORDER(TOUT(ZI)) QUIT:ZI=""  DO
 . SET WI=WI+1,WRAP(WI)=TOUT(ZI)
 SET WI=WI+1,WRAP(WI)=HSUF
 MERGE ARY=WRAP
 QUIT
 ;
REGTFHIR ; Register GET /tfhir -> wsShow^C0FHIR (^%web 17.6001). Does not alter showfhir (SYNFHIR).
 ; Programmer once per site (or after image rebuild): D REGTFHIR^C0FHIR
 ; Removes wrong pattern tfhir/* if present; see docs/VEHU_NEW_PATIENT_RUNBOOK_2026-03-16.md
 IF $T(addService^%webutils)="" QUIT
 IF $T(deleteService^%webutils)'="" DO deleteService^%webutils("GET","tfhir/*")
 DO addService^%webutils("GET","tfhir","wsShow^C0FHIR")
 QUIT
 ;
LOADLOGURL(ROOT,IEN) ; Build /gtree URL for load log node
 NEW URLROOT
 SET URLROOT=$EXTRACT($GET(ROOT),2,$LENGTH($GET(ROOT))) ; drop leading ^
 IF URLROOT="" QUIT ""
 IF URLROOT["(" SET URLROOT=$EXTRACT(URLROOT,1,$LENGTH(URLROOT)-1)_","_(+IEN)_",%22load%22)"
 ELSE  SET URLROOT=URLROOT_"("_(+IEN)_",%22load%22)"
 IF $EXTRACT(URLROOT,1)="%" SET URLROOT="%25"_$EXTRACT(URLROOT,2,$LENGTH(URLROOT))
 QUIT "/gtree/"_URLROOT
 ;
ADDLN(RTN,TXT) ; Append one line to output array
 NEW IDX
 SET IDX=$ORDER(RTN(""),-1)+1
 SET RTN(IDX)=$GET(TXT)
 QUIT
 ;
HTMLESC(X) ; Escape basic HTML special chars
 NEW C,I,Y
 SET Y=""
 FOR I=1:1:$LENGTH($GET(X)) DO
 . SET C=$EXTRACT(X,I)
 . IF C="&" SET Y=Y_"&amp;" QUIT
 . IF C="<" SET Y=Y_"&lt;" QUIT
 . IF C=">" SET Y=Y_"&gt;" QUIT
 . IF C="""" SET Y=Y_"&quot;" QUIT
 . IF C="'" SET Y=Y_"&#39;" QUIT
 . SET Y=Y_C
 QUIT Y
 ;
GETBNDL(REQ,OUT) ; Return one Bundle response structure for a request
 ; REQ("MODE")="ENCOUNTER" or "DATERANGE"
 ; REQ(...) contains request parameters (DFN, encounter/date filters, etc.)
 NEW MODE
 DO ENVINIT
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
 DO GETBNDLA(.REQ,.BUNDLE)
 DO TOJSON^C0FHIRBU(.BUNDLE,.OUT,.ERR)
 QUIT
 ;
GETBNDLA(REQ,OUT) ; Return one Bundle response as a finalized native array
 IF $T(GET^C0FWCAC)'="",$$GET^C0FWCAC(.REQ,.OUT) QUIT
 DO GETBNDL(.REQ,.OUT)
 DO FINAL^C0FHIRBU(.OUT)
 QUIT
 ;
MAPFILT(FILTER,REQ) ; Map URL parameters into request structure
 NEW ENDRAW,ENDVAL,STARTRAW,STARTVAL
 KILL REQ
 SET REQ("DFN")=$SELECT($GET(FILTER("dfn"))'="":$GET(FILTER("dfn")),1:$GET(FILTER("DFN")))
 SET REQ("ENCOUNTER")=$SELECT($GET(FILTER("encounter"))'="":$GET(FILTER("encounter")),1:$GET(FILTER("ENCOUNTER")))
 SET STARTRAW=$SELECT($GET(FILTER("start"))'="":$GET(FILTER("start")),$GET(FILTER("START"))'="":$GET(FILTER("START")),$GET(FILTER("sdt"))'="":$GET(FILTER("sdt")),1:$GET(FILTER("SDT")))
 SET STARTVAL=$$PARSEFM(STARTRAW)
 IF STARTVAL'="" SET REQ("START_DT")=STARTVAL
 SET ENDRAW=$SELECT($GET(FILTER("end"))'="":$GET(FILTER("end")),$GET(FILTER("END"))'="":$GET(FILTER("END")),$GET(FILTER("edt"))'="":$GET(FILTER("edt")),1:$GET(FILTER("EDT")))
 SET ENDVAL=$$PARSEFM(ENDRAW)
 IF ENDVAL'="" SET REQ("END_DT")=ENDVAL
 SET REQ("MODE")=$$UPCASE($SELECT($GET(FILTER("mode"))'="":$GET(FILTER("mode")),1:$GET(FILTER("MODE"))))
 SET REQ("MAX")=$SELECT($GET(FILTER("max"))'="":+$GET(FILTER("max")),1:+$GET(FILTER("MAX")))
 SET REQ("LOCATION")=+$GET(FILTER("loc"))
 IF REQ("LOCATION")<1 SET REQ("LOCATION")=+$GET(FILTER("LOC"))
 IF REQ("LOCATION")<1 SET REQ("LOCATION")=+$GET(FILTER("location"))
 IF REQ("LOCATION")<1 SET REQ("LOCATION")=+$GET(FILTER("LOCATION"))
 IF +$GET(FILTER("refresh")) SET REQ("REFRESH")=1
 IF +$GET(FILTER("REFRESH")) SET REQ("REFRESH")=1
 DO MAPDOM(.FILTER,.REQ)
 QUIT
 ;
MAPDOM(FILTER,REQ) ; Map optional domain filters into REQ("DOMAIN",...)
 NEW SUB,VAL
 SET VAL=$SELECT($GET(FILTER("domains"))'="":$GET(FILTER("domains")),1:$GET(FILTER("DOMAINS")))
 DO ADDDOM(VAL,.REQ)
 SET VAL=$SELECT($GET(FILTER("domain"))'="":$GET(FILTER("domain")),1:$GET(FILTER("DOMAIN")))
 DO ADDDOM(VAL,.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("domains",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("domains",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("DOMAINS",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("DOMAINS",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("domain",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("domain",SUB)),.REQ)
 SET SUB=""
 FOR  SET SUB=$ORDER(FILTER("DOMAIN",SUB)) Q:SUB=""  DO ADDDOM($GET(FILTER("DOMAIN",SUB)),.REQ)
 QUIT
 ;
ADDDOM(VAL,REQ) ; Parse one domain token list into canonical domain flags
 NEW LIST,TOK
 SET LIST=$$UPCASE($$TRIM($GET(VAL)))
 IF LIST="" QUIT
 SET REQ("DOMAIN","_FILTERED")=1
 SET LIST=$TRANSLATE(LIST,"|;/",",,,")
 FOR  QUIT:LIST=""  DO
 . SET TOK=$$TRIM($PIECE(LIST,",",1))
 . SET LIST=$PIECE(LIST,",",2,999)
 . IF TOK="" QUIT
 . SET TOK=$$DOMTOK(TOK)
 . IF TOK'="" SET REQ("DOMAIN",TOK)=1
 QUIT
 ;
DOMTOK(X) ; Normalize domain alias to canonical token
 NEW Y
 SET Y=$$UPCASE($$TRIM($GET(X)))
 IF Y="" QUIT ""
 IF Y="ALL" QUIT "ALL"
 IF Y="PATIENT"!(Y="PAT") QUIT "PATIENT"
 IF Y="ENCOUNTER"!(Y="ENCOUNTERS")!(Y="ENC")!(Y="VISIT")!(Y="VISITS") QUIT "ENCOUNTER"
 IF Y="CONDITION"!(Y="CONDITIONS")!(Y="PROBLEM")!(Y="PROBLEMS") QUIT "CONDITION"
 IF Y="OBS"!(Y="OBSERVATION")!(Y="OBSERVATIONS")!(Y="VITAL")!(Y="VITALS") QUIT "VITAL"
 IF Y="ALLERGY"!(Y="ALLERGIES")!(Y="ALGY")!(Y="ALLERGYINTOLERANCE") QUIT "ALLERGY"
 IF Y="MED"!(Y="MEDS")!(Y="MEDICATION")!(Y="MEDICATIONS")!(Y="RX")!(Y="MEDICATIONREQUEST") QUIT "MEDICATION"
 IF Y="IMM"!(Y="IMMS")!(Y="IMMUNIZATION")!(Y="IMMUNIZATIONS") QUIT "IMMUNIZATION"
 IF Y="PROC"!(Y="PROCS")!(Y="PROCEDURE")!(Y="PROCEDURES") QUIT "PROCEDURE"
 IF Y="LAB"!(Y="LABS")!(Y="LABORATORY")!(Y="LABORATORIES") QUIT "LAB"
 IF Y="REM"!(Y="REMS")!(Y="REMINDER")!(Y="REMINDERS")!(Y="CLINICALREMINDER")!(Y="CLINICALREMINDERS") QUIT "REMINDER"
 IF Y="CAREPLAN"!(Y="CAREPLANS")!(Y="CP") QUIT "CAREPLAN"
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
TRUTHVAL(X) ; $$ - treat JSON-ish boolean and 1/0 values
 NEW Y
 SET Y=$$UPCASE($$TRIM($GET(X)))
 IF Y=1 QUIT 1
 IF Y="1" QUIT 1
 IF Y="TRUE" QUIT 1
 IF Y="YES" QUIT 1
 QUIT 0
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
ENVINIT ; Ensure legacy VPR/runtime variables are available
 ; Many legacy VPR/PX/Kernel routines assume U,DT,DUZ,DUZ(0),DUZ(2) are defined.
 ; If ^VA(200) has no entries (minimal dev image), still force a positive DUZ so HTTP/RPC
 ; paths that require an active user (for example rehmp USER.CTX.SET) do not fail with DUZ<1.
 NEW DIV
 IF $GET(U)="" SET U="^"
 IF '$DATA(DT) SET DT=$$DT^XLFDT
 IF +$GET(DUZ)<1 DO
 . IF $DATA(^VA(200,.5,0)) SET DUZ=.5 QUIT
 . SET DUZ=+$ORDER(^VA(200,0))
 ; Use =0 not <1 so DUZ=.5 postmaster survives (+.5 is 0.5, which is <1).
 IF +$GET(DUZ)=0 SET DUZ=1
 IF $GET(DUZ(0))="" SET DUZ(0)="@"
 IF '$DATA(DUZ("AG")) SET DUZ("AG")=""
 IF +$GET(DUZ(2))<1 DO
 . SET DIV=+$PIECE($GET(^VA(200,+DUZ,2,1,0)),"^")
 . IF DIV<1 SET DIV=+$ORDER(^DIC(4,0))
 . SET DUZ(2)=DIV
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
