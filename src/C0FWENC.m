C0FWENC ; VEHU/Codex - C0FW encounter writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Encounter as a PCE/PCC visit
 N DFN,ENCDATA,FMDT,ID,KNOWNVISIT,LOC,PKG,RET,SOURCE,STOP,USER,VISIT,ZZERR,ZZERDESC
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 S DFN=$$DFN(ROOT,IEN,RIEN)
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Encounter" D ERR(ROOT,IEN,RIEN,"Resource is not Encounter",.RETURN) Q
 S ID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 D LOGINIT(ROOT,IEN,RIEN,ID)
 S VISIT=$$KNOWN(ROOT,IEN,RIEN,ID)
 S KNOWNVISIT=VISIT
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 I FMDT<1 D ERR(ROOT,IEN,RIEN,"Missing or invalid Encounter period.start/end",.RETURN) Q
 S LOC=$$LOC(ROOT,IEN,RIEN)
 I LOC<1 D ERR(ROOT,IEN,RIEN,"Unable to resolve hospital location",.RETURN) Q
 S USER=$$USER()
 D LEGACYVARS(ROOT,IEN,RIEN,FMDT,LOC,USER,DFN)
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 S SOURCE="C0FW WRITEBACK"
 K ENCDATA,ZZERR,ZZERDESC
 D BUILD(.ENCDATA,ROOT,IEN,RIEN,DFN,FMDT,LOC,USER,+$G(KNOWNVISIT))
 I +$G(KNOWNVISIT)>0,'$D(ENCDATA("HEALTH FACTOR")),'$D(ENCDATA("DX/PL")) D  Q
 . D LOG(ROOT,IEN,RIEN,"Encounter already has visitIen "_KNOWNVISIT_"; filing Encounter.note only")
 . D LOADED(ROOT,IEN,RIEN,KNOWNVISIT,"Encounter already linked to visit",.RETURN)
 I +$G(KNOWNVISIT)>0 S VISIT=KNOWNVISIT
 E  K VISIT
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 D LOG(ROOT,IEN,RIEN,"Calling DATA2PCE^PXAI to add/update encounter")
 S RET=$$DATA2PCE^PXAI("ENCDATA",PKG,SOURCE,.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 D LOG(ROOT,IEN,RIEN,"Return from DATA2PCE was: "_$G(RET)_"^"_$G(VISIT))
 D LEGACYRET(ROOT,IEN,RIEN,$G(RET),$G(VISIT),.ENCDATA,.ZZERR,.ZZERDESC)
 I +$G(RET)'=1,+$G(RET)'=-5 D  Q:$G(STOP)
 . I +$G(VISIT)>0,$$POVONLY(.ZZERR,.ZZERDESC) S RET=-5 Q
 . N MSG S MSG=$$ERRMSG($G(RET),.ZZERR,.ZZERDESC)
 . D ERR(ROOT,IEN,RIEN,MSG,.RETURN) S STOP=1
 I +$G(VISIT)<1 D ERR(ROOT,IEN,RIEN,"DATA2PCE did not return a visit IEN",.RETURN) Q
 D LOADED(ROOT,IEN,RIEN,+VISIT,$S(+$G(RET)=-5:"Encounter filed through DATA2PCE with warnings",1:"Encounter filed through DATA2PCE"),.RETURN)
 D POSTFILE(ROOT,IEN,RIEN,+VISIT)
 I +$G(RET)=-5 S @ROOT@(IEN,"load","Encounter",RIEN,"warning")=$$WARNMSG(.ZZERR,.ZZERDESC)
 Q
 ;
BUILD(ENCDATA,ROOT,IEN,RIEN,DFN,FMDT,LOC,USER,VISIT) ; Build unified encounter DATA2PCE payload
 S ENCDATA("ENCOUNTER",1,"PATIENT")=DFN
 S ENCDATA("ENCOUNTER",1,"ENCOUNTER TYPE")="P"
 S ENCDATA("ENCOUNTER",1,"ENC D/T")=FMDT
 S ENCDATA("ENCOUNTER",1,"HOS LOC")=LOC
 S ENCDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT(FMDT)
 S ENCDATA("ENCOUNTER",1,"EC")=0
 S ENCDATA("PROVIDER",1,"NAME")=USER
 S ENCDATA("PROVIDER",1,"PRIMARY")=1
 D ADDPOV(.ENCDATA,ROOT,IEN,RIEN,FMDT,USER)
 D ADDHF(.ENCDATA,ROOT,IEN,RIEN,FMDT,+$G(VISIT))
 Q
 ;
ADDHF(ENCDATA,ROOT,IEN,RIEN,FMDT,VISIT) ; Add VistA Health Factor Encounter extensions
 N CNT,EI,HF,HFIEN,MAG,NAME,NOTE,SEV,URL
 S (CNT,EI)=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  D
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))
 . Q:URL'=$$HFURL()
 . S NAME=$$EXTVAL(ROOT,IEN,RIEN,EI,"name")
 . S MAG=$$EXTVAL(ROOT,IEN,RIEN,EI,"magnitude")
 . S SEV=$$EXTVAL(ROOT,IEN,RIEN,EI,"severity")
 . S NOTE=$$EXTVAL(ROOT,IEN,RIEN,EI,"comment")
 . D HFPARM(ROOT,IEN,RIEN,EI,NAME,NOTE,MAG,SEV)
 . I NAME="" D HFSTAT(ROOT,IEN,RIEN,EI,"skipped","Health Factor extension missing name") Q
 . S HFIEN=+$O(^AUTTHF("B",NAME,0))
 . I HFIEN<1 D HFSTAT(ROOT,IEN,RIEN,EI,"skipped","Health Factor not found in ^AUTTHF: "_NAME) Q
 . I +$G(VISIT)>0,$$HASHF(VISIT,HFIEN) D HFSTAT(ROOT,IEN,RIEN,EI,"skipped","Health Factor already filed on visit: "_NAME) Q
 . S CNT=CNT+1,HF=$O(ENCDATA("HEALTH FACTOR",""),-1)+1
 . S ENCDATA("HEALTH FACTOR",HF,"HEALTH FACTOR")=HFIEN
 . S ENCDATA("HEALTH FACTOR",HF,"EVENT D/T")=FMDT
 . I MAG'="" D
 . . I +$P($G(^AUTTHF(HFIEN,220)),"^",4)>0 S ENCDATA("HEALTH FACTOR",HF,"MAGNITUDE")=MAG Q
 . . D HFMAG(ROOT,IEN,RIEN,EI,"skipped","Health Factor magnitude skipped; Health Factor has no UCUM measurement definition")
 . I $$SEV(SEV)'="" S ENCDATA("HEALTH FACTOR",HF,"LEVEL/SEVERITY")=$$SEV(SEV)
 . I NOTE'="" S ENCDATA("HEALTH FACTOR",HF,"COMMENT")=NOTE
 . D HFSTAT(ROOT,IEN,RIEN,EI,"queued","Health Factor queued: "_NAME)
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor","queued")=CNT
 Q
 ;
ADDPOV(ENCDATA,ROOT,IEN,RIEN,FMDT,USER) ; Add Encounter POV extension or reasonCode
 N CODE,CODESYS,DIAG,NARR,PI,PRI
 S CODE=$$POVEXT(ROOT,IEN,RIEN,"code")
 S CODESYS=$$POVEXT(ROOT,IEN,RIEN,"system")
 S NARR=$$POVEXT(ROOT,IEN,RIEN,"display")
 I NARR="" S NARR=$$POVEXT(ROOT,IEN,RIEN,"text")
 S PRI=$$POVEXT(ROOT,IEN,RIEN,"primary")
 I CODE="" D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"coding",1,"code"))
 . S CODESYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"coding",1,"system"))
 . S NARR=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"text"))
 . I NARR="" S NARR=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"coding",1,"display"))
 I CODE="" Q
 S DIAG=$$ICDIEN(CODE,CODESYS,FMDT)
 I DIAG<1 D POVSTAT(ROOT,IEN,RIEN,"skipped","POV code is not an ICD-9/ICD-10 code resolvable by C0FW: "_CODE_" "_CODESYS) Q
 S PI=$O(ENCDATA("DX/PL",""),-1)+1
 S ENCDATA("DX/PL",PI,"DIAGNOSIS")=DIAG
 S ENCDATA("DX/PL",PI,"NARRATIVE")=$S(NARR'="":NARR,1:$P($$ICDDX^ICDEX(DIAG),"^",4))
 S ENCDATA("DX/PL",PI,"SERVICE CATEGORY")=$$SERCAT(FMDT)
 S ENCDATA("DX/PL",PI,"PRIMARY")=$S($$BOOL(PRI):1,1:0)
 S ENCDATA("DX/PL",PI,"ENC PROVIDER")=USER
 D POVSTAT(ROOT,IEN,RIEN,"queued","POV queued: "_CODE)
 Q
 ;
FMDT(ROOT,IEN,RIEN) ; $$ - Encounter start/end as FileMan date/time
 N DT
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","start"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","end"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","meta","lastUpdated"))
 Q $$FHIRTFM^C0FWFUTL(DT)
 ;
LOC(ROOT,IEN,RIEN) ; $$ - hospital location
 N LOC,REF
 S LOC=+$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension","location"))
 I LOC>0 Q LOC
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","location",1,"location","reference"))
 I REF["/" S LOC=+$P(REF,"/",2) I LOC>0,$D(^SC(LOC,0)) Q LOC
 S LOC=$O(^SC("B","GENERAL MEDICINE",0))
 I LOC>0 Q LOC
 S LOC=$O(^SC(0))
 Q +LOC
 ;
DFN(ROOT,IEN,RIEN) ; $$ - patient DFN for this Encounter, preferring transaction subject
 N REF,DFN
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","reference"))
 I REF["Patient/" S DFN=+$P(REF,"Patient/",2) I DFN>0,$D(^DPT(DFN,0)) Q DFN
 S DFN=+$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","identifier","value"))
 I DFN>0,$D(^DPT(DFN,0)) Q DFN
 Q +$O(@ROOT@("SPO",IEN,"DFN",""))
 ;
USER() ; $$ - provider-capable filing user
 N USER
 S USER=$$DUZ^C0FWCTX()
 I USER>0,$D(^XUSEC("PROVIDER",USER)) Q USER
 S USER=+$O(^XUSEC("PROVIDER",0))
 Q $S(USER>0:USER,1:$$DUZ^C0FWCTX())
 ;
SERCAT(FMDT) ; $$ - PCE service category
 Q $S((+$G(FMDT)\1)<$$DT^XLFDT:"E",1:"A")
 ;
KNOWN(ROOT,IEN,RIEN,ID) ; $$ - known visit ien from graph or Encounter id
 N ERIEN,VISIT
 S VISIT=+$G(@ROOT@(IEN,"load","Encounter",RIEN,"visitIen"))
 I VISIT>0,$D(^AUPNVSIT(VISIT,0)) Q VISIT
 S ID=$G(ID)
 I ID?1"E".N S VISIT=+$E(ID,2,99) I $D(^AUPNVSIT(VISIT,0)) Q VISIT
 I +ID>0,$D(^AUPNVSIT(+ID,0)) Q +ID
 I ID'="" D  I VISIT>0 Q VISIT
 . S ERIEN=+$O(@ROOT@(IEN,"POS","visitIen",ID,""))
 . I ERIEN>0 S VISIT=+$G(@ROOT@(IEN,"load","Encounter",ERIEN,"visitIen"))
 Q $S(VISIT>0:VISIT,1:0)
 ;
VISITREF(ROOT,IEN,REF) ; $$ - visit ien for a FHIR Encounter reference
 N ID,RIEN,VISIT
 S REF=$G(REF)
 I REF="" Q 0
 I REF["urn:uuid:" S ID=$P(REF,"urn:uuid:",2)
 E  I REF["/" S ID=$P(REF,"/",2)
 E  S ID=REF
 S ID=$P(ID,";",1)
 I ID?1"E".N S VISIT=+$E(ID,2,99) I $D(^AUPNVSIT(VISIT,0)) Q VISIT
 I +ID>0,$D(^AUPNVSIT(+ID,0)) Q +ID
 S RIEN=+$O(@ROOT@(IEN,"POS","visitIen",ID,""))
 I RIEN>0 S VISIT=+$G(@ROOT@(IEN,"load","Encounter",RIEN,"visitIen")) I VISIT>0 Q VISIT
 Q 0
 ;
EXTVAL(ROOT,IEN,RIEN,EI,NAME) ; $$ - value from named child extension
 N NI,VAL
 S NI=0
 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"extension",NI)) Q:+NI=0  D  Q:$D(VAL)
 . Q:$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"extension",NI,"url"))'=NAME
 . S VAL=$$VALNODE(ROOT,IEN,RIEN,EI,NI)
 Q $G(VAL)
 ;
VALNODE(ROOT,IEN,RIEN,EI,NI) ; $$ - first primitive value[x] on child extension
 N KEY,VAL
 S KEY=""
 F  S KEY=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"extension",NI,KEY)) Q:KEY=""  D  Q:$D(VAL)
 . Q:KEY="url"
 . I $E(KEY,1,5)="value" S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"extension",NI,KEY))
 Q $G(VAL)
 ;
POVEXT(ROOT,IEN,RIEN,NAME) ; $$ - value from VistA POV Encounter extension
 N EI,URL,VAL
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  D  Q:$D(VAL)
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))
 . Q:URL'=$$POVURL()
 . S VAL=$$EXTVAL(ROOT,IEN,RIEN,EI,NAME)
 Q $G(VAL)
 ;
HFURL() ; $$ - canonical Health Factor extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-health-factor"
 ;
POVURL() ; $$ - canonical POV extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-pov"
 ;
ICDIEN(CODE,SYS,FMDT) ; $$ - ICD diagnosis ien for Encounter POV
 N CS,RET
 S CODE=$G(CODE),SYS=$G(SYS)
 I CODE="" Q 0
 S CS=$$ICDCS(SYS,FMDT)
 I CS<1 Q 0
 S RET=$$ICDDX^ICDEX(CODE,CS)
 I +RET<1,CS=30,CODE'?1.E1".",$L(CODE)=3 S RET=$$ICDDX^ICDEX(CODE_".",CS)
 Q $S(+RET>0:+RET,1:0)
 ;
ICDCS(SYS,FMDT) ; $$ - ICDEX coding system id
 S SYS=$$UP($G(SYS))
 I SYS["SNOMED" Q 0
 I SYS["SCT" Q 0
 I SYS["ICD-10" Q 30
 I SYS["ICD10" Q 30
 I SYS["ICD-9" Q 1
 I SYS["ICD9" Q 1
 Q 0
 ;
BOOL(X) ; $$ - true for FHIR-ish boolean values
 S X=$$UP($G(X))
 Q $S(X=1:1,X="TRUE":1,X="YES":1,1:0)
 ;
SEV(X) ; $$ - map FHIR magnitude to V Health Factor severity code
 S X=$$UP($G(X))
 I X="" Q ""
 I X="M"!(X="MINIMAL") Q "M"
 I X="MO"!(X="MODERATE") Q "MO"
 I X="H"!(X="HEAVY")!(X="SEVERE")!(X="HEAVY/SEVERE") Q "H"
 I +X<2 Q "M"
 I +X<3 Q "MO"
 Q "H"
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
LOGINIT(ROOT,IEN,RIEN,ID) ; Seed legacy operational load log
 N CODE,CODESYS,END,HL7,HL7END,REASON,REASONSYS,START
 D LOG(ROOT,IEN,RIEN,"ID is: "_$G(ID))
 S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","type",1,"coding",1,"code"))
 I CODE="" S CODE="308335008"
 S CODESYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","type",1,"coding",1,"system"))
 I CODESYS="" S CODESYS="http://snomed.info/sct"
 S REASON=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"coding",1,"code"))
 S REASONSYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"coding",1,"system"))
 S START=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","start"))
 S END=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","end"))
 S HL7=$$FHIRTHL7^C0FWFUTL(START),HL7END=$$FHIRTHL7^C0FWFUTL(END)
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","id")=$G(ID)
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","code")=CODE
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","codeSystem")=CODESYS
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","reasonCode")=REASON
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","reasonCodeSys")=REASONSYS
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","effectiveDateTime")=START
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","endDateTime")=END
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","hl7DateTime")=HL7
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","hl7endDateTime")=HL7END
 D LOG(ROOT,IEN,RIEN,"code is: "_CODE)
 D LOG(ROOT,IEN,RIEN,"code system is: "_CODESYS)
 D LOG(ROOT,IEN,RIEN,"reasonCode is: "_REASON)
 D LOG(ROOT,IEN,RIEN,"reasonCode system is: "_REASONSYS)
 D LOG(ROOT,IEN,RIEN,"effectiveDateTime is: "_START)
 D LOG(ROOT,IEN,RIEN,"hl7 dateTime is: "_HL7)
 D LOG(ROOT,IEN,RIEN,"endDateTime is: "_END)
 D LOG(ROOT,IEN,RIEN,"hl7 endDateTime is: "_HL7END)
 Q
 ;
LEGACYVARS(ROOT,IEN,RIEN,FMDT,LOC,USER,DFN) ; Add resolved filing context to legacy log
 N CLINIC,DHPPAT,ENCPROV,HL7,HL7END,REASON,DXICDCS
 S CLINIC=$P($G(^SC(+$G(LOC),0)),"^")
 S DHPPAT=$$DFN2ICN^C0FWFUTL(+$G(DFN))
 S ENCPROV=$P($G(^VA(200,+$G(USER),"PS")),"^",6)
 I ENCPROV="" S ENCPROV=$P($G(^VA(200,+$G(USER),0)),"^")
 S HL7=$G(@ROOT@(IEN,"load","encounters",RIEN,"vars","hl7DateTime"))
 S HL7END=$G(@ROOT@(IEN,"load","encounters",RIEN,"vars","hl7endDateTime"))
 S REASON=$G(@ROOT@(IEN,"load","encounters",RIEN,"vars","reasonCode"))
 S DXICDCS=$$ICDCS($G(@ROOT@(IEN,"load","encounters",RIEN,"vars","reasonCodeSys")),FMDT)
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","fmDateTime")=FMDT
 S @ROOT@(IEN,"load","encounters",RIEN,"vars","dxIcdCs")=DXICDCS
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","DHPPAT")=DHPPAT
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","SCTCPT")=$G(@ROOT@(IEN,"load","encounters",RIEN,"vars","code"))
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","SCTDX")=REASON
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","DXICDCS")=DXICDCS
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","STARTDT")=HL7
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","ENDDT")=HL7END
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","ENCPROV")=ENCPROV
 S @ROOT@(IEN,"load","encounters",RIEN,"parms","CLINIC")=CLINIC
 D LOG(ROOT,IEN,RIEN,"fileman dateTime is: "_FMDT)
 D LOG(ROOT,IEN,RIEN,"Provider for outpatient is: "_ENCPROV)
 D LOG(ROOT,IEN,RIEN,"Location for outpatient is: "_CLINIC)
 Q
 ;
LEGACYRET(ROOT,IEN,RIEN,RET,VISIT,ENCDATA,ZZERR,ZZERDESC) ; Mirror DATA2PCE return for old log readers
 S @ROOT@(IEN,"load","encounters",RIEN,"status","return")=$G(RET)_"^"_$G(VISIT)
 I $D(ENCDATA) M @ROOT@(IEN,"load","encounters",RIEN,"status","return","ENCDATA")=ENCDATA
 I $D(ZZERR) M @ROOT@(IEN,"load","encounters",RIEN,"status","return","ZZERR")=ZZERR
 I $D(ZZERDESC) M @ROOT@(IEN,"load","encounters",RIEN,"status","return","ZZERDESC")=ZZERDESC
 Q
 ;
LOG(ROOT,IEN,RIEN,TXT) ; Append legacy operational log line
 S @ROOT@(IEN,"load","encounters",RIEN,"log",$O(@ROOT@(IEN,"load","encounters",RIEN,"log",""),-1)+1)=$G(TXT)
 Q
 ;
LOADED(ROOT,IEN,RIEN,VISIT,MSG,RETURN) ; Record loaded visit status
 N ID
 S ID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Encounter","Encounter","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Encounter",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","encounters",RIEN,"visitIen")=+VISIT
 I ID'="" D SETIDXGN^C0FWFUTL($NA(@ROOT@(IEN)),RIEN,"visitIen",ID)
 S RETURN("domains","Encounter","visitIen")=+VISIT
 Q
 ;
POSTFILE(ROOT,IEN,RIEN,VISIT) ; Confirm queued Encounter-native PCE rows after filing
 N EI,HFIEN,NAME,POV
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI)) Q:+EI=0  D
 . Q:$G(@ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"status"))'="queued"
 . S NAME=$$EXTVAL(ROOT,IEN,RIEN,EI,"name")
 . S HFIEN=+$O(^AUTTHF("B",NAME,0))
 . I HFIEN>0,$$HASHF(VISIT,HFIEN) D HFSTAT(ROOT,IEN,RIEN,EI,"filed","Health Factor filed: "_NAME) Q
 . D HFSTAT(ROOT,IEN,RIEN,EI,"unknown","Health Factor was queued but not found after DATA2PCE: "_NAME)
 S POV=$G(@ROOT@(IEN,"load","Encounter",RIEN,"pov","status"))
 I POV="queued" D
 . I $$HASPOV(VISIT) D POVSTAT(ROOT,IEN,RIEN,"filed",$G(@ROOT@(IEN,"load","Encounter",RIEN,"pov","message"))) Q
 . D POVSTAT(ROOT,IEN,RIEN,"unknown","POV was queued but not found after DATA2PCE")
 Q
 ;
HASHF(VISIT,HFIEN) ; $$ - true if visit has V Health Factor row
 N IND
 S IND=0
 F  S IND=$O(^AUPNVHF("AD",+$G(VISIT),IND)) Q:+IND=0  I +$P($G(^AUPNVHF(IND,0)),"^")=+$G(HFIEN) Q
 Q $S(+IND>0:1,1:0)
 ;
HASPOV(VISIT) ; $$ - true if visit has any V POV row
 Q $S(+$O(^AUPNVPOV("AD",+$G(VISIT),0))>0:1,1:0)
 ;
POVONLY(ZZERR,ZZERDESC) ; $$ - true if DATA2PCE only complains about optional POV absence
 N MSG
 S MSG=$$UP($$ARRTXT("ZZERDESC")_" "_$$ARRTXT("ZZERR"))
 I MSG["NO V POV RECORD" Q 1
 Q 0
 ;
HFSTAT(ROOT,IEN,RIEN,EI,STATUS,MSG) ; Record Health Factor extension detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"status")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"message")=$G(MSG)
 S @ROOT@(IEN,"load","encounters",RIEN,"healthFactor",EI,"status")=$G(STATUS)
 S @ROOT@(IEN,"load","encounters",RIEN,"healthFactor",EI,"message")=$G(MSG)
 Q
 ;
HFMAG(ROOT,IEN,RIEN,EI,STATUS,MSG) ; Record Health Factor magnitude detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"magnitudeStatus")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"magnitudeMessage")=$G(MSG)
 S @ROOT@(IEN,"load","encounters",RIEN,"healthFactor",EI,"magnitudeStatus")=$G(STATUS)
 S @ROOT@(IEN,"load","encounters",RIEN,"healthFactor",EI,"magnitudeMessage")=$G(MSG)
 Q
 ;
HFPARM(ROOT,IEN,RIEN,EI,NAME,NOTE,MAG,SEV) ; Mirror requested HF into legacy parms log
 I $G(NAME)'="" S @ROOT@(IEN,"load","encounters",RIEN,"parms","HEALTH FACTOR",EI,"name")=$G(NAME)
 I $G(NOTE)'="" S @ROOT@(IEN,"load","encounters",RIEN,"parms","HEALTH FACTOR",EI,"comment")=$G(NOTE)
 I $G(MAG)'="" S @ROOT@(IEN,"load","encounters",RIEN,"parms","HEALTH FACTOR",EI,"magnitude")=$G(MAG)
 I $G(SEV)'="" S @ROOT@(IEN,"load","encounters",RIEN,"parms","HEALTH FACTOR",EI,"severity")=$G(SEV)
 Q
 ;
POVSTAT(ROOT,IEN,RIEN,STATUS,MSG) ; Record POV extension detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"pov","status")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"pov","message")=$G(MSG)
 S @ROOT@(IEN,"load","encounters",RIEN,"pov","status")=$G(STATUS)
 S @ROOT@(IEN,"load","encounters",RIEN,"pov","message")=$G(MSG)
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Encounter","Encounter",$G(MSG),.RETURN)
 Q
 ;
ERRMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE error text
 N MSG,N
 S MSG="DATA2PCE encounter filing failed: "_$G(RET)
 S N=0 F  S N=$O(ZZERDESC(N)) Q:+N=0  S MSG=MSG_" "_$G(ZZERDESC(N))
 I '$D(ZZERDESC),$D(ZZERR) S MSG=MSG_" "_$$ERRTXT("ZZERR")
 Q MSG
 ;
WARNMSG(ZZERR,ZZERDESC) ; $$ - DATA2PCE warning text
 N MSG,N
 S MSG="DATA2PCE returned warnings (-5)"
 S N=0 F  S N=$O(ZZERDESC(N)) Q:+N=0  S MSG=MSG_" "_$G(ZZERDESC(N))
 I '$D(ZZERDESC),$D(ZZERR) S MSG=MSG_" "_$$ERRTXT("ZZERR")
 Q MSG
 ;
ERRTXT(ROOT) ; $$ - compact first error node from a local array name
 N MSG,NODE
 S MSG="",NODE=$Q(@ROOT)
 I NODE'="" S MSG=NODE_"="_$G(@NODE)
 Q MSG
 ;
ARRTXT(ROOT) ; $$ - compact all first-level values from a local array name
 N MSG,N
 S MSG="",N=0
 F  S N=$O(@ROOT@(N)) Q:+N=0  S MSG=MSG_" "_$G(@ROOT@(N))
 I MSG="" S MSG=$$ERRTXT(ROOT)
 Q MSG
