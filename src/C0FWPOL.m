C0FWPOL ; VEHU/Codex - C0FW writeback policy ;May 13, 2026
 ;;0.1;C0FHIR PROJECT;;May 13, 2026
 ;
 Q
 ;
ENGINE(DOMAIN,ARGS) ; $$ - selected engine for one C0FW domain
 N ENG
 S DOMAIN=$G(DOMAIN)
 S ENG=$$ARGENG(DOMAIN,.ARGS)
 I ENG="" S ENG=$G(^C0FW("policy",DOMAIN))
 I ENG="" S ENG=$$DEFAULT(DOMAIN)
 Q $$NORM(ENG)
 ;
DEFAULT(DOMAIN) ; $$ - conservative default engine
 I DOMAIN="Patient" Q "native"
 I DOMAIN="Encounter" Q "native"
 I DOMAIN="HealthFactor" Q "native"
 I DOMAIN="Observation" Q "native"
 I DOMAIN="Condition" Q "native"
 Q "native"
 ;
ARGENG(DOMAIN,ARGS) ; $$ - request override for controlled tests
 N KEY,LOW
 S LOW=$$LOW(DOMAIN)
 S KEY="engine."_DOMAIN
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 S KEY="engine."_LOW
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 S KEY="engine"_DOMAIN
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 S KEY="engine"_LOW
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 S KEY="engine-"_DOMAIN
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 S KEY="engine-"_LOW
 I $G(ARGS(KEY))'="" Q $G(ARGS(KEY))
 I $G(ARGS("engine",DOMAIN))'="" Q $G(ARGS("engine",DOMAIN))
 I $G(ARGS("engine",LOW))'="" Q $G(ARGS("engine",LOW))
 Q ""
 ;
NORM(ENG) ; $$ - normalize policy value
 S ENG=$$UP($G(ENG))
 I ENG="NATIVE" Q "native"
 I ENG="SYN" Q "syn"
 I ENG="ISI" Q "isi"
 I ENG="AUTO" Q "auto"
 I ENG="OFF" Q "off"
 Q "native"
 ;
CAP(DOMAIN,ENG) ; $$ - true if requested engine is available
 S DOMAIN=$G(DOMAIN),ENG=$$NORM($G(ENG))
 I ENG="native" Q 1
 I ENG="off" Q 1
 I ENG="auto" Q 1
 I ENG="syn",DOMAIN="HealthFactor" Q $S($T(GETHF^SYNFHF)'="":1,1:0)
 Q 0
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
LOW(X) ; $$ - lowercase
 Q $TR($G(X),"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")
 ;
