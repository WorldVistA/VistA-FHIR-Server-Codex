C0FWCON ; VEHU/Codex - C0FW condition writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Condition on an existing visit
 N CODE,CODESYS,DFN,FMDT,ICD,MSG,PKG,PROBDATA,RET,USER,VISIT,ZZERR,ZZERDESC
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Condition" D ERR(ROOT,IEN,RIEN,"Resource is not Condition",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D ERR(ROOT,IEN,RIEN,"Condition has no resolved encounter visit pointer",.RETURN) Q
 S CODE=$$CODE(ROOT,IEN,RIEN),CODESYS=$$CODESYS(ROOT,IEN,RIEN)
 S ICD=$$ICDIEN(CODE,CODESYS,$$FMDT(ROOT,IEN,RIEN))
 I ICD<1 D  Q
 . S MSG="Condition code is not an ICD-9/ICD-10 code resolvable by C0FW: "_CODE_" "_CODESYS
 . D ERR(ROOT,IEN,RIEN,MSG,.RETURN)
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
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
 S PROBDATA("ENCOUNTER",1,"EC")=0
 S PROBDATA("DX/PL",1,"PL ADD")=1
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
 D LOADED(ROOT,IEN,RIEN,VISIT,ICD,$S(+$G(RET)'=1:"Condition filed through DATA2PCE with warnings",1:"Condition filed through DATA2PCE"),.RETURN)
 I +$G(RET)'=1 S @ROOT@(IEN,"load","Condition",RIEN,"warning")=$$WARNMSG(RET,.ZZERR,.ZZERDESC)
 Q
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from Condition encounter reference
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 Q +VISIT
 ;
CODE(ROOT,IEN,RIEN) ; $$ - first coding code
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 ;
CODESYS(ROOT,IEN,RIEN) ; $$ - first coding system
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"system"))
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
ACTIVE(ROOT,IEN,RIEN) ; $$ - VistA problem active flag
 N ABATE,STAT
 S ABATE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","abatementDateTime"))
 I ABATE'="" Q "I"
 S STAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","clinicalStatus","coding",1,"code"))
 I STAT="" S STAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","clinicalStatus"))
 S STAT=$$UP(STAT)
 Q $S(STAT["INACTIVE":"I",STAT["RESOLVED":"I",1:"A")
 ;
LOADED(ROOT,IEN,RIEN,VISIT,ICD,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Condition",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","Condition",RIEN,"diagnosisIen")=+ICD
 S RETURN("domains","Condition","visitIen")=+VISIT
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition",$G(MSG),.RETURN)
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
