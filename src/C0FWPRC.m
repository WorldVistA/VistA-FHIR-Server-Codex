C0FWPRC ; VEHU/Codex - C0FW procedure writeback via PRCADD^SYNDHP65 ;Jul 30, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 30, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Procedure through PRCADD^SYNDHP65
 N CNT,DFN,HL7DT,ICN,MSG,RETSTA,SCT,TYPE,VISIT,X
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE'="Procedure" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"C0FWPRC only files Procedure resources",.RETURN) Q
 S X="PRCADD^SYNDHP65"
 I $T(@X)="" D NI^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"SYNDHP65 is not installed; cannot file procedures",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"No DFN linked to graph row",.RETURN) Q
 S ICN=$$ICN^C0FWLAB(DFN,IEN)
 I ICN="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Patient has no ICN; PRCADD^SYNDHP65 requires AFICN",.RETURN) Q
 S SCT=$$SCT(ROOT,IEN,RIEN)
 I SCT="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Missing SNOMED CT Procedure.code",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Procedure has no resolved encounter visit pointer",.RETURN) Q
 S HL7DT=$$HL7DT(ROOT,IEN,RIEN)
 I HL7DT="" D  Q
 . ; Fall back to visit date/time when Procedure.performed* is absent
 . N FMDT
 . S FMDT=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 . I FMDT<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Missing Procedure performed date/time and visit date",.RETURN) Q
 . S HL7DT=$$FMTHL7^XLFDT(FMDT)
 . I HL7DT="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Unable to convert visit date to HL7",.RETURN) Q
 S CNT=1
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 K RETSTA
 D PRCADD^SYNDHP65(.RETSTA,ICN,VISIT,CNT,SCT,HL7DT)
 I $$OK(RETSTA) D  Q
 . S MSG="Procedure filed through PRCADD^SYNDHP65: SCT="_SCT
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"loaded",MSG,.RETURN)
 . S RETURN("domains","Procedure","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,ICN,VISIT,SCT,HL7DT,"loaded",$G(RETSTA))
 S MSG=$G(RETSTA)
 I MSG="" S MSG="-1^PRCADD^SYNDHP65 returned empty status"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"PRCADD failed: "_MSG,.RETURN)
 D LOG(ROOT,IEN,RIEN,ICN,VISIT,SCT,HL7DT,"error",MSG)
 Q
 ;
OK(RETSTA) ; $$ - true when PRCADD / DATA2PCE result is acceptable
 N R
 S R=$G(RETSTA)
 I +R=1 Q 1
 I +R=-5 Q 1 ; DATA2PCE warnings with data present
 Q 0
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from Procedure encounter reference
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 I VISIT<1 S VISIT=$$TXVISIT^C0FWCON(ROOT,IEN,REF)
 Q +VISIT
 ;
SCT(ROOT,IEN,RIEN) ; $$ - first SNOMED CT code on Procedure.code
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system")))
 . I SYS'["SNOMED",SYS'["SCT" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 I $G(CODE)="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 Q $G(CODE)
 ;
HL7DT(ROOT,IEN,RIEN) ; $$ - compact HL7 date/time from Procedure.performed*
 N DT,HL7
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","performedDateTime"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","performedPeriod","start"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","performedPeriod","end"))
 S HL7=$$FHIRISO2HL7^C0FWFUTL(DT)
 I HL7="" Q ""
 I $L(HL7)=8 S HL7=HL7_"120000"
 I $L(HL7)'<14,$E(HL7,9,14)="000000" S HL7=$E(HL7,1,8)_"120000"
 Q HL7
 ;
LOG(ROOT,IEN,RIEN,ICN,VISIT,SCT,HL7DT,STATUS,RAW) ; Persist load details
 S @ROOT@(IEN,"load","Procedure",RIEN,"engine")="SYN/PCE"
 S @ROOT@(IEN,"load","Procedure",RIEN,"routine")="SYNDHP65"
 S @ROOT@(IEN,"load","Procedure",RIEN,"entrypoint")="PRCADD^SYNDHP65"
 S @ROOT@(IEN,"load","Procedure",RIEN,"file")=9000010.18
 S @ROOT@(IEN,"load","Procedure",RIEN,"icn")=$G(ICN)
 S @ROOT@(IEN,"load","Procedure",RIEN,"visitIen")=+$G(VISIT)
 S @ROOT@(IEN,"load","Procedure",RIEN,"sct")=$G(SCT)
 S @ROOT@(IEN,"load","Procedure",RIEN,"hl7DateTime")=$G(HL7DT)
 S @ROOT@(IEN,"load","Procedure",RIEN,"rawStatus")=$G(RAW)
 S @ROOT@(IEN,"load","Procedure",RIEN,"loadStatus")=$G(STATUS)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
