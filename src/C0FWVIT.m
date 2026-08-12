C0FWVIT ; VEHU/Codex - C0FW vital writeback ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Observation vital sign
 N ABBR,DFN,ENT,FMDT,INVAR,LOC,OBS,OUT,TYPE,VAL,WHY
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D STATUS(ROOT,IEN,RIEN,"skipped","No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Observation" D STATUS(ROOT,IEN,RIEN,"skipped","Resource is not Observation",.RETURN) Q
 I '$$ISVITAL(ROOT,IEN,RIEN) D STATUS(ROOT,IEN,RIEN,"skipped","Observation is not a vital-signs resource",.RETURN) Q
 S ABBR=$$ABBR(ROOT,IEN,RIEN,.WHY)
 I ABBR="" D STATUS(ROOT,IEN,RIEN,"skipped",$G(WHY,"Unable to map vital type"),.RETURN) Q
 I $$RPMS() D RPMSLOAD(ROOT,IEN,RIEN,DFN,ABBR,.RETURN) Q
 S TYPE=$$VTIEN(ABBR)
 I TYPE<1 D STATUS(ROOT,IEN,RIEN,"skipped",$G(WHY,"Unable to map vital type"),.RETURN) Q
 S VAL=$$VALUE(ROOT,IEN,RIEN,ABBR,.WHY)
 I VAL="" D STATUS(ROOT,IEN,RIEN,"error",$G(WHY,"Missing vital value"),.RETURN) Q
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 I FMDT<1 D STATUS(ROOT,IEN,RIEN,"error","Missing or invalid effectiveDateTime",.RETURN) Q
 S LOC=$$LOC(ROOT,IEN,RIEN)
 I LOC<1 D STATUS(ROOT,IEN,RIEN,"error","Unable to resolve hospital location",.RETURN) Q
 S ENT=$$DUZ^C0FWCTX()
 S INVAR=FMDT_U_DFN_U_TYPE_";"_VAL_";"_U_LOC_U_ENT
 D EN1^GMVDCSAV(.OUT,INVAR)
 I $G(OUT(0))["ERROR" D STATUS(ROOT,IEN,RIEN,"error","GMVDCSAV failed: "_$G(OUT(0)),.RETURN) Q
 D STATUS(ROOT,IEN,RIEN,"loaded","Vital sign filed through GMVDCSAV",.RETURN)
 S @ROOT@(IEN,"load","Observation",RIEN,"file")=120.5
 S @ROOT@(IEN,"load","Observation",RIEN,"vitalType")=TYPE
 S @ROOT@(IEN,"load","Observation",RIEN,"value")=VAL
 S @ROOT@(IEN,"load","Observation",RIEN,"dateTime")=FMDT
 S @ROOT@(IEN,"load","Observation",RIEN,"location")=LOC
 Q
 ;
RPMS() ; $$ - true when RPMS PCC measurements are available
 I '$D(^AUPNVMSR(0)) Q 0
 I '$D(^DD(9000010.01,0)) Q 0
 I '$D(^AUTTMSR(0)) Q 0
 Q 1
 ;
GETRMSR(RTN,DFN,BEG,END,MAX) ; Add RPMS V MEASUREMENT resources
 ; Walk newest-first: AC is ascending by IEN; large patients hit MAX on old vitals
 ; and omit Quality AI Consult / recent writebacks (e.g. DFN 55 BP IEN 116851).
 N CNT,DATE,IEN,VIT
 S CNT=0,IEN=""
 F  S IEN=$O(^AUPNVMSR("AC",+$G(DFN),IEN),-1) Q:IEN<1!(CNT'<MAX)  D
 . S DATE=$$MSRDT(IEN)
 . I (DATE<BEG)!(DATE>END) Q
 . K VIT
 . D MSRVIT(IEN,.VIT)
 . I '$D(VIT) Q
 . D SETOBS^C0FHIRD(.RTN,.VIT,DFN)
 . S CNT=CNT+1
 Q
 ;
MSRVIT(IEN,VIT) ; Build a VPR-like vital array from RPMS V MEASUREMENT
 N ABBR,DATE,NAME,NODE0,RES,TYPE,UNIT
 S NODE0=$G(^AUPNVMSR(IEN,0))
 S TYPE=+$P(NODE0,U,1)
 I TYPE<1 Q
 S RES=$P(NODE0,U,4)
 I RES="" Q
 S NAME=$P($G(^AUTTMSR(TYPE,0)),U,2)
 I NAME="" S NAME=$P($G(^AUTTMSR(TYPE,0)),U)
 S ABBR=$P($G(^AUTTMSR(TYPE,0)),U)
 S UNIT=$$MSRUNIT(ABBR)
 S VIT("measurement",1)=IEN_"^^"_NAME_"^"_RES_"^"_UNIT_"^"_RES_"^"_UNIT
 S DATE=$$MSRDT(IEN)
 I DATE>0 S VIT("taken")=DATE
 Q
 ;
MSRDT(IEN) ; $$ - observation date for RPMS V MEASUREMENT
 N DATE,VISIT
 S DATE=+$P($G(^AUPNVMSR(IEN,12)),U,1)
 I DATE>0 Q DATE
 S VISIT=+$P($G(^AUPNVMSR(IEN,0)),U,3)
 I VISIT>0 Q +$G(^AUPNVSIT(VISIT,0))
 Q 0
 ;
MSRUNIT(ABBR) ; $$ - common UCUM-ish unit by RPMS measurement abbreviation
 S ABBR=$G(ABBR)
 I ABBR="WT" Q "lb"
 I ABBR="HT" Q "in"
 I ABBR="TMP" Q "degF"
 I ABBR="BP" Q "mm[Hg]"
 I ABBR="O2" Q "%"
 I ABBR="PA" Q "{score}"
 Q ""
 ;
RPMSLOAD(ROOT,IEN,RIEN,DFN,ABBR,RETURN) ; File one RPMS V MEASUREMENT
 N CLIN,ENT,ERR,FDA,FMDT,LOC,MSR,MSG,UNIT,VAL,VISIT
 S MSR=$$MSRIEN(ABBR)
 I MSR<1 D STATUS(ROOT,IEN,RIEN,"skipped","Unable to map RPMS measurement type: "_$G(ABBR),.RETURN) Q
 S VAL=$$VALUE(ROOT,IEN,RIEN,ABBR,.ERR)
 I VAL="" D STATUS(ROOT,IEN,RIEN,"error",$G(ERR,"Missing vital value"),.RETURN) Q
 S UNIT=$$UNIT(ROOT,IEN,RIEN)
 S VAL=$$CNV(ABBR,VAL,UNIT)
 S FMDT=$$FMDT(ROOT,IEN,RIEN)
 I FMDT<1 D STATUS(ROOT,IEN,RIEN,"error","Missing or invalid effectiveDateTime",.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D STATUS(ROOT,IEN,RIEN,"error","Observation has no resolved RPMS visit pointer",.RETURN) Q
 I $$HASMSR(DFN,VISIT,MSR,FMDT,VAL) D  Q
 . D STATUS(ROOT,IEN,RIEN,"skipped","Vital sign already filed as RPMS V MEASUREMENT",.RETURN)
 . S @ROOT@(IEN,"load","Observation",RIEN,"file")=9000010.01
 . S @ROOT@(IEN,"load","Observation",RIEN,"vitalType")=MSR
 . S @ROOT@(IEN,"load","Observation",RIEN,"value")=VAL
 . S @ROOT@(IEN,"load","Observation",RIEN,"dateTime")=FMDT
 . S @ROOT@(IEN,"load","Observation",RIEN,"visitIen")=VISIT
 S LOC=$$LOC(ROOT,IEN,RIEN)
 I LOC<1 D STATUS(ROOT,IEN,RIEN,"error","Unable to resolve hospital location",.RETURN) Q
 S CLIN=$$CLINIC(LOC)
 S ENT=$$DUZ^C0FWCTX()
 K FDA,MSG
 S FDA(9000010.01,"+1,",.01)=MSR
 S FDA(9000010.01,"+1,",.02)=DFN
 S FDA(9000010.01,"+1,",.03)=VISIT
 S FDA(9000010.01,"+1,",.04)=VAL
 S FDA(9000010.01,"+1,",.07)=FMDT
 S FDA(9000010.01,"+1,",1201)=FMDT
 I CLIN>0 S FDA(9000010.01,"+1,",1203)=CLIN
 S FDA(9000010.01,"+1,",1217)=ENT
 D UPDATE^DIE("","FDA","","MSG")
 I $D(MSG) D STATUS(ROOT,IEN,RIEN,"error","Problem saving RPMS V MEASUREMENT: "_$G(MSG("DIERR",1,"TEXT",1)),.RETURN) Q
 D STATUS(ROOT,IEN,RIEN,"loaded","Vital sign filed as RPMS V MEASUREMENT",.RETURN)
 S @ROOT@(IEN,"load","Observation",RIEN,"file")=9000010.01
 S @ROOT@(IEN,"load","Observation",RIEN,"vitalType")=MSR
 S @ROOT@(IEN,"load","Observation",RIEN,"value")=VAL
 S @ROOT@(IEN,"load","Observation",RIEN,"dateTime")=FMDT
 S @ROOT@(IEN,"load","Observation",RIEN,"location")=LOC
 S @ROOT@(IEN,"load","Observation",RIEN,"visitIen")=VISIT
 Q
 ;
ISVITAL(ROOT,IEN,RIEN) ; $$ - true if Observation should be treated as vital
 N CAT,CODE
 S CAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",1,"coding",1,"code"))
 I CAT="vital-signs" Q 1
 S CODE=$$CODE(ROOT,IEN,RIEN)
 Q $S($$ABBRCD(CODE)'="":1,1:0)
 ;
ABBR(ROOT,IEN,RIEN,WHY) ; $$ - canonical vital abbreviation
 N ABBR,CODE,TXT
 S CODE=$$CODE(ROOT,IEN,RIEN)
 S ABBR=$$ABBRCD(CODE)
 I ABBR'="" Q ABBR
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 S ABBR=$$ABBRNM(TXT)
 I ABBR'="" Q ABBR
 S WHY="Unsupported vital code/display: "_CODE_" "_TXT
 Q ""
 ;
ABBRCD(CODE) ; $$ - LOINC/SNOMED to vital abbreviation
 S CODE=$G(CODE)
 I CODE="55284-4" Q "BP"
 I CODE="85354-9" Q "BP"
 I CODE="8480-6" Q "BP"
 I CODE="8462-4" Q "BP"
 I CODE="8867-4" Q "P"
 I CODE="9279-1" Q "R"
 I CODE="8302-2" Q "HT"
 I CODE="29463-7" Q "WT"
 I CODE="8331-1" Q "T"
 I CODE="8310-5" Q "T"
 I CODE="59408-5" Q "PO2"
 I CODE="2708-6" Q "PO2"
 I CODE="72514-3" Q "PN"
 I CODE=27113001 Q "WT"
 I CODE=50373000 Q "HT"
 I CODE=75367002 Q "BP"
 I CODE=78564009 Q "P"
 I CODE=386725007 Q "T"
 I CODE=86290005 Q "R"
 I CODE=252465000 Q "PO2"
 I CODE=22253000 Q "PN"
 Q ""
 ;
ABBRNM(TXT) ; $$ - display/text to vital abbreviation
 N X
 S X=$$UP($G(TXT))
 I X["BLOOD"&(X["PRESSURE") Q "BP"
 I X["PULSE" Q "P"
 I X["HEART RATE" Q "P"
 I X["RESP" Q "R"
 I X["HEIGHT" Q "HT"
 I X["WEIGHT" Q "WT"
 I X["TEMP" Q "T"
 I X["OXIM" Q "PO2"
 I X["PAIN" Q "PN"
 Q ""
 ;
VTIEN(ABBR) ; $$ - vital type ien from abbreviation or name index
 N IEN
 S ABBR=$G(ABBR)
 S IEN=$O(^GMRD(120.51,"C",ABBR,0))
 I IEN>0 Q IEN
 S IEN=$O(^GMRD(120.51,"B",ABBR,0))
 Q +IEN
 ;
MSRIEN(ABBR) ; $$ - RPMS V MEASUREMENT type ien from abbreviation
 N RABBR
 S RABBR=$S($G(ABBR)="P":"PU",$G(ABBR)="T":"TMP",$G(ABBR)="R":"RS",$G(ABBR)="PO2":"O2",$G(ABBR)="PN":"PA",1:$G(ABBR))
 Q +$O(^AUTTMSR("B",RABBR,0))
 ;
HASMSR(DFN,VISIT,MSR,FMDT,VAL) ; $$ - true if matching RPMS V MEASUREMENT exists
 N FOUND,IEN,NODE0,WHEN
 S IEN=0
 F  S IEN=$O(^AUPNVMSR("AD",+$G(VISIT),IEN)) Q:IEN<1  D  Q:$G(FOUND)
 . S NODE0=$G(^AUPNVMSR(IEN,0))
 . Q:+$P(NODE0,U)'=+$G(MSR)
 . Q:+$P(NODE0,U,2)'=+$G(DFN)
 . Q:$P(NODE0,U,4)'=$G(VAL)
 . S WHEN=$$MSRDT(IEN)
 . I +WHEN=+$G(FMDT) S FOUND=1
 Q +$G(FOUND)
 ;
CODE(ROOT,IEN,RIEN) ; $$ - first Observation code
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 ;
VALUE(ROOT,IEN,RIEN,TYPE,WHY) ; $$ - vital value string
 N DIA,SYS,VAL
 I $G(TYPE)="BP" D  Q VAL
 . S SYS=$$COMP(ROOT,IEN,RIEN,"8480-6")
 . S DIA=$$COMP(ROOT,IEN,RIEN,"8462-4")
 . I SYS'="",DIA'="" S VAL=SYS_"/"_DIA Q
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueString"))
 . I VAL="" S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueQuantity","value"))
 . I VAL="" S WHY="Missing blood pressure systolic/diastolic values"
 S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueQuantity","value"))
 I VAL="" S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueString"))
 I VAL="" S WHY="Missing vital value"
 Q VAL
 ;
UNIT(ROOT,IEN,RIEN) ; $$ - vital value unit
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueQuantity","unit"))
 ;
CNV(ABBR,VAL,UNIT) ; $$ - convert common SI units to RPMS display units
 N U
 S U=$$UP($G(UNIT))
 I $G(ABBR)="WT",U="KG" Q $J(VAL*2.20462,0,1)
 I $G(ABBR)="HT",U="CM" Q $J(VAL*.393701,0,0)
 I $G(ABBR)="T",(U="CEL"!(U="C")) Q $J(VAL/5*9+32,0,1)
 Q $G(VAL)
 ;
COMP(ROOT,IEN,RIEN,CODE) ; $$ - component value by code
 N N,VAL
 S N=0
 F  S N=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","component",N)) Q:+N=0  D  Q:$G(VAL)'=""
 . I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","component",N,"code","coding",1,"code"))'=CODE Q
 . S VAL=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","component",N,"valueQuantity","value"))
 Q $G(VAL)
 ;
FMDT(ROOT,IEN,RIEN) ; $$ - effective date/time as FileMan
 N DT
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","effectiveDateTime"))
 Q $$FHIRTFM^C0FWFUTL(DT)
 ;
LOC(ROOT,IEN,RIEN) ; $$ - hospital location
 N ENC,LOC
 S LOC=+$G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension","location"))
 I LOC>0 Q LOC
 S ENC=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 S ENC=+$P($P(ENC,"/",2),";")
 I ENC>0 S LOC=+$P($G(^AUPNVSIT(ENC,0)),U,22) I LOC>0 Q LOC
 S LOC=$O(^SC(0))
 Q +LOC
 ;
CLINIC(LOC) ; $$ - RPMS clinic stop-code pointer for field 1203
 N CLIN
 S CLIN=+$P($G(^SC(+$G(LOC),0)),U,7)
 I CLIN>0,$D(^DIC(40.7,CLIN,0)) Q CLIN
 S CLIN=$O(^DIC(40.7,"C",28,0))
 I CLIN>0 Q CLIN
 Q +$O(^DIC(40.7,0))
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - resolved Encounter visit ien
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 Q +VISIT
 ;
STATUS(ROOT,IEN,RIEN,STATUS,MSG,RETURN) ; Record load status
 S @ROOT@(IEN,"load","Observation",RIEN,"loadStatus")=$G(STATUS)
 S @ROOT@(IEN,"load","Observation",RIEN,"resourceType")="Observation"
 S @ROOT@(IEN,"load","Observation",RIEN,"message")=$G(MSG)
 S RETURN("domains","Observation","status")=$G(STATUS)
 S RETURN("domains","Observation","message")=$G(MSG)
 S RETURN("domains","Observation","entries",RIEN)=$G(STATUS)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
