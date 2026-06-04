C0FWENC ; VEHU/Codex - C0FW encounter writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Encounter as a PCE/PCC visit
 N DFN,ENCDATA,FMDT,GIEN,GRIEN,ID,KNOWNVISIT,LOC,PKG,RET,SENTDATA,SOURCE,STOP,USER,VISIT,ZZERR,ZZERDESC
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
 I +$G(KNOWNVISIT)>0,'$D(ENCDATA("HEALTH FACTOR")),'$D(ENCDATA("DX/PL")),'$D(ENCDATA("STD CODES")) D  Q
 . D LOG(ROOT,IEN,RIEN,"Encounter already has visitIen "_KNOWNVISIT_"; filing Encounter.note only")
 . D LOADED(ROOT,IEN,RIEN,KNOWNVISIT,"Encounter already linked to visit",.RETURN)
 I +$G(KNOWNVISIT)>0 S VISIT=KNOWNVISIT
 E  K VISIT
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 K SENTDATA M SENTDATA=ENCDATA
 D LOG(ROOT,IEN,RIEN,"Calling DATA2PCE^PXAI to add/update encounter")
 D LOGARR(ROOT,IEN,RIEN,"ENCDATA",.SENTDATA)
 S GIEN=IEN,GRIEN=RIEN
 S RET=$$DATA2PCE^PXAI("ENCDATA",PKG,SOURCE,.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 S IEN=GIEN,RIEN=GRIEN
 D LOG(ROOT,IEN,RIEN,"Return from DATA2PCE was: "_$G(RET)_"^"_$G(VISIT))
 D LOGPCE(ROOT,IEN,RIEN,.ZZERR,.ZZERDESC)
 D LEGACYRET(ROOT,IEN,RIEN,$G(RET),$G(VISIT),.SENTDATA,.ZZERR,.ZZERDESC)
 I +$G(VISIT)<1 S VISIT=$$MATCHVIS(ROOT,IEN,RIEN) I +$G(VISIT)>0 D LOG(ROOT,IEN,RIEN,"Matched visit after DATA2PCE: "_VISIT)
 I +$G(RET)'=1,+$G(RET)'=-5 D  Q:$G(STOP)
 . I +$G(VISIT)>0,$$POVONLY(.ZZERR,.ZZERDESC) S RET=-5 Q
 . I +$G(VISIT)>0 D LOG(ROOT,IEN,RIEN,"DATA2PCE add-on filing returned error after visit was established; continuing with visit "_VISIT) S RET=-5 Q
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
 S ENCDATA("PROVIDER",1,"NAME")=USER
 S ENCDATA("PROVIDER",1,"PRIMARY")=1
 D ADDPOV(.ENCDATA,ROOT,IEN,RIEN,FMDT,USER)
 D ADDHF(.ENCDATA,ROOT,IEN,RIEN,FMDT,+$G(VISIT))
 Q
 ;
BASE(BASE,ENCDATA) ; Copy only ENCOUNTER/PROVIDER nodes for visit establishment
 K BASE
 M BASE("ENCOUNTER")=ENCDATA("ENCOUNTER")
 M BASE("PROVIDER")=ENCDATA("PROVIDER")
 Q
 ;
HASCLIN(ENCDATA) ; $$ - true if the encounter payload has visit-linked add-ons
 I $D(ENCDATA("HEALTH FACTOR")) Q 1
 I $D(ENCDATA("DX/PL")) Q 1
 I $D(ENCDATA("STD CODES")) Q 1
 Q 0
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
 . S HFIEN=$$HFIEN(ROOT,IEN,RIEN,EI,NAME)
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
ADDPOV(ENCDATA,ROOT,IEN,RIEN,FMDT,USER) ; Add Encounter POV extension, reasonCode, or STD CODES
 N CODE,CODESYS,HASPOV,NARR,PRI,RCCNT,RCI
 S HASPOV=0
 S CODE=$$POVEXT(ROOT,IEN,RIEN,"code")
 S CODESYS=$$POVEXT(ROOT,IEN,RIEN,"system")
 S NARR=$$POVEXT(ROOT,IEN,RIEN,"display")
 I NARR="" S NARR=$$POVEXT(ROOT,IEN,RIEN,"text")
 S PRI=$$POVEXT(ROOT,IEN,RIEN,"primary")
 I CODE'="" D ADDCODE(.ENCDATA,ROOT,IEN,RIEN,CODE,CODESYS,NARR,$$BOOL(PRI),FMDT,USER,.HASPOV) Q
 S RCCNT=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",""),-1)
 S RCI=0 F  S RCI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI)) Q:+RCI=0  D ADDRC(.ENCDATA,ROOT,IEN,RIEN,RCI,RCCNT,FMDT,USER,.HASPOV)
 Q
 ;
ADDRC(ENCDATA,ROOT,IEN,RIEN,RCI,RCCNT,FMDT,USER,HASPOV) ; Add one Encounter.reasonCode entry
 N CI,CODE,CODESYS,DISP,ICDCODE,ICDDISP,ICDSYS,NARR,PRI,SCTCODE,SCTDISP,SCTICD
 S PRI=$$RCPRIM(ROOT,IEN,RIEN,RCI)
 I 'PRI,+$G(RCCNT)=1 S PRI=1
 S NARR=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"text"))
 S (ICDCODE,ICDDISP,ICDSYS,SCTCODE,SCTDISP)=""
 S CI=0 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"coding",CI)) Q:+CI=0  D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"coding",CI,"code"))
 . S CODESYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"coding",CI,"system"))
 . S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"coding",CI,"display"))
 . I '$$SCTSYS(CODESYS),$$ICDCS(CODESYS,FMDT)>0,ICDCODE="" S ICDCODE=CODE,ICDSYS=CODESYS,ICDDISP=DISP
 . Q:'$$SCTSYS(CODESYS)
 . I SCTCODE="" S SCTCODE=CODE,SCTDISP=DISP
 . D ADDCODE(.ENCDATA,ROOT,IEN,RIEN,CODE,CODESYS,"",0,FMDT,USER,.HASPOV)
 I $$BOOL(PRI),'$G(HASPOV) D
 . I ICDCODE'="" D ADDCODE(.ENCDATA,ROOT,IEN,RIEN,ICDCODE,ICDSYS,$S(NARR'="":NARR,ICDDISP'="":ICDDISP,1:ICDCODE),1,FMDT,USER,.HASPOV) Q
 . I SCTCODE'="" D  Q:$G(HASPOV)
 . . S SCTICD=$$SCTICD10(SCTCODE)
 . . I SCTICD>0 D ADDDX(.ENCDATA,ROOT,IEN,RIEN,SCTICD,SCTCODE,$S(NARR'="":NARR,SCTDISP'="":SCTDISP,1:SCTCODE),FMDT,USER,.HASPOV) D POVSTAT(ROOT,IEN,RIEN,"queued","POV queued from SNOMED-to-ICD-10 Lexicon mapping: "_SCTCODE)
 . D POVSTAT(ROOT,IEN,RIEN,"skipped","Primary reasonCode has no ICD-9/ICD-10 coding; true V POV requires ICD mapping.")
 Q
 ;
ADDCODE(ENCDATA,ROOT,IEN,RIEN,CODE,CODESYS,NARR,PRI,FMDT,USER,HASPOV) ; Add one coding from a POV source
 N DIAG
 I $G(CODE)="" Q
 S DIAG=$$ICDIEN(CODE,CODESYS,FMDT)
 I $$SCTSYS(CODESYS) D  Q
 . D ADDSTD(.ENCDATA,ROOT,IEN,RIEN,CODE,NARR,FMDT,USER)
 . I $$BOOL(PRI),'$G(HASPOV) D POVSTAT(ROOT,IEN,RIEN,"skipped","SNOMED-only POV candidate filed as standard code; true V POV requires ICD mapping: "_CODE)
 I DIAG>0,$$BOOL(PRI),'$G(HASPOV) D ADDDX(.ENCDATA,ROOT,IEN,RIEN,DIAG,CODE,NARR,FMDT,USER,.HASPOV) Q
 I DIAG>0 Q
 I DIAG<1 D POVSTAT(ROOT,IEN,RIEN,"skipped","POV code is not an ICD-9/ICD-10 code or SNOMED CT standard code resolvable by C0FW: "_CODE_" "_CODESYS) Q
 Q
 ;
ADDDX(ENCDATA,ROOT,IEN,RIEN,DIAG,CODE,NARR,FMDT,USER,HASPOV) ; Queue one ICD-mapped V POV
 N PI
 S PI=$O(ENCDATA("DX/PL",""),-1)+1
 S ENCDATA("DX/PL",PI,"DIAGNOSIS")=DIAG
 S ENCDATA("DX/PL",PI,"NARRATIVE")=$S(NARR'="":NARR,1:$P($$ICDDX^ICDEX(DIAG),"^",4))
 S ENCDATA("DX/PL",PI,"SERVICE CATEGORY")=$$SERCAT(FMDT)
 S ENCDATA("DX/PL",PI,"PRIMARY")=1
 S ENCDATA("DX/PL",PI,"ENC PROVIDER")=USER
 S HASPOV=1
 D POVSTAT(ROOT,IEN,RIEN,"queued","POV queued: "_CODE)
 Q
 ;
ADDSTD(ENCDATA,ROOT,IEN,RIEN,CODE,NARR,FMDT,USER) ; Queue SNOMED-only standard code for DATA2PCE
 N SI
 S SI=$O(ENCDATA("STD CODES",""),-1)+1
 S ENCDATA("STD CODES",SI,"CODE")=CODE
 S ENCDATA("STD CODES",SI,"CODING SYSTEM")="SCT"
 S ENCDATA("STD CODES",SI,"EVENT D/T")=FMDT
 S ENCDATA("STD CODES",SI,"ENC PROVIDER")=USER
 D STDSTAT(ROOT,IEN,RIEN,SI,"queued","SNOMED standard code queued: "_CODE,CODE)
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
DFN(ROOT,IEN,RIEN) ; $$ - patient DFN for this Encounter
 N ID,REF,DFN
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","reference"))
 I REF["Patient/" D  I DFN>0 Q DFN
 . S ID=$P(REF,"Patient/",2),ID=$P(ID,"/",1),ID=$P(ID,";",1)
 . I ID?1.N S DFN=+ID I $D(^DPT(DFN,0)) Q
 . S DFN=0
 S DFN=+$G(@ROOT@(IEN,"json","entry",RIEN,"resource","subject","identifier","value"))
 I DFN>0,$D(^DPT(DFN,0)) Q DFN
 Q +$O(@ROOT@("SPO",IEN,"DFN",""))
 ;
USER() ; $$ - provider-capable filing user
 N USER
 I $G(DT)="" S DT=$$DT^XLFDT
 S USER=$$DUZ^C0FWCTX()
 I USER>0,$D(^XUSEC("PROVIDER",USER)),$$ACTIVEPC(USER) Q USER
 S USER=+$O(^XUSEC("PROVIDER",0))
 F  Q:USER<1  Q:$$ACTIVEPC(USER)  S USER=+$O(^XUSEC("PROVIDER",USER))
 I USER>0 Q USER
 S USER=+$O(^VA(200,0))
 F  Q:USER<1  Q:$$ACTIVEPC(USER)  S USER=+$O(^VA(200,USER))
 Q $S(USER>0:USER,1:$$DUZ^C0FWCTX())
 ;
ACTIVEPC(USER) ; $$ - true if user has active person class for PCE
 N PC
 I $G(U)="" S U="^"
 S USER=+$G(USER) Q:USER<1 0
 I $T(GET^XUA4A72)="" Q 1
 S PC=$$GET^XUA4A72(USER,$S($G(DT)>0:DT,1:$$DT^XLFDT))
 Q $S(+PC>0:1,1:0)
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
 I ID?1.N,$D(^AUPNVSIT(+ID,0)) Q +ID
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
 I ID?1.N,$D(^AUPNVSIT(+ID,0)) Q +ID
 S RIEN=+$O(@ROOT@(IEN,"POS","visitIen",ID,""))
 I RIEN>0 S VISIT=+$G(@ROOT@(IEN,"load","Encounter",RIEN,"visitIen")) I VISIT>0 Q VISIT
 Q 0
 ;
MATCHVIS(ROOT,IEN,RIEN) ; $$ - best matching visit for this Encounter row
 N DFN,FMDT,INV,LOC,VISIT
 S DFN=$$DFN(ROOT,IEN,RIEN) Q:DFN<1 0
 S FMDT=$$FMDT(ROOT,IEN,RIEN) Q:FMDT<1 0
 S LOC=$$LOC(ROOT,IEN,RIEN)
 S INV=9999999-(FMDT\1)
 S VISIT=0
 F  S VISIT=$O(^AUPNVSIT("AA",DFN,INV,VISIT)) Q:+VISIT=0  D  Q:+VISIT>0
 . I LOC>0,+$P($G(^AUPNVSIT(VISIT,0)),"^",22)'=LOC S VISIT=0 Q
 . I ($P($G(^AUPNVSIT(VISIT,0)),"^")\1)'=(FMDT\1) S VISIT=0 Q
 Q +VISIT
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
HFIEN(ROOT,IEN,RIEN,EI,NAME) ; $$ - Health Factor ien from native or SYN resolution
 N HFIEN,SYN
 S HFIEN=+$O(^AUTTHF("B",$G(NAME),0))
 I HFIEN>0 Q HFIEN
 S SYN=+$G(@ROOT@(IEN,"load","HealthFactor",RIEN,"healthFactor",EI,"ien"))
 I SYN>0 Q SYN
 Q 0
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
RCPRIM(ROOT,IEN,RIEN,RCI) ; $$ - reasonCode is marked as the V POV candidate
 N EI,URL,VAL
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI)) Q:+EI=0  D  Q:$D(VAL)
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI,"url"))
 . Q:URL'=$$RCPRURL()
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI,"valueBoolean"))
 Q $$BOOL($G(VAL))
 ;
RCSUP(ROOT,IEN,RIEN,RCI) ; $$ - reasonCode support text extension value
 N EI,URL,VAL
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI)) Q:+EI=0  D  Q:$D(VAL)
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI,"url"))
 . Q:URL'=$$RCSUPURL()
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",RCI,"extension",EI,"valueString"))
 Q $G(VAL)
 ;
HFURL() ; $$ - canonical Health Factor extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-health-factor"
 ;
POVURL() ; $$ - canonical POV extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-pov"
 ;
RCPRURL() ; $$ - canonical reasonCode primary POV extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-pov-primary"
 ;
RCSUPURL() ; $$ - canonical reasonCode support extension URL
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-reason-support"
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
SCTICD10(SCT) ; $$ - SNOMED CT code to ICD-10 diagnosis ien via Lexicon map 5217693
 N ICDTX,LEX,MAPVUID,RET,Y
 S SCT=$G(SCT) I SCT="" Q 0
 S MAPVUID=5217693
 K LEX S Y=$$GETASSN^LEXTRAN1(SCT,MAPVUID)
 S ICDTX="" S ICDTX=$O(LEX(1,ICDTX))
 I ICDTX="" Q 0
 S RET=$$ICDDX^ICDEX(ICDTX,30)
 I +RET<1,ICDTX'?1.E1".",$L(ICDTX)=3 S RET=$$ICDDX^ICDEX(ICDTX_".",30)
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
SCTSYS(SYS) ; $$ - true if coding system is SNOMED CT
 S SYS=$$UP($G(SYS))
 Q $S(SYS["SNOMED":1,SYS["SCT":1,1:0)
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
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","id")=$G(ID)
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","code")=CODE
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","codeSystem")=CODESYS
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","reasonCode")=REASON
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","reasonCodeSys")=REASONSYS
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","effectiveDateTime")=START
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","endDateTime")=END
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","hl7DateTime")=HL7
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","hl7endDateTime")=HL7END
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
 S HL7=$G(@ROOT@(IEN,"load","Encounter",RIEN,"vars","hl7DateTime"))
 S HL7END=$G(@ROOT@(IEN,"load","Encounter",RIEN,"vars","hl7endDateTime"))
 S REASON=$G(@ROOT@(IEN,"load","Encounter",RIEN,"vars","reasonCode"))
 S DXICDCS=$$ICDCS($G(@ROOT@(IEN,"load","Encounter",RIEN,"vars","reasonCodeSys")),FMDT)
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","fmDateTime")=FMDT
 S @ROOT@(IEN,"load","Encounter",RIEN,"vars","dxIcdCs")=DXICDCS
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","DHPPAT")=DHPPAT
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","SCTCPT")=$G(@ROOT@(IEN,"load","Encounter",RIEN,"vars","code"))
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","SCTDX")=REASON
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","DXICDCS")=DXICDCS
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","STARTDT")=HL7
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","ENDDT")=HL7END
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","ENCPROV")=ENCPROV
 S @ROOT@(IEN,"load","Encounter",RIEN,"parms","CLINIC")=CLINIC
 D LOG(ROOT,IEN,RIEN,"fileman dateTime is: "_FMDT)
 D LOG(ROOT,IEN,RIEN,"Provider for outpatient is: "_ENCPROV)
 D LOG(ROOT,IEN,RIEN,"Location for outpatient is: "_CLINIC)
 Q
 ;
LEGACYRET(ROOT,IEN,RIEN,RET,VISIT,ENCDATA,ZZERR,ZZERDESC) ; Mirror DATA2PCE return for old log readers
 S @ROOT@(IEN,"load","Encounter",RIEN,"status","return")=$G(RET)_"^"_$G(VISIT)
 I $D(ENCDATA) M @ROOT@(IEN,"load","Encounter",RIEN,"status","return","ENCDATA")=ENCDATA
 I $D(ZZERR) M @ROOT@(IEN,"load","Encounter",RIEN,"status","return","ZZERR")=ZZERR
 I $D(ZZERDESC) M @ROOT@(IEN,"load","Encounter",RIEN,"status","return","ZZERDESC")=ZZERDESC
 Q
 ;
LEGACYBASE(ROOT,IEN,RIEN,RET,VISIT,BASE,ZZERR,ZZERDESC) ; Mirror visit-establish DATA2PCE payload
 S @ROOT@(IEN,"load","Encounter",RIEN,"status","baseReturn")=$G(RET)_"^"_$G(VISIT)
 I $D(BASE) M @ROOT@(IEN,"load","Encounter",RIEN,"status","baseReturn","BASE")=BASE
 I $D(ZZERR) M @ROOT@(IEN,"load","Encounter",RIEN,"status","baseReturn","ZZERR")=ZZERR
 I $D(ZZERDESC) M @ROOT@(IEN,"load","Encounter",RIEN,"status","baseReturn","ZZERDESC")=ZZERDESC
 Q
 ;
LOG(ROOT,IEN,RIEN,TXT) ; Append legacy operational log line
 S @ROOT@(IEN,"load","Encounter",RIEN,"log",$O(@ROOT@(IEN,"load","Encounter",RIEN,"log",""),-1)+1)=$G(TXT)
 Q
 ;
LOGARR(ROOT,IEN,RIEN,LABEL,ARY,INTRO) ; Append a local array snapshot to legacy log
 N BASE,NODE,SEEN
 S LABEL=$G(LABEL,"ARRAY")
 S INTRO=$G(INTRO,"DATA2PCE input")
 D LOG(ROOT,IEN,RIEN,INTRO_" "_LABEL_":")
 S BASE=$NA(ARY),NODE=BASE,SEEN=0
 F  S NODE=$Q(@NODE) Q:NODE=""  Q:$E(NODE,1,$L(BASE))'=BASE  D
 . S SEEN=1
 . D LOG(ROOT,IEN,RIEN,LABEL_$E(NODE,$L(BASE)+1,999)_"="_$G(@NODE))
 I 'SEEN D LOG(ROOT,IEN,RIEN,LABEL_"=<empty>")
 Q
 ;
LOGPCE(ROOT,IEN,RIEN,ZZERR,ZZERDESC) ; Append DATA2PCE errors/warnings to legacy log
 I $D(ZZERR) D LOGARR(ROOT,IEN,RIEN,"ZZERR",.ZZERR,"DATA2PCE output")
 I $D(ZZERDESC) D LOGARR(ROOT,IEN,RIEN,"ZZERDESC",.ZZERDESC,"DATA2PCE output")
 Q
 ;
LOADED(ROOT,IEN,RIEN,VISIT,MSG,RETURN) ; Record loaded visit status
 N ID
 S ID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Encounter","Encounter","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Encounter",RIEN,"visitIen")=+VISIT
 I ID'="" D SETIDXGN^C0FWFUTL($NA(@ROOT@(IEN)),RIEN,"visitIen",ID)
 S RETURN("domains","Encounter","visitIen")=+VISIT
 Q
 ;
POSTFILE(ROOT,IEN,RIEN,VISIT) ; Confirm queued Encounter-native PCE rows after filing
 N EI,HFIEN,NAME,POV,SI
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI)) Q:+EI=0  D
 . Q:$G(@ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"status"))'="queued"
 . S NAME=$$EXTVAL(ROOT,IEN,RIEN,EI,"name")
 . S HFIEN=+$O(^AUTTHF("B",NAME,0))
 . I HFIEN>0,$$HASHF(VISIT,HFIEN) D HFSTAT(ROOT,IEN,RIEN,EI,"filed","Health Factor filed: "_NAME) Q
 . D HFSTAT(ROOT,IEN,RIEN,EI,"unknown","Health Factor was queued but not found after DATA2PCE: "_NAME)
 S SI=0
 F  S SI=$O(@ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI)) Q:+SI=0  D
 . Q:$G(@ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"status"))'="queued"
 . D ENSSTD(ROOT,IEN,RIEN,VISIT,SI)
 S POV=$G(@ROOT@(IEN,"load","Encounter",RIEN,"pov","status"))
 I POV="queued" D
 . I $$HASPOV(VISIT) D POVSTAT(ROOT,IEN,RIEN,"filed",$G(@ROOT@(IEN,"load","Encounter",RIEN,"pov","message"))) Q
 . D POVSTAT(ROOT,IEN,RIEN,"unknown","POV was queued but not found after DATA2PCE")
 Q
 ;
ENSALL(ROOT,IEN,RIEN,VISIT) ; Verify all queued V STANDARD CODES rows are present
 N SI
 S SI=0
 F  S SI=$O(@ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI)) Q:+SI=0  D ENSSTD(ROOT,IEN,RIEN,VISIT,SI)
 Q
 ;
ENSSTD(ROOT,IEN,RIEN,VISIT,SI) ; Verify V STANDARD CODES row exists after DATA2PCE
 N CODE,SCIEN
 S VISIT=+$G(VISIT),CODE=$G(@ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"code"))
 Q:VISIT<1  Q:CODE=""
 S SCIEN=$$STDROW(VISIT,CODE)
 I SCIEN>0 D STDSTAT(ROOT,IEN,RIEN,SI,"filed","SNOMED standard code filed by DATA2PCE: "_CODE,CODE) Q
 D STDSTAT(ROOT,IEN,RIEN,SI,"unknown","SNOMED standard code was queued for DATA2PCE but not found after filing: "_CODE,CODE)
 Q
 ;
STDROW(VISIT,CODE) ; $$ - V STANDARD CODES IEN for visit/code
 N IEN
 S IEN=0
 F  S IEN=$O(^AUPNVSC("AD",+$G(VISIT),IEN)) Q:IEN<1  I $P($G(^AUPNVSC(IEN,0)),U)=$G(CODE) Q
 Q +IEN
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
 Q
 ;
HFMAG(ROOT,IEN,RIEN,EI,STATUS,MSG) ; Record Health Factor magnitude detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"magnitudeStatus")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"healthFactor",EI,"magnitudeMessage")=$G(MSG)
 Q
 ;
HFPARM(ROOT,IEN,RIEN,EI,NAME,NOTE,MAG,SEV) ; Mirror requested HF into legacy parms log
 I $G(NAME)'="" S @ROOT@(IEN,"load","Encounter",RIEN,"parms","HEALTH FACTOR",EI,"name")=$G(NAME)
 I $G(NOTE)'="" S @ROOT@(IEN,"load","Encounter",RIEN,"parms","HEALTH FACTOR",EI,"comment")=$G(NOTE)
 I $G(MAG)'="" S @ROOT@(IEN,"load","Encounter",RIEN,"parms","HEALTH FACTOR",EI,"magnitude")=$G(MAG)
 I $G(SEV)'="" S @ROOT@(IEN,"load","Encounter",RIEN,"parms","HEALTH FACTOR",EI,"severity")=$G(SEV)
 Q
 ;
POVSTAT(ROOT,IEN,RIEN,STATUS,MSG) ; Record POV extension detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"pov","status")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"pov","message")=$G(MSG)
 Q
 ;
STDSTAT(ROOT,IEN,RIEN,SI,STATUS,MSG,CODE) ; Record Encounter standard code detail
 S @ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"status")=$G(STATUS)
 S @ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"message")=$G(MSG)
 I $G(CODE)'="" S @ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"code")=$G(CODE)
 S @ROOT@(IEN,"load","Encounter",RIEN,"standardCode",SI,"system")="SCT"
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
