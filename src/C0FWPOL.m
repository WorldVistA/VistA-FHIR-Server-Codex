C0FWPOL ; VEHU/Codex - C0FW writeback policy ;May 13, 2026
 ;;0.1;C0FHIR PROJECT;;May 13, 2026
 ;
 Q
 ;
ENGINE(DOMAIN,ARGS) ; $$ - selected engine for one C0FW domain
 N ENG,PROF
 S DOMAIN=$G(DOMAIN)
 S PROF=$$PROFILE(.ARGS)
 S ENG=$$ARGENG(DOMAIN,.ARGS)
 I ENG'="" Q $$NORM(ENG)
 I ENG="" S ENG=$G(^C0FW("policy",DOMAIN))
 I PROF="rpms",$$RPMSDEF(DOMAIN) Q "off"
 I ENG="" S ENG=$$DEFAULT(DOMAIN,PROF)
 Q $$NORM(ENG)
 ;
DEFAULT(DOMAIN,PROF) ; $$ - conservative default engine
 I DOMAIN="Patient" Q "native"
 I DOMAIN="Encounter" Q "native"
 I DOMAIN="HealthFactor" Q "native"
 I DOMAIN="Observation" Q "native"
 I DOMAIN="Condition" Q "native"
 Q "native"
 ;
REASON(DOMAIN,ENG,ARGS) ; $$ - policy status message
 I $$NORM($G(ENG))'="off" Q ""
 I $$PROFILE(.ARGS)="rpms",$$RPMSDEF($G(DOMAIN)) Q "RPMS first-pass policy skipped "_$G(DOMAIN)_" filing; domain is deferred until a native RPMS adapter is proven safe."
 Q "C0FW policy skipped domain"
 ;
PROFILE(ARGS) ; $$ - active C0FW target profile
 N PROF
 S PROF=$$ARGPROF(.ARGS)
 I PROF'="" Q PROF
 I $$ISRPMS() Q "rpms"
 Q "vista"
 ;
ARGPROF(ARGS) ; $$ - request override for focused policy tests
 N PROF
 S PROF=$G(ARGS("profile"))
 I PROF="" S PROF=$G(ARGS("c0fwProfile"))
 I PROF="" S PROF=$G(ARGS("targetProfile"))
 S PROF=$$LOW(PROF)
 I PROF="rpms" Q "rpms"
 I PROF="vista" Q "vista"
 Q ""
 ;
ISRPMS() ; $$ - detect RPMS by package capabilities, not host/container name
 I '$D(^AUPNPAT(0)) Q 0
 I '$D(^DD(9000001,0)) Q 0
 I $T(+0^APCDALV)'="" Q 1
 I $D(^AUPNVSIT(0)),$D(^DD(9000010,0)),$D(^AUTTLOC(0)) Q 1
 Q 0
 ;
RPMSDEF(DOMAIN) ; $$ - RPMS first-pass deferred domains
 S DOMAIN=$G(DOMAIN)
 I DOMAIN="Condition" Q 1
 I DOMAIN="Lab" Q 1
 I DOMAIN="Medication" Q 1
 I DOMAIN="Procedure" Q 1
 I DOMAIN="Appointment" Q 1
 I DOMAIN="CarePlan" Q 1
 I DOMAIN="Allergy" Q 1
 I DOMAIN="Immunization" Q 1
 Q 0
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
