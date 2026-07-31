C0FWSR ; VEHU/Codex - C0FW ServiceRequest writeback via ORDER^RAMAG02 ;Jul 30, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 30, 2026
 ;
 ; Files imaging ServiceRequest resources as Radiology orders (file 75.1)
 ; through ORDER^RAMAG02. Initial support: CMS125 mammography SNOMED codes.
 ; Creates an ordered exam only (does not register/complete the exam).
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR ServiceRequest as a radiology order
 N DFN,HIST,MAGLOC,MSG,PROV,RAPROC,RAREASON,REQLOC,RET,SCT,TYPE,VISIT,X
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE'="ServiceRequest" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"C0FWSR only files ServiceRequest resources",.RETURN) Q
 S X="ORDER^RAMAG02"
 I $T(@X)="" D NI^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"RAMAG02 is not installed; cannot file radiology orders",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"No DFN linked to graph row",.RETURN) Q
 S SCT=$$SCT(ROOT,IEN,RIEN)
 I SCT="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"Missing SNOMED CT ServiceRequest.code",.RETURN) Q
 S RAPROC=$$RAPROC(SCT)
 I RAPROC<1 D  Q
 . S MSG="No radiology procedure (#71) mapped for SNOMED "_SCT_"; C0FWSR currently supports mammography orders only"
 . D NI^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,MSG,.RETURN)
 S MAGLOC=$$MAGLOC(RAPROC)
 I MAGLOC<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"No Mammography imaging location (#79.1) for RAPROC="_RAPROC,.RETURN) Q
 D ACTLOC(MAGLOC)
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 S REQLOC=$$REQLOC(VISIT,MAGLOC)
 I REQLOC<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"Unable to resolve requesting location (#44)",.RETURN) Q
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 S PROV=$$PROV(ROOT,IEN,RIEN)
 I PROV<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"Unable to resolve ordering provider (#200)",.RETURN) Q
 S RAREASON=$$REASON(ROOT,IEN,RIEN)
 S HIST=$$HIST(ROOT,IEN,RIEN)
 S RET=$$ORDER(DFN,MAGLOC,RAPROC,REQLOC,PROV,RAREASON,HIST)
 I +RET>0 D  Q
 . S MSG="ServiceRequest filed as radiology order RAOIFN="_+RET
 . I $P(RET,U,2)'="" S MSG=MSG_", ORIFN="_$P(RET,U,2)
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"loaded",MSG,.RETURN)
 . S RETURN("domains","ServiceRequest","raoIfn")=+RET
 . I $P(RET,U,2)'="" S RETURN("domains","ServiceRequest","orIfn")=+$P(RET,U,2)
 . I VISIT>0 S RETURN("domains","ServiceRequest","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,DFN,RAPROC,MAGLOC,REQLOC,PROV,+RET,$P(RET,U,2),"loaded",$G(RET))
 S MSG=$P(RET,U,2,$L(RET,U))
 I MSG="" S MSG=$G(RET)
 I MSG="" S MSG="ORDER^RAMAG02 returned empty status"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"ServiceRequest",TYPE,"Radiology order failed: "_MSG,.RETURN)
 D LOG(ROOT,IEN,RIEN,DFN,RAPROC,MAGLOC,REQLOC,PROV,0,"","error",MSG)
 Q
 ;
ORDER(DFN,MAGLOC,RAPROC,REQLOC,PROV,RAREASON,HIST) ; $$ - RAOIFN^ORIFN or -1^msg
 N ORIFN,RACAT,RADTE,RAMAG,RAMISC,RAOIFN
 S RADTE=$$NOW^XLFDT
 S RACAT="O"
 K RAMISC,RAMAG
 S RAMISC("ACLHIST",1)=$G(HIST)
 I $G(RAMISC("ACLHIST",1))="" S RAMISC("ACLHIST",1)="Quality AI Consult imaging order"
 I $P($G(^DPT(DFN,0)),U,2)="F" S RAMISC("PREGNANT")="N"
 S RAOIFN=$$ORDER^RAMAG02(.RAMAG,DFN,MAGLOC,RAPROC,RADTE,RACAT,REQLOC,PROV,RAREASON,.RAMISC)
 I +RAOIFN<1 Q RAOIFN
 S ORIFN=$$ORIFN(+RAOIFN)
 Q +RAOIFN_U_ORIFN
 ;
ORIFN(RAOIFN) ; $$ - File 100 IEN linked from radiology order 75.1
 N N0,ORIFN
 S N0=$G(^RAO(75.1,+$G(RAOIFN),0))
 S ORIFN=+$P(N0,U,7)
 I ORIFN<1 S ORIFN=+$P(N0,U,11)
 Q ORIFN
 ;
RAPROC(SCT) ; $$ - radiology procedure IEN (#71) for supported SNOMED codes
 N NAME,Y
 S SCT=$G(SCT)
 ; Bilateral screening mammography is the CMS125 demo default.
 I SCT=71651007!(SCT=24623002) S NAME="MAMMOGRAM BILAT"
 I $G(NAME)="" Q 0
 S Y=$O(^RAMIS(71,"B",NAME,0))
 I Y<1 S Y=$O(^RAMIS(71,"B","MAMMOGRAM UNILAT",0))
 Q +Y
 ;
MAGLOC(RAPROC) ; $$ - active imaging location (#79.1) matching procedure type
 N I,INACT,N,TDY,TYP,Y
 S TYP=+$P($G(^RAMIS(71,+$G(RAPROC),0)),U,12)
 I TYP<1 Q 0
 D NOW^%DTC S TDY=X
 S Y=0,I=0
 F  S I=$O(^RA(79.1,I)) Q:'I  D  Q:Y
 . S N=$G(^RA(79.1,I,0))
 . I +$P(N,U,6)'=TYP Q
 . S INACT=$P(N,U,19)
 . I INACT'="",INACT'>TDY Q
 . S Y=I
 ; Demo fallback: prefer matching type even if marked inactive.
 I Y<1 S I=0 F  S I=$O(^RA(79.1,I)) Q:'I  D  Q:Y
 . S N=$G(^RA(79.1,I,0))
 . I +$P(N,U,6)=TYP S Y=I
 Q +Y
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from ServiceRequest.encounter
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 I VISIT<1 S VISIT=$$TXVISIT^C0FWCON(ROOT,IEN,REF)
 Q +VISIT
 ;
REQLOC(VISIT,MAGLOC) ; $$ - requesting hospital location (#44)
 N LOC
 S LOC=0
 I +$G(VISIT)>0 S LOC=+$P($G(^AUPNVSIT(+VISIT,0)),U,22)
 I LOC<1 S LOC=+$P($G(^RA(79.1,+$G(MAGLOC),0)),U)
 Q +LOC
 ;
ACTLOC(MAGLOC) ; Clear inactive date on imaging location when needed for demo filing
 N INACT,N,TDY
 Q:+$G(MAGLOC)<1
 S N=$G(^RA(79.1,+MAGLOC,0))
 S INACT=$P(N,U,19) Q:INACT=""
 D NOW^%DTC S TDY=X
 Q:INACT>TDY
 S $P(^RA(79.1,+MAGLOC,0),U,19)=""
 Q
 ;
PROV(ROOT,IEN,RIEN) ; $$ - ordering provider DUZ
 N PROV,REF
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","requester","reference"))
 I REF["Practitioner/" S PROV=+$P(REF,"Practitioner/",2)
 I +$G(PROV)<1 S PROV=+$$DUZ^C0FWCTX()
 I +PROV<1 S PROV=1
 Q +PROV
 ;
REASON(ROOT,IEN,RIEN) ; $$ - reason for study text
 N TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I TXT="" S TXT="Screening mammography"
 Q $E(TXT,1,60)
 ;
HIST(ROOT,IEN,RIEN) ; $$ - clinical history / note text
 N NI,TXT
 S TXT=""
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI)) Q:+NI=0  D  Q:TXT'=""
 . S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",NI,"text"))
 I TXT="" S TXT="Quality AI Consult imaging order"
 Q $E(TXT,1,240)
 ;
SCT(ROOT,IEN,RIEN) ; $$ - first SNOMED CT code on ServiceRequest.code
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system")))
 . I SYS'["SNOMED",SYS'["SCT" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 I $G(CODE)="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 Q $G(CODE)
 ;
LOG(ROOT,IEN,RIEN,DFN,RAPROC,MAGLOC,REQLOC,PROV,RAOIFN,ORIFN,STATUS,RAW) ; Persist load details
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"engine")="RAMAG"
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"routine")="RAMAG02"
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"entrypoint")="ORDER^RAMAG02"
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"file")=75.1
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"dfn")=+$G(DFN)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"raproc")=+$G(RAPROC)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"magloc")=+$G(MAGLOC)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"reqloc")=+$G(REQLOC)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"provider")=+$G(PROV)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"raoIfn")=+$G(RAOIFN)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"orIfn")=+$G(ORIFN)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"rawStatus")=$G(RAW)
 S @ROOT@(IEN,"load","ServiceRequest",RIEN,"loadStatus")=$G(STATUS)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
