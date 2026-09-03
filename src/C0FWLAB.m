C0FWLAB ; VEHU/Codex - C0FW lab writeback via SYN/ISI ;Jul 18, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 18, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File lab Observation (ISI) or accept into fhir-intake graph
 N CSAMP,DFN,HL7DT,ICN,LOCN,LOINC,MSG,RETSTA,TEST,TYPE,VAL,X
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE="DiagnosticReport" D  Q
 . ; Panels stay in fhir-intake; C0FHIRLG GETGRPDR reads them as labs-of-record.
 . I $$USEGRAPH() D GRAPHOK(ROOT,IEN,RIEN,TYPE,"Lab DiagnosticReport retained in fhir-intake (RPMS graph labs-of-record)",.RETURN) Q
 . D NI^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"DiagnosticReport lab panels are not filed by C0FWLAB yet; accept Observation actions for atomic results.",.RETURN)
 I TYPE'="Observation" D NI^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"C0FWLAB only files laboratory Observation resources",.RETURN) Q
 I $$ISVITAL^C0FWVIT(ROOT,IEN,RIEN) D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Observation is a vital-sign; routed to C0FWVIT instead",.RETURN) Q
 I $$ISSMOK^C0FWSMOK(ROOT,IEN,RIEN) D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Observation is smoking status; routed to C0FWSMOK instead",.RETURN) Q
 ; RPMS (and hosts without ISI lab import): intake graph is already persisted by
 ; /updatepatient before LOAD; mark loaded so Quality AI Consult is not "skipped".
 I $$USEGRAPH() D GRAPHOK(ROOT,IEN,RIEN,TYPE,"Lab Observation retained in fhir-intake (RPMS graph labs-of-record)",.RETURN) Q
 S X="LABADD^SYNDHP63"
 I $T(@X)="" D NI^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"SYNDHP63 is not installed; cannot file labs through ISI",.RETURN) Q
 S X="LAB^ISIIMP12"
 I $T(@X)="" D NI^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"ISIIMP12 is not installed; cannot file labs through ISI",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"No DFN linked to graph row",.RETURN) Q
 S ICN=$$ICN(DFN,IEN)
 I ICN="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Patient has no ICN; LABADD^SYNDHP63 requires AFICN",.RETURN) Q
 I $$GET1^DIQ(2,DFN_",",.09,"I")="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Patient has no SSN; ISI lab import requires PAT_SSN",.RETURN) Q
 S LOINC=$$LOINC(ROOT,IEN,RIEN)
 S TEST=$$TEST(LOINC,ROOT,IEN,RIEN)
 I TEST="" D  Q
 . ; Quality AI / unmapped LOINCs (PHQ, FIT, etc.): keep fhir-intake as lab-of-record
 . ; instead of hard-failing when #60 has no ISI map.
 . I LOINC'="" D GRAPHOK(ROOT,IEN,RIEN,TYPE,"Lab Observation retained in fhir-intake (no #60 map for LOINC "_LOINC_")",.RETURN) Q
 . D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Unable to map LOINC/code to VistA #60 lab test name"_$S(LOINC'="":" ("_LOINC_")",1:""),.RETURN)
 S VAL=$$VALUE(ROOT,IEN,RIEN)
 I VAL="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Missing Observation valueQuantity/valueString",.RETURN) Q
 S HL7DT=$$HL7DT(ROOT,IEN,RIEN)
 I HL7DT="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Missing or invalid effectiveDateTime (time required)",.RETURN) Q
 S LOCN=$$LOCN(ROOT,IEN,RIEN)
 I LOCN="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"Unable to resolve hospital location name",.RETURN) Q
 S CSAMP=$$CSAMP(LOINC)
 ; LABADD / LRPARAM require Kernel DUZ(2) and IO context in web jobs.
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 K RETSTA
 D LABADD^SYNDHP63(.RETSTA,ICN,LOCN,TEST,VAL,HL7DT,LOINC,CSAMP)
 I +$G(RETSTA)=1 D  Q
 . S MSG="Lab filed through LABADD^SYNDHP63 / $$LAB^ISIIMP12: "_TEST_"="_VAL
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"loaded",MSG,.RETURN)
 . D LOG(ROOT,IEN,RIEN,ICN,LOCN,TEST,VAL,HL7DT,LOINC,CSAMP,"loaded",$G(RETSTA))
 I $G(RETSTA)["Duplicate Lab Test entry" D  Q
 . S MSG="Duplicate lab treated as loaded: "_TEST
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"loaded",MSG,.RETURN)
 . D LOG(ROOT,IEN,RIEN,ICN,LOCN,TEST,VAL,HL7DT,LOINC,CSAMP,"loaded",$G(RETSTA))
 S MSG=$G(RETSTA)
 I MSG="" S MSG="-1^LABADD^SYNDHP63 returned empty status"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"LABADD failed: "_MSG,.RETURN)
 D LOG(ROOT,IEN,RIEN,ICN,LOCN,TEST,VAL,HL7DT,LOINC,CSAMP,"error",MSG)
 Q
 ;
USEGRAPH() ; $$ - 1 when fhir-intake is lab-of-record (no LR filing)
 I $TEXT(ISRPMS^C0FWPOL)'="",$$ISRPMS^C0FWPOL() Q 1
 I $T(LABADD^SYNDHP63)="" Q 1
 Q 0
 ;
GRAPHOK(ROOT,IEN,RIEN,TYPE,MSG,RETURN) ; Mark graph-retained lab as loaded
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,"loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Lab",RIEN,"engine")="graph"
 S @ROOT@(IEN,"load","Lab",RIEN,"routine")="C0FHIRLG"
 Q
 ;
ICN(DFN,IEN) ; $$ - ICN for LABADD (must be a ^DPT("AFICN") key)
 N FULL,ICN
 ; LABADD^SYNDHP63 resolves patients only through ^DPT("AFICN",ICN).
 ; Prefer full ICN (991.1 / MPI piece 10). Bare 991.01 (e.g. 10108) is NOT
 ; an AFICN key when the indexed value is 10108V420871.
 S ICN=$$IEN2ICN^C0FWFUTL(IEN) I $$OKAFICN(ICN) Q ICN
 S ICN=$$DFN2ICN^C0FWFUTL(DFN) I $$OKAFICN(ICN) Q ICN
 I $T(dfn2icn^SYNFUTL)'="" S ICN=$$dfn2icn^SYNFUTL(DFN) I $$OKAFICN(ICN) Q ICN
 S ICN=$$GET1^DIQ(2,DFN_",",991.1,"E") I $$OKAFICN(ICN) Q ICN
 S ICN=$P($G(^DPT(DFN,"MPI")),U,10) I $$OKAFICN(ICN) Q ICN
 S ICN=$$GET1^DIQ(2,DFN_",",991.01,"E")
 I $$OKAFICN(ICN) Q ICN
 I ICN'="",ICN'["V" D
 . S FULL=ICN_"V"_$P($G(^DPT(DFN,"MPI")),U,2)
 . I $$OKAFICN(FULL) S ICN=FULL
 I $$OKAFICN(ICN) Q ICN
 Q ""
 ;
OKAFICN(ICN) ; $$ - 1 if ICN is present in ^DPT("AFICN")
 I $G(ICN)="" Q 0
 Q ($D(^DPT("AFICN",ICN))>0)
 ;
LOINC(ROOT,IEN,RIEN) ; $$ - first LOINC code on Observation.code
 N C,CODE,N,SYS
 S (CODE,N)=""
 F  S N=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",N)) Q:N=""  D  Q:CODE'=""
 . S C=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",N,"code"))
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",N,"system")))
 . I C="" Q
 . I SYS["LOINC" S CODE=C Q
 . I C?1.5N1"-"1N S CODE=C Q
 Q CODE
 ;
TEST(LOINC,ROOT,IEN,RIEN) ; $$ - VistA #60 name for LOINC / display
 N NAME,TXT,TRY
 S NAME=""
 I $G(LOINC)'="" D
 . I $T(graphmap^SYNGRAPH)'="" D
 . . S TRY=$$graphmap^SYNGRAPH("loinc-lab-map",LOINC)
 . . I +TRY'=-1,TRY'="" S NAME=$$TRIM^XLFSTR(TRY)
 . I NAME="",$T(MAP^SYNQLDM)'="" D
 . . S TRY=$$MAP^SYNQLDM(LOINC,"labs")
 . . I TRY'="",+TRY'=-1 S NAME=$$TRIM^XLFSTR(TRY)
 . I NAME="" S NAME=$$A1CMAP(LOINC)
 I NAME'="" Q NAME
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 I $$UP(TXT)["A1C"!($$UP(TXT)["HEMOGLOBIN A1") Q "HEMOGLOBIN A1C"
 Q ""
 ;
A1CMAP(LOINC) ; $$ - built-in HbA1c LOINC aliases used by Synthea/quality mode
 S LOINC=$G(LOINC)
 I LOINC="4548-4" Q "HEMOGLOBIN A1C"
 I LOINC="17856-6" Q "HEMOGLOBIN A1C"
 I LOINC="17855-8" Q "HEMOGLOBIN A1C"
 I LOINC="4549-2" Q "HEMOGLOBIN A1C"
 Q ""
 ;
VALUE(ROOT,IEN,RIEN) ; $$ - result value
 N VAL,VTXT
 S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueQuantity","value"))
 I VAL'="" Q VAL
 S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueString"))
 I VAL'="" Q VAL
 S VTXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueCodeableConcept","text"))
 I VTXT'="" Q VTXT
 Q ""
 ;
HL7DT(ROOT,IEN,RIEN) ; $$ - compact HL7 date/time with required time component
 N DT,HL7
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","effectiveDateTime"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","issued"))
 S HL7=$$FHIRISO2HL7^C0FWFUTL(DT)
 I HL7="" Q ""
 I $L(HL7)=8 S HL7=HL7_"120000"
 I $L(HL7)'<14,$E(HL7,9,14)="000000" S HL7=$E(HL7,1,8)_"120000"
 Q HL7
 ;
LOCN(ROOT,IEN,RIEN) ; $$ - hospital location name for ISI LOCATION
 N LOC,LOCN,LOCIEN
 I $T(MAP^SYNQLDM)'="" S LOCN=$$MAP^SYNQLDM("OP","location") I LOCN'="",+LOCN'=-1,$O(^SC("B",LOCN,""))'="" Q LOCN
 S LOCIEN=$$LOC^C0FWVIT(ROOT,IEN,RIEN)
 I LOCIEN>0 S LOCN=$P($G(^SC(LOCIEN,0)),U) I LOCN'="" Q LOCN
 S LOCN="GENERAL MEDICINE"
 I $O(^SC("B",LOCN,""))'="" Q LOCN
 S LOC=$O(^SC(0))
 I LOC>0 Q $P($G(^SC(LOC,0)),U)
 Q ""
 ;
CSAMP(LOINC) ; $$ - collection sample name
 N CSAMP
 S CSAMP=""
 I $G(LOINC)'="",$D(^LAB(95.3)) D
 . S CSAMP=$$GET1^DIQ(95.3,$P(LOINC,"-",1),4)
 . I CSAMP["SER/PLAS" S CSAMP="SERUM" Q
 . I CSAMP["Whole blood"!(CSAMP["Blood venous")!(CSAMP["Blood arterial") S CSAMP="BLOOD" Q
 . I CSAMP["Urine" S CSAMP="URINE" Q
 . I CSAMP["plasma"!(CSAMP["Plasma") S CSAMP="PLASMA" Q
 I CSAMP="" S CSAMP="BLOOD"
 Q CSAMP
 ;
LOG(ROOT,IEN,RIEN,ICN,LOCN,TEST,VAL,HL7DT,LOINC,CSAMP,STATUS,RAW) ; Persist load details
 S @ROOT@(IEN,"load","Lab",RIEN,"engine")="SYN/ISI"
 S @ROOT@(IEN,"load","Lab",RIEN,"routine")="SYNDHP63"
 S @ROOT@(IEN,"load","Lab",RIEN,"entrypoint")="LABADD^SYNDHP63"
 S @ROOT@(IEN,"load","Lab",RIEN,"file")=63
 S @ROOT@(IEN,"load","Lab",RIEN,"icn")=$G(ICN)
 S @ROOT@(IEN,"load","Lab",RIEN,"location")=$G(LOCN)
 S @ROOT@(IEN,"load","Lab",RIEN,"test")=$G(TEST)
 S @ROOT@(IEN,"load","Lab",RIEN,"value")=$G(VAL)
 S @ROOT@(IEN,"load","Lab",RIEN,"hl7DateTime")=$G(HL7DT)
 S @ROOT@(IEN,"load","Lab",RIEN,"loinc")=$G(LOINC)
 S @ROOT@(IEN,"load","Lab",RIEN,"collectionSample")=$G(CSAMP)
 S @ROOT@(IEN,"load","Lab",RIEN,"rawStatus")=$G(RAW)
 S @ROOT@(IEN,"load","Lab",RIEN,"loadStatus")=$G(STATUS)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
