C0FWCP ; VEHU/Codex - C0FW CarePlan writeback as SYN CP health factors ;Sep 09, 2026
 ;;0.2;C0FHIR PROJECT;;Sep 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR CarePlan as SYN CP V Health Factors
 N ADD,CAT,CMT,CNT,DFN,EDT,ENCDATA,ERR,FMDT,HFCAP,HFCAT,LOC,PKG
 N RET,SDT,STAT,USER,VISIT,X,ZZERR,ZZERDESC
 I $G(U)="" S U="^"
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="CarePlan" D ERR(ROOT,IEN,RIEN,"Resource is not CarePlan",.RETURN) Q
 S X="HFCP^SYNFHF"
 I $T(@X)="" D SKIP(ROOT,IEN,RIEN,0,0,"SYNFHF is not installed; cannot file CarePlan health factors",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D SKIP(ROOT,IEN,RIEN,0,0,"CarePlan has no resolved encounter visit; skipped.",.RETURN) Q
 S FMDT=$$FMDT(ROOT,IEN,RIEN,VISIT)
 I FMDT<1 D ERR(ROOT,IEN,RIEN,"Missing CarePlan period and visit date",.RETURN) Q
 S SDT=$$START(ROOT,IEN,RIEN,FMDT)
 S EDT=$$END(ROOT,IEN,RIEN)
 S STAT=$$STAT(ROOT,IEN,RIEN)
 S CAT=$$CAT(ROOT,IEN,RIEN)
 I $P(CAT,U,2)="" S $P(CAT,U,2)="Care Plan"
 S HFCAT=$$HFCPCAT^SYNFHF($P(CAT,U),$P(CAT,U,2))
 I +HFCAT<1 D ERR(ROOT,IEN,RIEN,"SYNFHF could not create CarePlan category HF: "_HFCAT,.RETURN) Q
 S HFCAP=$$HFCP^SYNFHF($P(CAT,U),$P(CAT,U,2),+HFCAT)
 I +HFCAP<1 D ERR(ROOT,IEN,RIEN,"SYNFHF could not create CarePlan HF: "_HFCAP,.RETURN) Q
 I $$HASHF^C0FWENC(VISIT,+HFCAP) D SKIP(ROOT,IEN,RIEN,VISIT,+HFCAP,"CarePlan already filed as SYN CP health factor on visit",.RETURN) Q
 S USER=$$USER^C0FWENC()
 S LOC=+$P($G(^AUPNVSIT(VISIT,0)),U,22)
 S CMT=$$CMT(SDT,EDT,STAT)
 K ENCDATA
 D BASE(.ENCDATA,DFN,VISIT,FMDT,USER)
 D QONE(.ENCDATA,+HFCAP,VISIT,FMDT,CMT)
 S ADD=$$ADDR(ROOT,IEN,RIEN)
 I $P(ADD,U)'=""!($P(ADD,U,2)'="") D QADDR(.ENCDATA,+HFCAT,VISIT,ADD,FMDT,$$CMT(SDT,EDT,""))
 D QACT(.ENCDATA,ROOT,IEN,RIEN,VISIT,+HFCAT,FMDT,SDT,EDT)
 D QGOAL(.ENCDATA,ROOT,IEN,RIEN,VISIT,+HFCAT,FMDT,SDT,EDT)
 S CNT=$$QCNT(.ENCDATA)
 I CNT<1 D SKIP(ROOT,IEN,RIEN,VISIT,+HFCAP,"CarePlan health factors already present on visit",.RETURN) Q
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 I $$RPMS^C0FWENC() D  Q
 . D RPMSHF^C0FWENC(.ERR,DFN,VISIT,FMDT,LOC,USER,.ENCDATA,ROOT,IEN,RIEN)
 . I $$HASHF^C0FWENC(VISIT,+HFCAP) D LOADED(ROOT,IEN,RIEN,VISIT,+HFCAP,"CarePlan filed as RPMS V HEALTH FACTOR",.RETURN) Q
 . I $G(ERR)'="" D ERR(ROOT,IEN,RIEN,ERR,.RETURN) Q
 . D ERR(ROOT,IEN,RIEN,"RPMS CarePlan filing did not create SYN CP health factor",.RETURN)
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 K ZZERR,ZZERDESC
 S RET=$$DATA2PCE^PXAI("ENCDATA",PKG,"C0FW WRITEBACK",.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 I $$HASHF^C0FWENC(VISIT,+HFCAP) D  Q
 . D LOADED(ROOT,IEN,RIEN,VISIT,+HFCAP,$S(+$G(RET)=1:"CarePlan filed as SYN CP health factors",1:"CarePlan filed as SYN CP health factors with warnings"),.RETURN)
 . I +$G(RET)'=1,+$G(RET)'=-5 S @ROOT@(IEN,"load","CarePlan",RIEN,"warning")=$$WARNMSG(RET,.ZZERR,.ZZERDESC)
 D ERR(ROOT,IEN,RIEN,$$ERRMSG(RET,.ZZERR,.ZZERDESC),.RETURN)
 Q
 ;
BASE(ENCDATA,DFN,VISIT,FMDT,USER) ; Encounter header for DATA2PCE add-on filing
 S ENCDATA("ENCOUNTER",1,"PATIENT")=DFN
 S ENCDATA("ENCOUNTER",1,"ENC D/T")=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 S ENCDATA("ENCOUNTER",1,"HOS LOC")=+$P($G(^AUPNVSIT(VISIT,0)),"^",22)
 S ENCDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT(VISIT,FMDT)
 S ENCDATA("PROVIDER",1,"NAME")=USER
 S ENCDATA("PROVIDER",1,"PRIMARY")=1
 Q
 ;
QONE(ENCDATA,HFIEN,VISIT,FMDT,CMT) ; Append one HEALTH FACTOR when not already on visit
 N HF
 I +$G(HFIEN)<1 Q
 I +$G(VISIT)>0,$$HASHF^C0FWENC(VISIT,HFIEN) Q
 S HF=$O(ENCDATA("HEALTH FACTOR",""),-1)+1
 S ENCDATA("HEALTH FACTOR",HF,"HEALTH FACTOR")=+HFIEN
 S ENCDATA("HEALTH FACTOR",HF,"EVENT D/T")=+FMDT
 I $G(CMT)'="" S ENCDATA("HEALTH FACTOR",HF,"COMMENT")=$E(CMT,1,245)
 Q
 ;
QADDR(ENCDATA,HFCAT,VISIT,ADD,FMDT,CMT) ; Queue addresses HF
 N HF
 S HF=$$HFADDR^SYNFHF($P(ADD,U),$P(ADD,U,2),HFCAT)
 I +HF>0 D QONE(.ENCDATA,+HF,VISIT,FMDT,CMT)
 Q
 ;
QACT(ENCDATA,ROOT,IEN,RIEN,VISIT,HFCAT,FMDT,SDT,EDT) ; Queue activity HFs
 N AI,CODE,HF,STAT,TXT
 S AI=0
 F  S AI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","activity",AI)) Q:+AI=0  D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","activity",AI,"detail","code","coding",1,"code"))
 . S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","activity",AI,"detail","code","coding",1,"display"))
 . I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","activity",AI,"detail","code","text"))
 . S STAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","activity",AI,"detail","status"))
 . I CODE="",TXT="" Q
 . I TXT="" S TXT="Activity"
 . S HF=$$HFACT^SYNFHF(CODE,TXT,HFCAT)
 . I +HF>0 D QONE(.ENCDATA,+HF,VISIT,FMDT,$$CMT(SDT,EDT,STAT))
 Q
 ;
QGOAL(ENCDATA,ROOT,IEN,RIEN,VISIT,HFCAT,FMDT,SDT,EDT) ; Queue goal HFs from Goal references
 N ADD,GI,GRIEN,HF,REF,STAT,TXT
 S GI=0
 F  S GI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","goal",GI)) Q:+GI=0  D
 . S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","goal",GI,"reference"))
 . S GRIEN=$$REFIND(ROOT,IEN,REF,"Goal")
 . I GRIEN<1 Q
 . S TXT=$G(@ROOT@(IEN,"json","entry",GRIEN,"resource","description","text"))
 . I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",GRIEN,"resource","description","coding",1,"display"))
 . I TXT="" Q
 . S STAT=$G(@ROOT@(IEN,"json","entry",GRIEN,"resource","lifecycleStatus"))
 . I STAT="" S STAT=$G(@ROOT@(IEN,"json","entry",GRIEN,"resource","status"))
 . S ADD=$$GADDR(ROOT,IEN,GRIEN)
 . S HF=$$HFGOAL^SYNFHF($P(ADD,U),HFCAT,TXT,$TR(ADD,"^","-"))
 . I +HF>0 D QONE(.ENCDATA,+HF,VISIT,FMDT,$$CMT(SDT,EDT,STAT))
 Q
 ;
QCNT(ENCDATA) ; $$ - queued HEALTH FACTOR count
 N HF,N
 S (HF,N)=0
 F  S HF=$O(ENCDATA("HEALTH FACTOR",HF)) Q:+HF=0  S N=N+1
 Q N
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from CarePlan encounter/context
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 I VISIT<1 S VISIT=$$TXVISIT^C0FWCON(ROOT,IEN,REF)
 Q +VISIT
 ;
FMDT(ROOT,IEN,RIEN,VISIT) ; $$ - FileMan event date
 N DT
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","start")))
 I DT>0 Q +DT
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","end")))
 I DT>0 Q +DT
 Q +$P($G(^AUPNVSIT(+$G(VISIT),0)),"^")
 ;
START(ROOT,IEN,RIEN,FMDT) ; $$ - period start FileMan (date)
 N DT
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","start")))
 I DT>0 Q (DT\1)
 Q (+$G(FMDT)\1)
 ;
END(ROOT,IEN,RIEN) ; $$ - period end FileMan (date) or 0
 N DT
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","period","end")))
 I DT>0 Q (DT\1)
 Q 0
 ;
STAT(ROOT,IEN,RIEN) ; $$ - FHIR CarePlan.status
 N S
 S S=$$LOW($G(@ROOT@(IEN,"json","entry",RIEN,"resource","status")))
 I S="" Q "active"
 Q S
 ;
CAT(ROOT,IEN,RIEN) ; $$ - category code^display, preferring SNOMED over assess-plan
 N CI,CODE,DISP,SYS,USCORE
 S (CODE,DISP,USCORE)=""
 S CI=0
 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",CI)) Q:+CI=0  D  Q:CODE'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",CI,"coding",1,"system")))
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",CI,"coding",1,"code"))
 . S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",CI,"coding",1,"display"))
 . I DISP="" S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",CI,"text"))
 . I $$UP(CODE)="ASSESS-PLAN"!(SYS["CAREPLAN-CATEGORY") D  Q
 . . I USCORE="" S USCORE=CODE_U_$S(DISP'="":DISP,1:"Assessment and Plan of Treatment")
 . . S CODE=""
 . I SYS["SNOMED"!(SYS["SCT") Q
 . I CODE?1.N Q
 . S CODE=""
 I CODE="" S CODE=$P(USCORE,U),DISP=$P(USCORE,U,2)
 I DISP="" S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","title"))
 I CODE="",DISP="" S DISP="Care Plan"
 Q CODE_U_DISP
 ;
ADDR(ROOT,IEN,RIEN) ; $$ - addresses Condition code^display
 N CRIEN,REF
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","addresses",1,"reference"))
 I REF="" Q ""
 S CRIEN=$$REFIND(ROOT,IEN,REF,"Condition")
 I CRIEN<1 Q ""
 Q $$RESCODE(ROOT,IEN,CRIEN)
 ;
GADDR(ROOT,IEN,GRIEN) ; $$ - Goal.addresses Condition code^display
 N CRIEN,REF
 S REF=$G(@ROOT@(IEN,"json","entry",GRIEN,"resource","addresses",1,"reference"))
 I REF="" Q ""
 S CRIEN=$$REFIND(ROOT,IEN,REF,"Condition")
 I CRIEN<1 Q ""
 Q $$RESCODE(ROOT,IEN,CRIEN)
 ;
RESCODE(ROOT,IEN,RIEN) ; $$ - first SNOMED (else first) coding on resource.code
 N CI,CODE,DISP,SYS
 S (CODE,DISP)=""
 S CI=0
 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI)) Q:+CI=0  D  Q:CODE'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI,"system")))
 . I SYS'="",SYS'["SNOMED",SYS'["SCT" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI,"code"))
 . S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",CI,"display"))
 I CODE="" D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 . S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I DISP="" S DISP=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 Q CODE_U_DISP
 ;
REFIND(ROOT,IEN,REF,TYPE) ; $$ - entry index for a same-bundle reference
 N ERIEN,ID,HIT
 S REF=$G(REF),TYPE=$G(TYPE)
 I REF="" Q 0
 I REF["urn:uuid:" S ID=$P(REF,"urn:uuid:",2)
 E  I REF["/" S ID=$P(REF,"/",$L(REF,"/"))
 E  S ID=REF
 S ID=$P(ID,";",1)
 S (ERIEN,HIT)=0
 F  S ERIEN=$O(@ROOT@(IEN,"json","entry",ERIEN)) Q:+ERIEN=0  D  Q:HIT
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"resource","resourceType"))'=TYPE Q
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"fullUrl"))=REF S HIT=ERIEN Q
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"resource","id"))=ID S HIT=ERIEN Q
 Q +HIT
 ;
CMT(SDT,EDT,STAT) ; $$ - GETCP-readable HF comment
 N T
 S T="Start: "_(+$G(SDT)\1)_" End: "_$S(+$G(EDT)>0:(+EDT\1),1:"")
 I $G(STAT)'="" S T=T_" Status: "_STAT
 Q T
 ;
SERCAT(VISIT,FMDT) ; $$ - service category
 N CAT
 S CAT=$P($G(^AUPNVSIT(+$G(VISIT),0)),"^",7)
 I CAT'="" Q CAT
 Q $S((+$G(FMDT)\1)<$$DT^XLFDT:"E",1:"A")
 ;
LOADED(ROOT,IEN,RIEN,VISIT,HFIEN,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"CarePlan","CarePlan","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","CarePlan",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","CarePlan",RIEN,"healthFactorIen")=+HFIEN
 S @ROOT@(IEN,"load","CarePlan",RIEN,"engine")="C0FW"
 S RETURN("domains","CarePlan","visitIen")=+VISIT
 I $T(INV^C0FWCAC)'="" D INV^C0FWCAC(IEN,ROOT)
 Q
 ;
SKIP(ROOT,IEN,RIEN,VISIT,HFIEN,MSG,RETURN) ; Record skip (already filed / no visit)
 D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"CarePlan","CarePlan",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","CarePlan",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","CarePlan",RIEN,"healthFactorIen")=+HFIEN
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"CarePlan","CarePlan",$G(MSG),.RETURN)
 Q
 ;
ERRMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE error text
 N MSG,N
 S MSG="DATA2PCE CarePlan health-factor filing failed: "_$G(RET)
 S N=0 F  S N=$O(ZZERDESC(N)) Q:+N=0  S MSG=MSG_" "_$G(ZZERDESC(N))
 I '$D(ZZERDESC),$D(ZZERR) S MSG=MSG_" "_$$ERRTXT("ZZERR")
 Q MSG
 ;
WARNMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE warning text
 N MSG,N
 S MSG="DATA2PCE returned non-clean status ("_$G(RET)_") after CarePlan filing"
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
LOW(X) ; $$ - lowercase
 Q $TR($G(X),"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")
 ;
