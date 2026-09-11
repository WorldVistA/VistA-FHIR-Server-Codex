C0FWIMM ; VEHU/Codex - C0FW immunization writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Immunization on an existing visit
 N DFN,FMDT,IMMDATA,IMMIEN,PKG,RET,USER,VISIT,ZZERR,ZZERDESC
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Immunization" D ERR(ROOT,IEN,RIEN,"Resource is not Immunization",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D SKIP(ROOT,IEN,RIEN,0,0,"Immunization has no resolved encounter visit; skipped.",.RETURN) Q
 S IMMIEN=$$IMMIEN(ROOT,IEN,RIEN)
 I IMMIEN<1 D SKIP(ROOT,IEN,RIEN,0,0,"Immunization CVX code not found in ^AUTTIMM; skipped.",.RETURN) Q
 I +$$GET1^DIQ(9999999.14,IMMIEN_",",.07,"I") D SKIP(ROOT,IEN,RIEN,VISIT,IMMIEN,"Immunization is inactive in ^AUTTIMM; skipped.",.RETURN) Q
 I $$HASIMM(VISIT,IMMIEN) D SKIP(ROOT,IEN,RIEN,VISIT,IMMIEN,"Immunization already filed on visit",.RETURN) Q
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 I FMDT<1 S FMDT=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 I FMDT<1 D ERR(ROOT,IEN,RIEN,"Missing Immunization occurrence date and visit date",.RETURN) Q
 S USER=$$USER^C0FWENC()
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 K IMMDATA,ZZERR,ZZERDESC
 D BUILD(.IMMDATA,ROOT,IEN,RIEN,DFN,VISIT,IMMIEN,FMDT,USER)
 S DUZ=USER
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=500
 D IO^C0FWCTX
 I $$RPMS^C0FWENC() D RPMSLOAD(ROOT,IEN,RIEN,DFN,VISIT,IMMIEN,FMDT,USER,.RETURN) Q
 S RET=$$DATA2PCE^PXAI("IMMDATA",PKG,"C0FW WRITEBACK",.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 I +$G(RET)'=1,+$G(RET)'=-5,'$$HASIMM(VISIT,IMMIEN) D ERR(ROOT,IEN,RIEN,$$ERRMSG(RET,.ZZERR,.ZZERDESC),.RETURN) Q
 D LOADED(ROOT,IEN,RIEN,VISIT,IMMIEN,$S(+$G(RET)'=1:"Immunization filed through DATA2PCE with warnings",1:"Immunization filed through DATA2PCE"),.RETURN)
 I +$G(RET)'=1 S @ROOT@(IEN,"load","Immunization",RIEN,"warning")=$$WARNMSG(RET,.ZZERR,.ZZERDESC)
 Q
 ;
RPMSLOAD(ROOT,IEN,RIEN,DFN,VISIT,IMMIEN,FMDT,USER,RETURN) ; File one RPMS V IMMUNIZATION through APCDALVR
 N ERR,LOC,NEWIEN,SERIES
 S LOC=+$P($G(^AUPNVSIT(+$G(VISIT),0)),U,22)
 I LOC<1 D ERR(ROOT,IEN,RIEN,"Unable to resolve hospital location from RPMS visit",.RETURN) Q
 S SERIES=$$SERIES(ROOT,IEN,RIEN)
 S NEWIEN=$$RPMSIMM^C0FWENC(.ERR,DFN,VISIT,IMMIEN,FMDT,LOC,USER,SERIES)
 I $G(ERR)'="" D ERR(ROOT,IEN,RIEN,ERR,.RETURN) Q
 D LOADED(ROOT,IEN,RIEN,VISIT,IMMIEN,"Immunization filed as RPMS V IMMUNIZATION through APCDALVR",.RETURN)
 S @ROOT@(IEN,"load","Immunization",RIEN,"ien")=NEWIEN
 Q
 ;
BUILD(IMMDATA,ROOT,IEN,RIEN,DFN,VISIT,IMMIEN,FMDT,USER) ; Build DATA2PCE payload
 N COMMENT,SERIES
 S IMMDATA("ENCOUNTER",1,"PATIENT")=DFN
 S IMMDATA("ENCOUNTER",1,"ENC D/T")=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 S IMMDATA("ENCOUNTER",1,"HOS LOC")=+$P($G(^AUPNVSIT(VISIT,0)),"^",22)
 S IMMDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT(VISIT,FMDT)
 S IMMDATA("IMMUNIZATION",1,"IMMUN")=IMMIEN
 S IMMDATA("IMMUNIZATION",1,"EVENT D/T")=FMDT
 S IMMDATA("IMMUNIZATION",1,"SERVICE CATEGORY")=$$SERCAT(VISIT,FMDT)
 S IMMDATA("IMMUNIZATION",1,"ENC PROVIDER")=USER
 S SERIES=$$SERIES(ROOT,IEN,RIEN) I SERIES'="" S IMMDATA("IMMUNIZATION",1,"SERIES")=SERIES
 S COMMENT=$$COMMENT(ROOT,IEN,RIEN) I COMMENT'="" S IMMDATA("IMMUNIZATION",1,"COMMENT")=COMMENT
 Q
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from Immunization encounter reference
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 Q +VISIT
 ;
IMMIEN(ROOT,IEN,RIEN) ; $$ - Immunization dictionary IEN from CVX coding
 N CODE,IDX,SYS
 S IDX=0
 F  S IDX=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","vaccineCode","coding",IDX)) Q:+IDX=0  D  Q:+$G(CODE)>0
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","vaccineCode","coding",IDX,"system")))
 . I SYS'["CVX",SYS'["HL7.ORG/FHIR/SID/CVX" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","vaccineCode","coding",IDX,"code"))
 I $G(CODE)="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","vaccineCode","coding",1,"code"))
 Q $$CVXIEN($G(CODE))
 ;
CVXIEN(CODE) ; $$ - ^AUTTIMM IEN from CVX code
 N IEN
 S CODE=$G(CODE)
 I CODE="" Q 0
 S IEN=+$O(^AUTTIMM("C",CODE,0))
 I IEN>0 Q IEN
 I CODE?1.3N S IEN=+$O(^AUTTIMM("C",+CODE,0))
 Q +IEN
 ;
FMDT(ROOT,IEN,RIEN) ; $$ - occurrence date/time as FileMan
 N DT
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","occurrenceDateTime"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","date"))
 Q $$FHIRTFM^C0FWFUTL(DT)
 ;
SERIES(ROOT,IEN,RIEN) ; $$ - V Immunization series code when obvious
 N TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","protocolApplied",1,"doseNumberPositiveInt"))
 I TXT?1N Q TXT
 S TXT=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","protocolApplied",1,"doseNumberString")))
 I TXT?1N Q TXT
 I TXT["BOOST" Q "B"
 I TXT["COMPLETE" Q "C"
 Q ""
 ;
COMMENT(ROOT,IEN,RIEN) ; $$ - comment from FHIR note or reason text
 N TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",1,"text"))
 I TXT'="" Q $E(TXT,1,245)
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reasonCode",1,"text"))
 Q $E(TXT,1,245)
 ;
HASIMM(VISIT,IMMIEN) ; $$ - true if visit already has this immunization
 N IND
 S IND=0
 F  S IND=$O(^AUPNVIMM("AD",+$G(VISIT),IND)) Q:+IND=0  I +$P($G(^AUPNVIMM(IND,0)),"^")=+$G(IMMIEN) Q
 Q $S(+IND>0:1,1:0)
 ;
SERCAT(VISIT,FMDT) ; $$ - service category
 N CAT
 S CAT=$P($G(^AUPNVSIT(+$G(VISIT),0)),"^",7)
 I CAT'="" Q CAT
 Q $S((+$G(FMDT)\1)<$$DT^XLFDT:"E",1:"A")
 ;
LOADED(ROOT,IEN,RIEN,VISIT,IMMIEN,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Immunization","Immunization","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Immunization",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","Immunization",RIEN,"immunizationIen")=+IMMIEN
 S @ROOT@(IEN,"load","Immunization",RIEN,"engine")="C0FW"
 S RETURN("domains","Immunization","visitIen")=+VISIT
 Q
 ;
SKIP(ROOT,IEN,RIEN,VISIT,IMMIEN,MSG,RETURN) ; Record idempotent skip
 D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Immunization","Immunization",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Immunization",RIEN,"visitIen")=+VISIT
 S @ROOT@(IEN,"load","Immunization",RIEN,"immunizationIen")=+IMMIEN
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Immunization","Immunization",$G(MSG),.RETURN)
 Q
 ;
ERRMSG(RET,ZZERR,ZZERDESC) ; $$ - DATA2PCE error text
 N MSG,N
 S MSG="DATA2PCE immunization filing failed: "_$G(RET)
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
