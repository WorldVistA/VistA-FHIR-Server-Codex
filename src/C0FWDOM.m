C0FWDOM ; VEHU/Codex - C0FW update domain dispatcher ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(RETURN,IEN,ARGS) ; Process appended update resources without SYNF/ISI importers
 N ROOT,BUNDLE,RIEN,TYPE,DOMAIN,COUNT,FIRST,LAST
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 S BUNDLE=$G(ARGS("bundle"))
 S FIRST=+$G(ARGS("firstEntry"))
 S LAST=+$G(ARGS("lastEntry"))
 S COUNT=0
 S RIEN=$S(FIRST>0:FIRST-1,1:0)
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  Q:(LAST>0)&(RIEN>LAST)  D
 . I BUNDLE'="",$G(@ROOT@(IEN,"json","entry",RIEN,"bundle"))'=BUNDLE Q
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S DOMAIN=$$DOMAIN(TYPE)
 . Q:DOMAIN=""
 . S COUNT=COUNT+1
 . I DOMAIN="Observation" D LOAD^C0FWVIT(ROOT,IEN,RIEN,.RETURN) Q
 . D NOTIMPL(ROOT,IEN,RIEN,DOMAIN,TYPE,.RETURN)
 S RETURN("loadStatus")=$$SUMMARY(.RETURN,COUNT)
 S RETURN("load","engine")="C0FW"
 S RETURN("load","clinicalFiling")=$S($G(RETURN("loadStatus"))="loaded":"partial",1:$G(RETURN("loadStatus")))
 Q
 ;
DOMAIN(TYPE) ; $$ - map FHIR resourceType to C0FW domain
 S TYPE=$G(TYPE)
 I TYPE="Observation" Q "Observation"
 I TYPE="Encounter" Q "Encounter"
 I TYPE="Condition" Q "Condition"
 I TYPE="DocumentReference" Q "DocumentReference"
 I TYPE="Immunization" Q "Immunization"
 I TYPE="AllergyIntolerance" Q "Allergy"
 I TYPE="MedicationRequest" Q "Medication"
 I TYPE="Medication" Q "Medication"
 I TYPE="Procedure" Q "Procedure"
 I TYPE="CarePlan" Q "CarePlan"
 I TYPE="Appointment" Q "Appointment"
 Q ""
 ;
NOTIMPL(ROOT,IEN,RIEN,DOMAIN,TYPE,RETURN) ; Record deterministic domain status
 N MSG
 S MSG="C0FW "_DOMAIN_" clinical filing is not implemented; SYNF/ISI importers are intentionally not called."
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"loadStatus")="not_implemented"
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"resourceType")=$G(TYPE)
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"message")=MSG
 S RETURN("domains",DOMAIN,"status")="not_implemented"
 S RETURN("domains",DOMAIN,"message")=MSG
 S RETURN("domains",DOMAIN,"entries",RIEN)="not_implemented"
 Q
 ;
SUMMARY(RETURN,COUNT) ; $$ - overall load summary
 N DOM,LOADED,NOTIMP,ERROR
 I +$G(COUNT)<1 Q "no_applicable_resources"
 S (LOADED,NOTIMP,ERROR)=0
 S DOM=""
 F  S DOM=$O(RETURN("domains",DOM)) Q:DOM=""  D
 . I $G(RETURN("domains",DOM,"status"))="loaded" S LOADED=1
 . I $G(RETURN("domains",DOM,"status"))="not_implemented" S NOTIMP=1
 . I $G(RETURN("domains",DOM,"status"))="error" S ERROR=1
 I ERROR Q "error"
 I LOADED,NOTIMP Q "partial"
 I LOADED Q "loaded"
 I NOTIMP Q "not_implemented"
 Q "skipped"
 ;
