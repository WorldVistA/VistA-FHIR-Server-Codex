C0FWVIT ; VEHU/Codex - C0FW vital writeback ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR Observation vital sign
 N DFN,ENT,FMDT,INVAR,LOC,OBS,OUT,TYPE,VAL,WHY
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D STATUS(ROOT,IEN,RIEN,"skipped","No DFN linked to graph row",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="Observation" D STATUS(ROOT,IEN,RIEN,"skipped","Resource is not Observation",.RETURN) Q
 I '$$ISVITAL(ROOT,IEN,RIEN) D STATUS(ROOT,IEN,RIEN,"skipped","Observation is not a vital-signs resource",.RETURN) Q
 S TYPE=$$TYPE(ROOT,IEN,RIEN,.WHY)
 I TYPE<1 D STATUS(ROOT,IEN,RIEN,"skipped",$G(WHY,"Unable to map vital type"),.RETURN) Q
 S VAL=$$VALUE(ROOT,IEN,RIEN,TYPE,.WHY)
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
ISVITAL(ROOT,IEN,RIEN) ; $$ - true if Observation should be treated as vital
 N CAT,CODE
 S CAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",1,"coding",1,"code"))
 I CAT="vital-signs" Q 1
 S CODE=$$CODE(ROOT,IEN,RIEN)
 Q $S($$TYPECODE(CODE)>0:1,1:0)
 ;
TYPE(ROOT,IEN,RIEN,WHY) ; $$ - VistA vital type ien
 N CODE,TXT,TYPE
 S CODE=$$CODE(ROOT,IEN,RIEN)
 S TYPE=$$TYPECODE(CODE)
 I TYPE>0 Q TYPE
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 S TYPE=$$TYPENAME(TXT)
 I TYPE>0 Q TYPE
 S WHY="Unsupported vital code/display: "_CODE_" "_TXT
 Q 0
 ;
TYPECODE(CODE) ; $$ - LOINC/SNOMED to VistA vital type ien
 S CODE=$G(CODE)
 I CODE="55284-4" Q $$VTIEN("BP")
 I CODE="85354-9" Q $$VTIEN("BP")
 I CODE="8480-6" Q $$VTIEN("BP")
 I CODE="8462-4" Q $$VTIEN("BP")
 I CODE="8867-4" Q $$VTIEN("P")
 I CODE="9279-1" Q $$VTIEN("R")
 I CODE="8302-2" Q $$VTIEN("HT")
 I CODE="29463-7" Q $$VTIEN("WT")
 I CODE="8331-1" Q $$VTIEN("T")
 I CODE="8310-5" Q $$VTIEN("T")
 I CODE="59408-5" Q $$VTIEN("PO2")
 I CODE="2708-6" Q $$VTIEN("PO2")
 I CODE="72514-3" Q $$VTIEN("PN")
 I CODE=27113001 Q $$VTIEN("WT")
 I CODE=50373000 Q $$VTIEN("HT")
 I CODE=75367002 Q $$VTIEN("BP")
 I CODE=78564009 Q $$VTIEN("P")
 I CODE=386725007 Q $$VTIEN("T")
 I CODE=86290005 Q $$VTIEN("R")
 I CODE=252465000 Q $$VTIEN("PO2")
 I CODE=22253000 Q $$VTIEN("PN")
 Q 0
 ;
TYPENAME(TXT) ; $$ - display/text to VistA vital type ien
 N X
 S X=$$UP($G(TXT))
 I X["BLOOD"&(X["PRESSURE") Q $$VTIEN("BP")
 I X["PULSE" Q $$VTIEN("P")
 I X["HEART RATE" Q $$VTIEN("P")
 I X["RESP" Q $$VTIEN("R")
 I X["HEIGHT" Q $$VTIEN("HT")
 I X["WEIGHT" Q $$VTIEN("WT")
 I X["TEMP" Q $$VTIEN("T")
 I X["OXIM" Q $$VTIEN("PO2")
 I X["PAIN" Q $$VTIEN("PN")
 Q 0
 ;
VTIEN(ABBR) ; $$ - vital type ien from abbreviation or name index
 N IEN
 S ABBR=$G(ABBR)
 S IEN=$O(^GMRD(120.51,"C",ABBR,0))
 I IEN>0 Q IEN
 S IEN=$O(^GMRD(120.51,"B",ABBR,0))
 Q +IEN
 ;
CODE(ROOT,IEN,RIEN) ; $$ - first Observation code
 Q $G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 ;
VALUE(ROOT,IEN,RIEN,TYPE,WHY) ; $$ - vital value string
 N DIA,SYS,VAL
 I +$G(TYPE)=$$VTIEN("BP") D  Q VAL
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
