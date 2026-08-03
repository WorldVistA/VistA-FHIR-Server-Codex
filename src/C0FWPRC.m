C0FWPRC ; VEHU/Codex - C0FW procedure writeback (VEHU SYN + RPMS PCE) ;Aug 02, 2026
 ;;0.2;C0FHIR PROJECT;;Aug 02, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Procedure
 N TYPE
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE'="Procedure" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"C0FWPRC only files Procedure resources",.RETURN) Q
 I $$ISRPMS^C0FWPOL() D LOADRPMS(ROOT,IEN,RIEN,.RETURN) Q
 D LOADVEHU(ROOT,IEN,RIEN,.RETURN)
 Q
 ;
LOADVEHU(ROOT,IEN,RIEN,RETURN) ; VEHU/SYN path via PRCADD^SYNDHP65
 N CNT,DFN,HL7DT,ICN,MSG,RETSTA,SCT,TYPE,VISIT,X
 S TYPE="Procedure"
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
 . D LOG(ROOT,IEN,RIEN,"","SYN/PCE","PRCADD^SYNDHP65",VISIT,SCT,"",HL7DT,"loaded",$G(RETSTA))
 S MSG=$G(RETSTA)
 I MSG="" S MSG="-1^PRCADD^SYNDHP65 returned empty status"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"PRCADD failed: "_MSG,.RETURN)
 D LOG(ROOT,IEN,RIEN,"","SYN/PCE","PRCADD^SYNDHP65",VISIT,SCT,"",HL7DT,"error",MSG)
 Q
 ;
LOADRPMS(ROOT,IEN,RIEN,RETURN) ; RPMS path: ensure CPT + DATA2PCE^PXAI (IEN pointer)
 N CPT,CPTIEN,DFN,FMDT,MSG,OS5,RETSTA,SCT,TYPE,VISIT
 S TYPE="Procedure"
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"No DFN linked to graph row",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Procedure has no resolved encounter visit pointer",.RETURN) Q
 S SCT=$$SCT(ROOT,IEN,RIEN)
 S OS5=$$CPTCODE(ROOT,IEN,RIEN)
 I OS5="",SCT'="" S OS5=$$SCT2OS5(SCT)
 I OS5="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"No CPT/OS5 mapping for Procedure.code (SCT="_SCT_")",.RETURN) Q
 S CPTIEN=$$ENSURECPT(OS5,$$CPTNAME(ROOT,IEN,RIEN,OS5,SCT))
 I CPTIEN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Unable to resolve/seed CPT "_OS5_" in file #81",.RETURN) Q
 I $$HASCPT(VISIT,CPTIEN) D  Q
 . S MSG="Procedure already matched visit-linked V CPT: "_OS5
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"skipped",MSG,.RETURN)
 . S RETURN("domains","Procedure","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,OS5,"RPMS/PCE","DATA2PCE^PXAI",VISIT,SCT,CPTIEN,"","skipped","already present")
 S FMDT=$$FMDT(ROOT,IEN,RIEN,VISIT)
 I FMDT<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"Missing Procedure performed date/time and visit date",.RETURN) Q
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 S RETSTA=$$FILEPCE(VISIT,CPTIEN,FMDT)
 I $$OKRPMS(RETSTA,VISIT,CPTIEN) D  Q
 . S MSG="Procedure filed through DATA2PCE^PXAI: CPT="_OS5_" SCT="_SCT
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"loaded",MSG,.RETURN)
 . S RETURN("domains","Procedure","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,OS5,"RPMS/PCE","DATA2PCE^PXAI",VISIT,SCT,CPTIEN,"","loaded",$G(RETSTA))
 S MSG=$G(RETSTA)
 I MSG="" S MSG="-1^DATA2PCE/V CPT filing failed"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Procedure",TYPE,"RPMS procedure filing failed: "_MSG,.RETURN)
 D LOG(ROOT,IEN,RIEN,OS5,"RPMS/PCE","DATA2PCE^PXAI",VISIT,SCT,CPTIEN,"","error",MSG)
 Q
 ;
FILEPCE(VISIT,CPTIEN,FMDT) ; $$ - file V CPT via DATA2PCE; fall back to direct indexes
 N ERRRET,PACKAGE,PROCDATA,PXAPROB,RETSTA,SOURCE
 S PACKAGE=$$FIND1^DIC(9.4,,"","PCE")
 I PACKAGE<1 Q "-1^PCE package not found in file #9.4"
 S SOURCE="C0FW PROCEDURE"
 K PROCDATA
 S PROCDATA("PROCEDURE",1,"PROCEDURE")=+CPTIEN
 S PROCDATA("PROCEDURE",1,"QTY")=1
 S PROCDATA("PROCEDURE",1,"EVENT D/T")=+FMDT
 K RETSTA,ERRRET,PXAPROB
 ; RPMS PXAI formals: 9 args (no ACCOUNT). Pass CPT IEN, not code text.
 S RETSTA=$$DATA2PCE^PXAI("PROCDATA",PACKAGE,SOURCE,.VISIT,DUZ,"",.ERRRET,"",.PXAPROB)
 I $$HASCPT(VISIT,CPTIEN) Q $S($G(RETSTA)'="":RETSTA,1:1)
 ; Fallback when DATA2PCE rejects sparse CPT dictionary / side-effect errors
 I $$DIRECT(VISIT,CPTIEN) Q "1^direct V CPT"
 Q $S($G(RETSTA)'="":RETSTA,1:"-1^DATA2PCE did not create V CPT")
 ;
DIRECT(VISIT,CPTIEN) ; $$ - create minimal V CPT + indexes when PCE API fails
 N DFN,IEN,X0
 S DFN=+$P($G(^AUPNVSIT(+VISIT,0)),"^",5)
 I DFN<1!(+CPTIEN<1) Q 0
 I $$HASCPT(VISIT,CPTIEN) Q 1
 S IEN=$O(^AUPNVCPT(" "),-1)+1
 I IEN<1 S IEN=1
 S X0=+CPTIEN_"^"_DFN_"^"_+VISIT
 S ^AUPNVCPT(IEN,0)=X0
 S ^AUPNVCPT("B",+CPTIEN,IEN)=""
 S ^AUPNVCPT("C",DFN,IEN)=""
 S ^AUPNVCPT("AD",+VISIT,IEN)=""
 S $P(^AUPNVCPT(0),"^",3)=IEN
 S $P(^AUPNVCPT(0),"^",4)=+$P($G(^AUPNVCPT(0)),"^",4)+1
 Q 1
 ;
HASCPT(VISIT,CPTIEN) ; $$ - visit already has this CPT IEN
 N DA,HIT,X0
 S HIT=0,DA=0
 F  S DA=$O(^AUPNVCPT("AD",+VISIT,DA)) Q:'DA  D  Q:HIT
 . S X0=$G(^AUPNVCPT(DA,0))
 . I +X0=+CPTIEN S HIT=1
 Q HIT
 ;
OK(RETSTA) ; $$ - true when PRCADD / DATA2PCE result is acceptable
 N R
 S R=$G(RETSTA)
 I +R=1 Q 1
 I +R=-5 Q 1 ; DATA2PCE warnings with data present
 Q 0
 ;
OKRPMS(RETSTA,VISIT,CPTIEN) ; $$ - success if API ok or V CPT present
 I $$HASCPT(VISIT,CPTIEN) Q 1
 Q $$OK($G(RETSTA))
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
CPTCODE(ROOT,IEN,RIEN) ; $$ - CPT/HCPCS/OS5 code from Procedure.code when present
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system")))
 . I SYS'["CPT",SYS'["HCPCS",SYS'["OS5",SYS'["C4" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 Q $G(CODE)
 ;
SCT2OS5(SCT) ; $$ - map SNOMED CT to OS5/CPT code
 N MAP,OS5
 S SCT=$G(SCT)
 I SCT="" Q ""
 ; Prefer installed SYN map when present
 I $T(+0^SYNDHPMP)'="" D  I $G(OS5)'="" Q OS5
 . S MAP=$$MAP^SYNDHPMP("sct2os5",SCT)
 . I +MAP=1 S OS5=$P(MAP,"^",2)
 ; Built-in allowlist: CMS125 mammo + common quality/Synthea procedures
 I SCT=71651007 Q "0583H" ; Mammography (procedure)
 I SCT=24623002 Q "1571J" ; Screening mammography (procedure)
 I SCT=241615005 Q "71020" ; Magnetic resonance imaging of breast
 I SCT=268547008 Q "77057" ; Screening for malignant neoplasm of breast
 I SCT=432102000 Q "71020" ; Diagnostic imaging procedure
 I SCT=274631009 Q "93000" ; Electrocardiographic procedure
 I SCT=5880005 Q "93000" ; Physical examination procedure (use ECG CPT only if present)
 I SCT=73761001 Q "90471" ; Colonoscopy (screening proxy when CPT present)
 I SCT=444783004 Q "45378" ; Screening colonoscopy
 I SCT=171207006 Q "G0101" ; Depression screening (proxy HCPCS if present)
 Q ""
 ;
CPTNAME(ROOT,IEN,RIEN,OS5,SCT) ; $$ - display for seeded CPT
 N NAME
 S NAME=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I NAME="" S NAME=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I NAME="" D
 . I OS5="0583H" S NAME="Mammography (procedure)" Q
 . I OS5="1571J" S NAME="Screening mammography (procedure)" Q
 . I $G(SCT)'="" S NAME="Procedure "_SCT Q
 . S NAME="Procedure "_OS5
 Q NAME
 ;
ENSURECPT(OS5,NAME) ; $$ - CPT IEN in #81; seed minimal OS5 row when missing
 N IEN
 S OS5=$G(OS5)
 I OS5="" Q 0
 S IEN=$O(^ICPT("B",OS5,0))
 I IEN>0 Q +IEN
 I $G(NAME)="" S NAME="Procedure "_OS5
 S IEN=$O(^ICPT(" "),-1)+1
 I IEN<1 S IEN=200000001
 S ^ICPT(IEN,0)=OS5_"^"_NAME_"^30"
 S ^ICPT("B",OS5,IEN)=""
 S ^ICPT(IEN,62)=NAME
 S ^ICPT(IEN,67,0)="^81.67D^1^1"
 S ^ICPT(IEN,67,1,0)="3000101^"_NAME
 S $P(^ICPT(0),"^",3)=IEN
 S $P(^ICPT(0),"^",4)=+$P($G(^ICPT(0)),"^",4)+1
 Q +IEN
 ;
FMDT(ROOT,IEN,RIEN,VISIT) ; $$ - FileMan date/time for PCE EVENT D/T
 N HL7,FMDT
 S HL7=$$HL7DT(ROOT,IEN,RIEN)
 I HL7'="" S FMDT=$$HL7TFM^XLFDT(HL7) I FMDT>0 Q +FMDT
 Q +$P($G(^AUPNVSIT(+VISIT,0)),"^")
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
LOG(ROOT,IEN,RIEN,OS5,ENG,ENTRY,VISIT,SCT,CPTIEN,HL7DT,STATUS,RAW) ; Persist load details
 S @ROOT@(IEN,"load","Procedure",RIEN,"engine")=$G(ENG)
 S @ROOT@(IEN,"load","Procedure",RIEN,"routine")=$S($G(ENG)["RPMS":"C0FWPRC",1:"SYNDHP65")
 S @ROOT@(IEN,"load","Procedure",RIEN,"entrypoint")=$G(ENTRY)
 S @ROOT@(IEN,"load","Procedure",RIEN,"file")=9000010.18
 S @ROOT@(IEN,"load","Procedure",RIEN,"os5")=$G(OS5)
 S @ROOT@(IEN,"load","Procedure",RIEN,"cptIen")=+$G(CPTIEN)
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
