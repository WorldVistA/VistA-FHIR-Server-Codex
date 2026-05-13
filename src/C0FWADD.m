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
 N CITY,DFN,DIC,DOB,ERR,FDA,MAR,NAME,PENT,PHONE,PTYPE,SEX,SSN,SSNIN,STATE,STIEN,STREET,STREET2,VET,X,Y,ZIP
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
 K DIC,ERR,FDA,Y
 S DIC="^DPT(",DIC(0)="L",X=NAME
 D FILE^DICN
 S DFN=+Y
 I DFN<1 D PATSTAT(.RETURN,IEN,ROOT,"error","FileMan failed to create Patient shell") Q
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
 I VET'="" S FDA(2,DFN_",",1901)=VET
 D FILE^DIE("","FDA","ERR")
 I $D(ERR) D  Q
 . D PATSTAT(.RETURN,IEN,ROOT,"error","FileMan failed to file Patient demographics")
 . M RETURN("patient","filemanError")=ERR
 S RETURN("dfn")=DFN
 S RETURN("patient","engine")="C0FW/FileMan"
 S RETURN("patient","loadStatus")="loaded"
 S RETURN("patient","message")="Patient filed directly by C0FW"
 S RETURN("patient","fields","name")=NAME
 S RETURN("patient","fields","ssn")=SSN
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
 N BASE,CHK,ERR,FDA,FULL
 S BASE=$$ICNBASE(ROOT,IEN,RIEN,SSN)
 I BASE="" Q ""
 I $T(CHECKDG^MPIFSPC)="" D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: MPIFSPC checksum API is not installed"
 S CHK=$$CHECKDG^MPIFSPC(BASE)
 I CHK="" D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: MPIFSPC did not return a checksum"
 S FULL=BASE_"V"_CHK
 K FDA,ERR
 S FDA(2,DFN_",",991.01)=BASE
 S FDA(2,DFN_",",991.02)=CHK
 S FDA(2,DFN_",",991.1)=FULL
 D UPDATE^DIE("","FDA",,"ERR")
 I $D(ERR) D  Q ""
 . S RETURN("patient","icnMessage")="ICN not filed: FileMan rejected MPI fields"
 . M RETURN("patient","icnFilemanError")=ERR
 S ^DPT("AFICN",FULL,DFN)=""
 S ^DPT("ARFICN",DFN,FULL)=""
 D SETIDXGN^C0FWFUTL(ROOT,IEN,"ICN",FULL)
 S RETURN("icn")=FULL
 S @ROOT@(IEN,"load","Patient","status","ICN")=FULL
 Q FULL
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
