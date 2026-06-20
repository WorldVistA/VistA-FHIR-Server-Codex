C0FWADD ; VEHU/Codex - C0FW /addpatient handler ;May 13, 2026
 ;;0.1;C0FHIR PROJECT;;May 13, 2026
 ;
 Q
 ;
WSPAT(ARGS,BODY,RESULT) ; POST /addpatient
 N BUNDLE,CNT,DNX,ERR,GR,GR1,ICN,ID,IEN,JSON,LASTRIEN,PATDONE,RDFN,RETURN,RIEN,ROOT,USER,ZI
 S U="^"
 S HTTPRSP("mime")="application/json"
 S USER=$$DUZ^C0FWCTX()
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" D ERR(.RESULT,"GRAPH","Unable to open fhir-intake graph") Q 0
 I '$D(BODY) D  Q 0
 . S HTTPERR=400
 . D ERR(.RESULT,"VALIDATION","Empty request body")
 M JSON=BODY
 D DECODE^XLFJSON("JSON","GR1","ERR")
 I $D(ERR) D  Q 0
 . S HTTPERR=400
 . D ERR(.RESULT,"JSON","Unable to decode addpatient JSON")
 I '$D(GR1("entry")) D  Q 0
 . S HTTPERR=400
 . D ERR(.RESULT,"VALIDATION","FHIR Bundle entry array not found")
 S ID=$G(ARGS("id"))
 S IEN=$O(@ROOT@(" "),-1)+1
 M GR(IEN,"json")=GR1
 S (ZI,CNT)=0
 F  S ZI=$O(GR1("entry",ZI)) Q:+ZI=0  S CNT=CNT+1
 S LASTRIEN=CNT
 D INDEX^C0FWIDX(IEN,"GR")
 S BUNDLE=$$BUNDLE^C0FWIDX($NA(GR(IEN)))
 M @ROOT@(IEN)=GR(IEN)
 I ID'="" S @ROOT@("B",ID,IEN)=""
 S RETURN("status")="ok"
 S RETURN("id")=ID
 S RETURN("ien")=IEN
 S RETURN("createdGraph")=1
 S RETURN("bundle")=BUNDLE
 S ARGS("bundle")=BUNDLE
 S ARGS("firstEntry")=1
 S ARGS("lastEntry")=LASTRIEN
 S C0FWBUNDLE=BUNDLE
 S RDFN=+$G(ARGS("dfn"))
 S ICN=$G(ARGS("icn")) I ICN="" S ICN=$G(ARGS("id"))
 S PATDONE=0
 I RDFN<1,ICN'="" S RDFN=+$O(^DPT("AFICN",ICN,""))
 I RDFN>0,$D(^DPT(RDFN,0)) D
 . S RETURN("dfn")=RDFN
 . S RETURN("patient","loadStatus")="linked"
 . S RETURN("patient","message")="Linked addpatient graph row to existing VistA patient from request identifier"
 . S PATDONE=1
 I 'PATDONE,RDFN<1,$G(ARGS("load"))'="",+$G(ARGS("load"))=0 D
 . D PATSTAT(.RETURN,IEN,ROOT,"skipped","Patient creation skipped because load=0")
 . S PATDONE=1
 I 'PATDONE D PATIENT(.RETURN,IEN,.ICN,ROOT)
 S RDFN=+$G(RETURN("dfn"))
 I RDFN>0 D LNKPAT^C0FWLNK(IEN,RDFN,.ICN,ROOT)
 I RDFN>0 D RPMSPAT(.RETURN,RDFN,ROOT,IEN)
 I ICN'="" S RETURN("icn")=ICN
 I RDFN>0 D
 . I $G(ARGS("load"))="" S ARGS("load")=1
 . I +$G(ARGS("load"))=0 S RETURN("loadStatus")="skipped" Q
 . D LOAD^C0FWDOM(.RETURN,IEN,.ARGS)
 E  D
 . I $G(RETURN("loadStatus"))="" S RETURN("loadStatus")="skipped"
 . S RETURN("load","message")="No DFN resolved for addpatient graph row"
 I $G(ARGS("returngraph"))=1 D TXLOAD^C0FWIDX(.RETURN,IEN,1,LASTRIEN)
 K C0FWBUNDLE
 D ENCODE^XLFJSON("RETURN","RESULT")
 Q 1
 ;
PATIENT(RETURN,IEN,ICN,ROOT) ; File Patient directly through FileMan
 N CITY,DEM,DFN,DIC,DOB,ERR,FDA,MAR,NAME,PENT,PHONE,PTYPE,SEX,SSN,SSNIN,STATE,STIEN,STREET,STREET2,VET,X,Y,ZIP
 S U="^"
 I $G(DT)="" S DT=$$DT^XLFDT
 S PENT=$$PENTRY(ROOT,IEN)
 I PENT<1 D PATSTAT(.RETURN,IEN,ROOT,"error","No Patient resource found in posted Bundle") Q
 S NAME=$$PNAME(ROOT,IEN,PENT)
 I NAME="" D PATSTAT(.RETURN,IEN,ROOT,"error","Patient name is missing family or given") Q
 S SEX=$$SEX($G(@ROOT@(IEN,"json","entry",PENT,"resource","gender")))
 S DOB=$$DOB($G(@ROOT@(IEN,"json","entry",PENT,"resource","birthDate")))
 S SSNIN=$$SSN(ROOT,IEN,PENT)
 S SSN=SSNIN
 I '$$VALIDSSN(SSN) S SSN=$$PSEUDO(IEN),RETURN("patient","ssnMessage")="FHIR SSN was missing or invalid for this VistA; filed local pseudo-SSN"
 I $D(^DPT("SSN",SSN)) D  Q
 . S DFN=+$O(^DPT("SSN",SSN,0))
 . D PATSTAT(.RETURN,IEN,ROOT,"duplicate","Patient SSN already exists in ^DPT; use /updatepatient?dfn="_DFN_" to merge into the existing patient")
 . S RETURN("dfn")=DFN
 S STREET=$G(@ROOT@(IEN,"json","entry",PENT,"resource","address",1,"line",1))
 S STREET2=$G(@ROOT@(IEN,"json","entry",PENT,"resource","address",1,"line",2))
 S CITY=$G(@ROOT@(IEN,"json","entry",PENT,"resource","address",1,"city"))
 S STATE=$G(@ROOT@(IEN,"json","entry",PENT,"resource","address",1,"state"))
 S ZIP=$G(@ROOT@(IEN,"json","entry",PENT,"resource","address",1,"postalCode"))
 S PHONE=$$PHONE(ROOT,IEN,PENT)
 S MAR=$$MARITAL($G(@ROOT@(IEN,"json","entry",PENT,"resource","maritalStatus","coding",1,"code")))
 S PTYPE=$$PTYPE()
 S VET=$$VET(ROOT,IEN,PENT)
 S DEM("SEX")=SEX,DEM("DOB")=DOB,DEM("SSN")=SSN
 S DEM("STREET")=STREET,DEM("STREET2")=STREET2,DEM("CITY")=CITY,DEM("STATE")=STATE,DEM("ZIP")=ZIP
 S DEM("PHONE")=PHONE,DEM("MAR")=MAR,DEM("PTYPE")=PTYPE,DEM("VET")=VET
 K DIC,ERR,FDA,Y
 S DIC="^DPT(",DIC(0)="L",X=NAME
 D FILE^DICN
 S DFN=+Y
 I DFN<1 D PATSTAT(.RETURN,IEN,ROOT,"error","FileMan failed to create Patient shell") Q
 K DIC
 S SEX=DEM("SEX"),DOB=DEM("DOB"),SSN=DEM("SSN")
 S STREET=DEM("STREET"),STREET2=DEM("STREET2"),CITY=DEM("CITY"),STATE=DEM("STATE"),ZIP=DEM("ZIP")
 S PHONE=DEM("PHONE"),MAR=DEM("MAR"),PTYPE=DEM("PTYPE"),VET=DEM("VET")
 I SEX'="" S FDA(2,DFN_",",.02)=SEX
 I DOB>0 S FDA(2,DFN_",",.03)=DOB
 S FDA(2,DFN_",",.09)=SSN
 I STREET'="" S FDA(2,DFN_",",.111)=STREET
 I STREET2'="" S FDA(2,DFN_",",.112)=STREET2
 I CITY'="" S FDA(2,DFN_",",.114)=CITY
 S STIEN=$$STATE(STATE) I STIEN>0 S FDA(2,DFN_",",.115)=STIEN
 I ZIP'="" S FDA(2,DFN_",",.116)=ZIP
 I PHONE'="" S FDA(2,DFN_",",.131)=PHONE
 I MAR>0 S FDA(2,DFN_",",.05)=MAR
 I PTYPE>0 S FDA(2,DFN_",",391)=PTYPE
 I VET'="",'$$RPMSCAP() S FDA(2,DFN_",",1901)=VET
 I $$RPMSCAP() D RPMSDEM(.RETURN,DFN,.FDA,.ERR)
 E  D FILE^DIE("","FDA","ERR")
 I $D(ERR) D  Q
 . D PATSTAT(.RETURN,IEN,ROOT,"error","FileMan failed to file Patient demographics")
 . M RETURN("patient","filemanError")=ERR
 . D FMERR(.RETURN,.ERR,.FDA)
 S RETURN("dfn")=DFN
 S RETURN("patient","engine")="C0FW/FileMan"
 S RETURN("patient","loadStatus")="loaded"
 S RETURN("patient","message")="Patient filed directly by C0FW"
 S RETURN("patient","fields","name")=NAME
 S RETURN("patient","fields","ssn")=SSN
 S RETURN("patient","fields","sex")=SEX
 I DOB>0 S RETURN("patient","fields","dob")=DOB
 S RETURN("patient","raceEthnicityMessage")="Race and ethnicity were not filed; this target Patient DD does not expose the same simple fields used by the ISI template"
 S @ROOT@(IEN,"load","Patient","status","DFN")=DFN
 S @ROOT@(IEN,"load","Patient","status","loadStatus")="loaded"
 S ICN=$$FILEICN(DFN,ROOT,IEN,PENT,SSN,.RETURN)
 Q
 ;
PATSTAT(RETURN,IEN,ROOT,STATUS,MSG) ; Record Patient status without throwing
 S RETURN("loadStatus")=$G(STATUS)
 S RETURN("patient","loadStatus")=$G(STATUS)
 S RETURN("patient","message")=$G(MSG)
 I $G(ROOT)'="",+$G(IEN)>0 D
 . S @ROOT@(IEN,"load","Patient","status","loadStatus")=$G(STATUS)
 . S @ROOT@(IEN,"load","Patient","status","loadMessage")=$G(MSG)
 Q
 ;
FMERR(RETURN,ERR,FDA) ; Flatten FileMan error details for HTTP JSON callers
 N FIELD,I,TEXT
 S I=0
 F  S I=$O(ERR("DIERR",1,"TEXT",I)) Q:+I=0  D
 . S TEXT=$G(ERR("DIERR",1,"TEXT",I))
 . I TEXT'="" S RETURN("patient","filemanErrorText",I)=TEXT
 S FIELD=""
 F  S FIELD=$O(FDA(2,$O(FDA(2,"")),FIELD)) Q:FIELD=""  D
 . S RETURN("patient","filemanFDA",FIELD)=$G(FDA(2,$O(FDA(2,"")),FIELD))
 Q
 ;
RPMSDEM(RETURN,DFN,FDA,ERR) ; File RPMS demographics in safe groups
 N FIELD,KEY,MSG,ONE
 K ERR
 F FIELD=.02,.03,.09,391 D  I $D(ERR) Q
 . Q:'$D(FDA(2,DFN_",",FIELD))
 . K ONE
 . S ONE(2,DFN_",",FIELD)=FDA(2,DFN_",",FIELD)
 . D FILE^DIE("","ONE","ERR")
 I $D(ERR) Q
 F FIELD=.05,.111,.112,.114,.115,.116,.131 D
 . Q:'$D(FDA(2,DFN_",",FIELD))
 . K MSG,ONE
 . S ONE(2,DFN_",",FIELD)=FDA(2,DFN_",",FIELD)
 . D FILE^DIE("","ONE","MSG")
 . I $D(MSG) D
 . . S KEY="field"_FIELD
 . . S RETURN("patient","rpms","filemanWarningField",KEY)=FDA(2,DFN_",",FIELD)
 . . S RETURN("patient","rpms","filemanWarningField",KEY,"reason")="RPMS Patient-file cross-reference returned a warning while filing this secondary demographic field"
 Q
 ;
RPMSPAT(RETURN,DFN,ROOT,IEN) ; Create/repair RPMS IHS PATIENT row when present
 N DET,MSG,STAT,TPL
 S DFN=+$G(DFN)
 S DET=$$RPMSCAP()
 S RETURN("patient","rpms","detected")=DET
 S RETURN("patient","rpms","templateDfn")=""
 I 'DET D  Q
 . D SETRPMS(.RETURN,ROOT,IEN,"not_applicable","RPMS IHS PATIENT file/DD not detected","")
 I DFN<1 D  Q
 . D SETRPMS(.RETURN,ROOT,IEN,"error","No DFN supplied for RPMS IHS PATIENT repair","")
 I '$D(^DPT(DFN,0)) D  Q
 . D SETRPMS(.RETURN,ROOT,IEN,"error","DFN does not exist in ^DPT; RPMS IHS PATIENT row not created","")
 I $D(^AUPNPAT(DFN,0)) D  Q
 . D SETRPMS(.RETURN,ROOT,IEN,"exists","Existing ^AUPNPAT row found; no repair needed","")
 I $$AUPNDD() D AUPNFM(.STAT,.MSG,DFN)
 I $G(STAT)="" D AUPNDIR(.STAT,.MSG,.TPL,DFN)
 D SETRPMS(.RETURN,ROOT,IEN,$G(STAT),$G(MSG),$G(TPL))
 Q
 ;
RPMSCAP() ; $$ - RPMS IHS PATIENT capability present
 Q $S($D(^AUPNPAT(0))&$D(^DD(9000001,.01,0)):1,1:0)
 ;
AUPNDD() ; $$ - FileMan DD for IHS PATIENT .01 is present
 Q $S($D(^DD(9000001,.01,0)):1,1:0)
 ;
AUPNFM(STAT,MSG,DFN) ; Try FileMan create with IEN tied to DFN
 N ERR,FDA,IENS
 S DFN=+$G(DFN)
 K ERR,FDA,IENS
 S FDA(9000001,"+1,",.01)=DFN
 S IENS(1)=DFN
 D UPDATE^DIE("","FDA","IENS","ERR")
 I '$D(ERR),$D(^AUPNPAT(DFN,0)) D  Q
 . S STAT="created_fileman"
 . S MSG="Created ^AUPNPAT row through FileMan"
 S STAT=""
 S MSG="FileMan did not create ^AUPNPAT row; direct fallback attempted"
 Q
 ;
AUPNDIR(STAT,MSG,TPL,DFN) ; Minimal direct fallback for RPMS IHS PATIENT row
 S DFN=+$G(DFN),TPL=""
 I $D(^AUPNPAT(DFN,0)) D  Q
 . S STAT="exists"
 . S MSG="Existing ^AUPNPAT row found during direct repair"
 I $D(^AUPNPAT(3,0)) D
 . S ^AUPNPAT(DFN,0)=^AUPNPAT(3,0)
 . S $P(^AUPNPAT(DFN,0),U,1)=DFN
 . S TPL=3
 . S STAT="created_template"
 . S MSG="Created ^AUPNPAT row from template DFN 3 zero node; .01 rewritten to DFN"
 E  D
 . S ^AUPNPAT(DFN,0)=DFN
 . S STAT="created_direct"
 . S MSG="Created minimal direct ^AUPNPAT zero node with DFN only"
 D AUPN0(DFN)
 Q
 ;
AUPN0(DFN) ; Maintain ^AUPNPAT(0) header after direct create
 N CNT,LAST
 S DFN=+$G(DFN)
 Q:DFN<1
 I $G(^AUPNPAT(0))="" S ^AUPNPAT(0)="IHS PATIENT^9000001IP"
 S LAST=+$P($G(^AUPNPAT(0)),U,3)
 S CNT=+$P($G(^AUPNPAT(0)),U,4)
 I LAST<DFN S $P(^AUPNPAT(0),U,3)=DFN
 S $P(^AUPNPAT(0),U,4)=CNT+1
 Q
 ;
SETRPMS(RETURN,ROOT,IEN,STAT,MSG,TPL) ; Store RPMS patient status in response/graph
 S RETURN("patient","rpms","aupnpatStatus")=$G(STAT)
 S RETURN("patient","rpms","message")=$G(MSG)
 I $G(TPL)'="" S RETURN("patient","rpms","templateDfn")=$G(TPL)
 I $G(ROOT)'="",+$G(IEN)>0 D
 . S @ROOT@(IEN,"load","Patient","status","rpms","detected")=$G(RETURN("patient","rpms","detected"))
 . S @ROOT@(IEN,"load","Patient","status","rpms","aupnpatStatus")=$G(STAT)
 . S @ROOT@(IEN,"load","Patient","status","rpms","message")=$G(MSG)
 . I $G(TPL)'="" S @ROOT@(IEN,"load","Patient","status","rpms","templateDfn")=$G(TPL)
 Q
 ;
PENTRY(ROOT,IEN) ; $$ - first Patient entry RIEN
 N RIEN
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))="Patient" Q
 Q +RIEN
 ;
PNAME(ROOT,IEN,RIEN) ; $$ - VistA NAME from FHIR Patient.name[1]
 N FAM,GIV,NAME
 S FAM=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","name",1,"family"))
 S GIV=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","name",1,"given",1))
 Q:FAM="" ""
 Q:GIV="" ""
 S NAME=$$UP(FAM)_","_$$UP(GIV)
 Q NAME
 ;
UP(X) ; $$ - uppercase using Kernel host support
 N Y
 S X=$G(X)
 X ^%ZOSF("UPPERCASE")
 Q Y
 ;
SEX(X) ; $$ - VistA sex code from FHIR gender
 S X=$G(X)
 Q $S(X="male":"M",X="female":"F",1:"")
 ;
DOB(X) ; $$ - FileMan DOB from FHIR birthDate
 Q $$FHIRTFM^C0FWFUTL($G(X))
 ;
SSN(ROOT,IEN,RIEN) ; $$ - SSN from Patient.identifier
 N IDX,SSN,SYS
 S (IDX,SSN)=""
 F  S IDX=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX)) Q:IDX=""  D  Q:SSN'=""
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX,"system"))
 . I SYS'["us-ssn" Q
 . S SSN=$$DIGITS($G(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX,"value")))
 I SSN?9N Q SSN
 Q ""
 ;
VALIDSSN(SSN) ; $$ - true if VistA Patient file accepts this SSN shape
 S SSN=$G(SSN)
 I SSN'?9N Q 0
 I $E(SSN)=9 Q 0
 Q 1
 ;
DIGITS(X) ; $$ - numeric characters only
 N I,Y
 S Y=""
 F I=1:1:$L($G(X)) I $E(X,I)?1N S Y=Y_$E(X,I)
 Q Y
 ;
PSEUDO(IEN) ; $$ - local pseudo SSN when FHIR has none
 N BASE,SSN
 S BASE=800000000+(+$G(IEN)#100000000)
 F  D  Q:'$D(^DPT("SSN",SSN))
 . S SSN=$E(BASE,1,9)
 . S BASE=BASE+1
 Q SSN
 ;
STATE(X) ; $$ - State file IEN from abbreviation or name
 N Y
 S X=$G(X) Q:X="" 0
 S Y=$$FIND1^DIC(5,,"X",X,"C")
 I Y>0 Q Y
 S Y=$$FIND1^DIC(5,,"X",X,"B")
 Q +Y
 ;
PHONE(ROOT,IEN,RIEN) ; $$ - first phone telecom value
 N IDX,SYS,VAL
 S (IDX,VAL)=""
 F  S IDX=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","telecom",IDX)) Q:IDX=""  D  Q:VAL'=""
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","telecom",IDX,"system"))
 . I SYS'="",SYS'="phone" Q
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","telecom",IDX,"value"))
 Q VAL
 ;
MARITAL(CODE) ; $$ - pointer to MARITAL STATUS file from FHIR code/text
 N NAME,Y
 S CODE=$G(CODE)
 S NAME=$S(CODE="M":"MARRIED",CODE="S":"NEVER MARRIED",CODE="D":"DIVORCED",CODE="W":"WIDOWED",CODE="L":"SEPARATED",CODE="UNK":"UNKNOWN",1:"")
 I NAME="" Q 0
 S Y=$$FIND1^DIC(11,,"X",NAME,"B")
 Q +Y
 ;
PTYPE() ; $$ - default Patient TYPE pointer
 N Y
 S Y=$$FIND1^DIC(391,,"X","NON-VETERAN (OTHER)","B")
 Q +Y
 ;
VET(ROOT,IEN,RIEN) ; $$ - veteran flag from explicit extension if present
 N IDX,URL,VAL
 S IDX=""
 F  S IDX=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",IDX)) Q:IDX=""  D  Q:$G(VAL)'=""
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",IDX,"url"))
 . I URL'["veteran",URL'["Veteran" Q
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",IDX,"valueBoolean"))
 Q $S($G(VAL)="true":"Y",$G(VAL)="false":"N",1:"N")
 ;
FILEICN(DFN,ROOT,IEN,RIEN,SSN,RETURN) ; $$ - optional native ICN filing
 N BASE,CHK,ERR,FDA,FULL,H99101,H99102,H9911
 S BASE=$$ICNBASE(ROOT,IEN,RIEN,SSN)
 I BASE="" Q ""
 I $T(CHECKDG^MPIFSPC)="" D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: MPIFSPC checksum API is not installed"
 S CHK=$$CHECKDG^MPIFSPC(BASE)
 I CHK="" D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: MPIFSPC did not return a checksum"
 S FULL=BASE_"V"_CHK
 K FDA,ERR
 S H99101=$$FLD(2,991.01),H99102=$$FLD(2,991.02),H9911=$$FLD(2,991.1)
 I H99101 S FDA(2,DFN_",",991.01)=BASE
 I H99102 S FDA(2,DFN_",",991.02)=CHK
 I H9911 S FDA(2,DFN_",",991.1)=FULL
 I $D(FDA) D
 . D UPDATE^DIE("","FDA",,"ERR")
 I $D(ERR) D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: FileMan rejected available MPI fields"
 . M RETURN("patient","icnFilemanError")=ERR
 I 'H9911 S RETURN("patient","icn9911Status")="skipped: field 991.1 not present in Patient DD"
 I 'H99101!'H99102 S RETURN("patient","icnMessage")="ICN MPI fields are incomplete on this target; maintained ^DPT ICN indexes"
 S ^DPT("AFICN",FULL,DFN)=""
 S ^DPT("ARFICN",DFN,FULL)=""
 D SETIDXGN^C0FWFUTL(ROOT,IEN,"ICN",FULL)
 S RETURN("icn")=FULL
 S @ROOT@(IEN,"load","Patient","status","ICN")=FULL
 Q FULL
 ;
FLD(FILE,FIELD) ; $$ - FileMan field exists
 Q $S($D(^DD(+$G(FILE),+$G(FIELD),0)):1,1:0)
 ;
ICNBASE(ROOT,IEN,RIEN,SSN) ; $$ - 10 digit ICN base from FHIR identifiers or SSN
 N BASE,IDX,SYS,VAL
 S (BASE,IDX)=""
 F  S IDX=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX)) Q:IDX=""  D  Q:BASE'=""
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX,"system"))
 . I (SYS'["ICN"),(SYS'["2.16.840.1.113883.4.349") Q
 . S VAL=$$DIGITS($G(@ROOT@(IEN,"json","entry",RIEN,"resource","identifier",IDX,"value")))
 . I $L(VAL)'<10 S BASE=$E(VAL,1,10)
 I BASE?10N Q BASE
 I $G(SSN)?9N Q "8"_SSN
 Q ""
 ;
ERR(RESULT,CODE,MESSAGE) ; Encode JSON error
 K OUT
 S OUT("status")="error"
 S OUT("error","code")=$G(CODE)
 S OUT("error","message")=$G(MESSAGE)
 D ENCODE^XLFJSON("OUT","RESULT")
 Q
 ;
