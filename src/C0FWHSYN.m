C0FWHSYN ; VEHU/Codex - SYN Health Factor policy wrapper ;May 13, 2026
 ;;0.1;C0FHIR PROJECT;;May 13, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Resolve Encounter Health Factors through SYNFHF
 N CNT,EI,MSG,TYPE
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE'="Encounter" D NI^C0FWSTAT(ROOT,IEN,RIEN,"HealthFactor",TYPE,"SYN Health Factor wrapper only accepts Encounter resources",.RETURN) Q
 I $T(GETHF^SYNFHF)="" D NI^C0FWSTAT(ROOT,IEN,RIEN,"HealthFactor",TYPE,"SYNFHF is not installed",.RETURN) Q
 S (CNT,EI)=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  D
 . I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))'=$$HFURL^C0FWENC() Q
 . D ONE(ROOT,IEN,RIEN,EI,.CNT)
 I CNT<1 D NI^C0FWSTAT(ROOT,IEN,RIEN,"HealthFactor",TYPE,"Encounter has no C0FW Health Factor extensions",.RETURN) Q
 S MSG="SYNFHF resolved "_CNT_" Encounter Health Factor extension(s); native Encounter filing owns V Health Factor rows"
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"HealthFactor",TYPE,"loaded",MSG,.RETURN)
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"engine")="SYN"
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"routine")="SYNFHF"
 Q
 ;
ONE(ROOT,IEN,RIEN,EI,CNT) ; Resolve one extension to ^AUTTHF
 N CODE,IENHF,NAME,RET,SYS,TEXT
 S NAME=$$EXTVAL^C0FWENC(ROOT,IEN,RIEN,EI,"name")
 S CODE=$$EXTVAL^C0FWENC(ROOT,IEN,RIEN,EI,"code")
 S SYS=$$EXTVAL^C0FWENC(ROOT,IEN,RIEN,EI,"system")
 S TEXT=$S(NAME'="":NAME,CODE'="":CODE,1:"")
 I TEXT="" D STAT(ROOT,IEN,RIEN,EI,"skipped","Health Factor extension missing name/code") Q
 I CODE'="",SYS'="" S CODE=SYS_":"_CODE
 S RET=$$GETHF^SYNFHF("HF","",CODE,TEXT,0,"C0FW Health Factor",1)
 S IENHF=+RET
 I IENHF<1 D STAT(ROOT,IEN,RIEN,EI,"error",$P(RET,"^",2,99)) Q
 S CNT=$G(CNT)+1
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"healthFactor",EI,"ien")=IENHF
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"healthFactor",EI,"name")=$P(RET,"^",2)
 D STAT(ROOT,IEN,RIEN,EI,"loaded","SYNFHF resolved Health Factor: "_$P(RET,"^",2))
 Q
 ;
STAT(ROOT,IEN,RIEN,EI,STATUS,MSG) ; Extension status
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"healthFactor",EI,"status")=$G(STATUS)
 S @ROOT@(IEN,"load","HealthFactor",RIEN,"healthFactor",EI,"message")=$G(MSG)
 Q
 ;
