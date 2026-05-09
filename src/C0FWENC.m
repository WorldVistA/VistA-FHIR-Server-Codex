C0FWENC ; VEHU/Codex - C0FW encounter writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Encounter as a PCE/PCC visit
 N DFN,ENCDATA,FMDT,ID,LOC,PKG,RET,SOURCE,USER,VISIT,ZZERR,ZZERDESC
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Encounter" D ERR(ROOT,IEN,RIEN,"Resource is not Encounter",.RETURN) Q
 S ID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 S VISIT=$$KNOWN(ROOT,IEN,RIEN,ID)
 I VISIT>0 D LOADED(ROOT,IEN,RIEN,VISIT,"Encounter already linked to visit",.RETURN) Q
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 I FMDT<1 D ERR(ROOT,IEN,RIEN,"Missing or invalid Encounter period.start/end",.RETURN) Q
 S LOC=$$LOC(ROOT,IEN,RIEN)
 I LOC<1 D ERR(ROOT,IEN,RIEN,"Unable to resolve hospital location",.RETURN) Q
 S USER=$$USER()
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 S SOURCE="C0FW WRITEBACK"
 K ENCDATA,ZZERR,ZZERDESC,VISIT
 S ENCDATA("ENCOUNTER",1,"PATIENT")=DFN
 S ENCDATA("ENCOUNTER",1,"ENCOUNTER TYPE")="P"
 S ENCDATA("ENCOUNTER",1,"ENC D/T")=FMDT
 S ENCDATA("ENCOUNTER",1,"HOS LOC")=LOC
 S ENCDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT(FMDT)
 S ENCDATA("PROVIDER",1,"NAME")=USER
 S ENCDATA("PROVIDER",1,"PRIMARY")=1
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 S RET=$$DATA2PCE^PXAI("ENCDATA",PKG,SOURCE,.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 I +$G(RET)'=1,+$G(RET)'=-5 D  Q
 . N MSG S MSG=$$ERRMSG($G(RET),.ZZERR,.ZZERDESC)
 . D ERR(ROOT,IEN,RIEN,MSG,.RETURN)
 I +$G(VISIT)<1 D ERR(ROOT,IEN,RIEN,"DATA2PCE did not return a visit IEN",.RETURN) Q
 D LOADED(ROOT,IEN,RIEN,+VISIT,$S(+$G(RET)=-5:"Encounter filed through DATA2PCE with warnings",1:"Encounter filed through DATA2PCE"),.RETURN)
 I +$G(RET)=-5 S @ROOT@(IEN,"load","Encounter",RIEN,"warning")=$$WARNMSG(.ZZERR,.ZZERDESC)
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
LOADED(ROOT,IEN,RIEN,VISIT,MSG,RETURN) ; Record loaded visit status
 N ID
 S ID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Encounter","Encounter","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Encounter",RIEN,"visitIen")=+VISIT
 I ID'="" D SETIDXGN^C0FWFUTL($NA(@ROOT@(IEN)),RIEN,"visitIen",ID)
 S RETURN("domains","Encounter","visitIen")=+VISIT
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
