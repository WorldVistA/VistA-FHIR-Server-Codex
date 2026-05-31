C0FWCON ; VEHU/Codex - C0FW condition writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Condition on an existing visit
 N ADDPL,DFN,FMDT,ICD,MSG,PKG,PROB,PROBDATA,RET,SCT,SCTDES,USER,VISIT,ZZERR,ZZERDESC
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Condition" D ERR(ROOT,IEN,RIEN,"Resource is not Condition",.RETURN) Q
 I $$CAND(ROOT,IEN,RIEN) D SKIP(ROOT,IEN,RIEN,"Candidate reminder Condition is note evidence only; no V POV/problem filing attempted.",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D ERR(ROOT,IEN,RIEN,"Condition has no resolved encounter visit pointer",.RETURN) Q
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 S ICD=$$RESICD(ROOT,IEN,RIEN,FMDT)
 I ICD<1 D  Q
 . S MSG="Condition has no ICD-10/ICD-9 diagnosis resolvable from codings (ICD or SNOMED CT to ICD-10 map)."
 . D ERR(ROOT,IEN,RIEN,MSG,.RETURN)
 S ADDPL=$$ADDPL(ROOT,IEN,RIEN)
 I FMDT<1 S FMDT=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 I FMDT<1 D ERR(ROOT,IEN,RIEN,"Missing Condition onset and visit date",.RETURN) Q
 S USER=$$USER^C0FWENC()
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 K PROBDATA,ZZERR,ZZERDESC
 S PROBDATA("ENCOUNTER",1,"PATIENT")=DFN
 S PROBDATA("ENCOUNTER",1,"ENC D/T")=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 S PROBDATA("ENCOUNTER",1,"HOS LOC")=+$P($G(^AUPNVSIT(VISIT,0)),"^",22)
 S PROBDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT(VISIT,FMDT)
 S PROBDATA("DX/PL",1,"PL ADD")=ADDPL
 S PROBDATA("DX/PL",1,"PL ONSET DATE")=FMDT\1
 S PROBDATA("DX/PL",1,"DIAGNOSIS")=ICD
 S PROBDATA("DX/PL",1,"NARRATIVE")=$$NARR(ICD,ROOT,IEN,RIEN)
 S PROBDATA("DX/PL",1,"SERVICE CATEGORY")=$$SERCAT(VISIT,FMDT)
 S PROBDATA("DX/PL",1,"PRIMARY")=$$PRIMARY(VISIT,ICD)
 S PROBDATA("DX/PL",1,"ENC PROVIDER")=USER
 S PROBDATA("DX/PL",1,"PL ACTIVE")=$$ACTIVE(ROOT,IEN,RIEN)
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 S RET=$$DATA2PCE^PXAI("PROBDATA",PKG,"C0FW WRITEBACK",.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 I +$G(RET)'=1,+$G(RET)'=-5,'$$HASPOV(VISIT,ICD) D ERR(ROOT,IEN,RIEN,$$ERRMSG(RET,.ZZERR,.ZZERDESC),.RETURN) Q
 S SCT=$$SCT(ROOT,IEN,RIEN),SCTDES=$$SCTDES(ROOT,IEN,RIEN)
 S PROB=$$PROB(DFN,ICD,FMDT)
 I PROB>0,SCT'="" D SETSCT(PROB,SCT,SCTDES,ROOT,IEN,RIEN,.RETURN)
 D LOADED(ROOT,IEN,RIEN,VISIT,ICD,ADDPL,$S(+$G(RET)'=1:"Condition filed through DATA2PCE with warnings",1:"Condition filed through DATA2PCE"),.RETURN)
 I +$G(RET)'=1 S @ROOT@(IEN,"load","Condition",RIEN,"warning")=$$WARNMSG(RET,.ZZERR,.ZZERDESC)
 Q
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from Condition encounter reference
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 I VISIT<1 S VISIT=$$TXVISIT(ROOT,IEN,REF)
 Q +VISIT
 ;
TXVISIT(ROOT,IEN,REF) ; $$ - visit ien from same-transaction Encounter fullUrl
 N ERIEN,ID,VISIT
 S REF=$G(REF)
 I REF="" Q 0
 S ERIEN=0
 F  S ERIEN=$O(@ROOT@(IEN,"json","entry",ERIEN)) Q:+ERIEN=0  D  Q:+$G(VISIT)>0
 . Q:$G(@ROOT@(IEN,"json","entry",ERIEN,"resource","resourceType"))'="Encounter"
 . S ID=$G(@ROOT@(IEN,"json","entry",ERIEN,"fullUrl"))
 . I ID="",REF["urn:uuid:" S ID="urn:uuid:"_$G(@ROOT@(IEN,"json","entry",ERIEN,"resource","id"))
 . I ID'=REF Q
 . S VISIT=+$G(@ROOT@(IEN,"load","Encounter",ERIEN,"visitIen"))
 Q +$G(VISIT)
 ;
CODE(ROOT,IEN,RIEN) ; $$ - first coding code
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 ;
CODESYS(ROOT,IEN,RIEN) ; $$ - first coding system
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"system"))
 ;
RESICD(ROOT,IEN,RIEN,FMDT) ; $$ - ICD diagnosis ien from Condition.code codings (ICD first, then SNOMED)
 N CODE,CS,ICD,NI,SYS
 S ICD=0
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  Q:ICD>0  D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system"))
 . Q:CODE=""
 . S CS=$$ICDCS(SYS,FMDT)
 . I CS>0 S ICD=$$ICDIEN(CODE,SYS,FMDT) Q:ICD>0
 . I $$SCTSYS(SYS) S ICD=$$SCTICD10(CODE) Q:ICD>0
 Q +ICD
 ;
SCTSYS(SYS) ; $$ - true if coding system is SNOMED CT
 S SYS=$$UP($G(SYS))
 Q $S(SYS["SNOMED":1,SYS["SCT":1,1:0)
 ;
SCT(ROOT,IEN,RIEN) ; $$ - first SNOMED CT code on Condition.code
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system"))
 . Q:'$$SCTSYS(SYS)
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 Q $G(CODE)
 ;
SCTDES(ROOT,IEN,RIEN) ; $$ - SNOMED designation code extension on SNOMED coding
 N EI,NI,SYS,URL,VAL
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(VAL)'=""
 . S SYS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system"))
 . Q:'$$SCTSYS(SYS)
 . S EI=0 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"extension",EI)) Q:+EI=0  D  Q:$G(VAL)'=""
 . . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"extension",EI,"url"))
 . . Q:URL'=$$SCTDESURL()
 . . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"extension",EI,"valueString"))
 Q $G(VAL)
 ;
SCTDESURL() ; $$ - coding extension URL for SNOMED designation code
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-snomed-designation-code"
 ;
SCTICD10(SCT) ; $$ - SNOMED CT code to ICD-10 diagnosis ien via Lexicon map 5217693
 N ICDTX,LEX,MAPVUID,RET,Y
 I $G(U)="" S U="^"
 S SCT=$G(SCT) I SCT="" Q 0
 S MAPVUID=5217693
 K LEX S Y=$$GETASSN^LEXTRAN1(SCT,MAPVUID)
 S ICDTX="" S ICDTX=$O(LEX(1,ICDTX))
 I ICDTX="" Q 0
 S RET=$$ICDDX^ICDEX(ICDTX,30)
 I +RET<1,ICDTX'?1.E1".",$L(ICDTX)=3 S RET=$$ICDDX^ICDEX(ICDTX_".",30)
 Q $S(+RET>0:+RET,1:0)
 ;
ADDPL(ROOT,IEN,RIEN) ; $$ - 1=file to problem list (PL ADD), 0=visit POV only
 N EI,FND,VB,VS
 S (EI,FND)=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  D
 . Q:$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))'=$$PLURL()
 . S FND=1
 . S VB=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"valueBoolean"))
 . S VS=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"valueString"))
 . I VS'="" S VB=VS
 Q $S(FND:$$BOOLPL(VB),1:0)
 ;
CAND(ROOT,IEN,RIEN) ; $$ - true if reminder generated a non-fileable candidate Condition
 N EI,URL,VAL
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  D  Q:$D(VAL)
 . S URL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))
 . Q:URL'="urn:reminders-on-fhir:writeback-status"
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"valueString"))
 Q $S($$UP($G(VAL))="CANDIDATE":1,1:0)
 ;
BOOLPL(V) ; $$ - truthy for PL ADD
 I $G(V)=0 Q 0
 I $G(V)=1 Q 1
 S V=$$UP($G(V))
 I V="" Q 0
 I V="0"!(V="FALSE")!(V="N")!(V="NO") Q 0
 Q 1
 ;
PLURL() ; $$ - Condition extension URL for Add to Problem List
 Q "http://vistaplex.org/fhir/StructureDefinition/vista-add-to-problem-list"
 ;
FMDT(ROOT,IEN,RIEN) ; $$ - onset as FileMan date/time
 N DT
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","onsetDateTime"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","recordedDate"))
 Q $$FHIRTFM^C0FWFUTL(DT)
 ;
ICDIEN(CODE,SYS,FMDT) ; $$ - ICD diagnosis ien for ICD-coded Condition
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
NARR(ICD,ROOT,IEN,RIEN) ; $$ - problem narrative
 N TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I TXT'="" Q TXT
 Q $P($$ICDDX^ICDEX(ICD),"^",4)
 ;
SERCAT(VISIT,FMDT) ; $$ - service category
 N CAT
 S CAT=$P($G(^AUPNVSIT(+$G(VISIT),0)),"^",7)
 I CAT'="" Q CAT
 Q $S((+$G(FMDT)\1)<$$DT^XLFDT:"E",1:"A")
 ;
PRIMARY(VISIT,ICD) ; $$ - primary diagnosis flag
 N DIAG,FOUND,IND
 S FOUND=0,IND=0
 F  S IND=$O(^AUPNVPOV("AD",+$G(VISIT),IND)) Q:+IND=0  D
 . I $P($G(^AUPNVPOV(IND,0)),"^",12)="P" S FOUND=1
 . I +$P($G(^AUPNVPOV(IND,0)),"^")=+$G(ICD) S FOUND=2
 Q $S(FOUND=0:1,FOUND=1:0,1:0)
 ;
HASPOV(VISIT,ICD) ; $$ - true if visit has a V POV row for diagnosis
 N IND
 S IND=0
 F  S IND=$O(^AUPNVPOV("AD",+$G(VISIT),IND)) Q:+IND=0  I +$P($G(^AUPNVPOV(IND,0)),"^")=+$G(ICD) Q
 Q $S(+IND>0:1,1:0)
 ;
PROB(DFN,ICD,FMDT) ; $$ - most recent active problem for patient/diagnosis
 N BEST,IFN,LM,ODT
 S (BEST,ODT)=0,IFN=0
 F  S IFN=$O(^AUPNPROB("AC",+$G(DFN),IFN)) Q:+IFN=0  D
 . Q:+$P($G(^AUPNPROB(IFN,0)),"^")'=+$G(ICD)
 . Q:$P($G(^AUPNPROB(IFN,1)),"^",2)="H"
 . S LM=+$P($G(^AUPNPROB(IFN,0)),"^",3)
 . I LM<1 S LM=+$P($G(^AUPNPROB(IFN,0)),"^",8)
 . I +$G(FMDT)>0,LM>0,LM>(FMDT+1) Q
 . I LM'<ODT S ODT=LM,BEST=IFN
 Q +BEST
 ;
SETSCT(PROB,SCT,SCTDES,ROOT,IEN,RIEN,RETURN) ; Store SNOMED fields on problem entry
 N DA,DIE,DR,ERR
 S PROB=+$G(PROB),SCT=$G(SCT),SCTDES=$G(SCTDES)
 I PROB<1!(SCT="") Q
 I '$D(DUZ) S DUZ=$$USER^C0FWENC()
 I $G(DUZ(0))="" S DUZ(0)="@"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 S DIE="^AUPNPROB(",DA=PROB,DR="80001////"_SCT
 I SCTDES'="" S DR=DR_";80002////"_SCTDES
 D ^DIE
 S @ROOT@(IEN,"load","Condition",RIEN,"problemIen")=PROB
 S @ROOT@(IEN,"load","Condition",RIEN,"snomedCode")=SCT
 I SCTDES'="" S @ROOT@(IEN,"load","Condition",RIEN,"snomedDesignationCode")=SCTDES
 S RETURN("domains","Condition","problemIen")=PROB
 S RETURN("domains","Condition","snomedCode")=SCT
 I SCTDES'="" S RETURN("domains","Condition","snomedDesignationCode")=SCTDES
 Q
 ;
ACTIVE(ROOT,IEN,RIEN) ; $$ - VistA problem active flag
 N ABATE,STAT
 S ABATE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","abatementDateTime"))
 I ABATE'="" Q "I"
 S STAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","clinicalStatus","coding",1,"code"))
 I STAT="" S STAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","clinicalStatus"))
 S STAT=$$UP(STAT)
 Q $S(STAT["INACTIVE":"I",STAT["RESOLVED":"I",1:"A")
 ;
LOADED(ROOT,IEN,RIEN,VISIT,ICD,ADDPL,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Condition",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","Condition",RIEN,"diagnosisIen")=+ICD
 S @ROOT@(IEN,"load","Condition",RIEN,"addToProblemList")=+$G(ADDPL)
 S RETURN("domains","Condition","visitIen")=+VISIT
 S RETURN("domains","Condition","addToProblemList")=+$G(ADDPL)
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition",$G(MSG),.RETURN)
 Q
 ;
SKIP(ROOT,IEN,RIEN,MSG,RETURN) ; Record skipped status
 D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition",$G(MSG),.RETURN)
 Q
 ;
ERRMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE error text
 N MSG,N
 S MSG="DATA2PCE condition filing failed: "_$G(RET)
 S N=0 F  S N=$O(ZZERDESC(N)) Q:+N=0  S MSG=MSG_" "_$G(ZZERDESC(N))
 I '$D(ZZERDESC),$D(ZZERR) S MSG=MSG_" "_$$ERRTXT("ZZERR")
 Q MSG
 ;
WARNMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE warning text
 N MSG,N
 S MSG="DATA2PCE returned non-clean status ("_$G(RET)_") after filing"
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
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
