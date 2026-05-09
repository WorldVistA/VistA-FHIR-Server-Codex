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
 ; Encounters are filed first so later domains can resolve a visit pointer.
 S RIEN=$S(FIRST>0:FIRST-1,1:0)
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  Q:(LAST>0)&(RIEN>LAST)  D
 . I '$$INBUND(ROOT,IEN,RIEN,BUNDLE) Q
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S DOMAIN=$$DOMAIN(ROOT,IEN,RIEN,TYPE)
 . Q:DOMAIN'="Encounter"
 . S COUNT=COUNT+1
 . D LOAD^C0FWENC(ROOT,IEN,RIEN,.RETURN)
 . D LOADENC^C0FWTIU(ROOT,IEN,RIEN,.RETURN)
 S RIEN=$S(FIRST>0:FIRST-1,1:0)
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  Q:(LAST>0)&(RIEN>LAST)  D
 . I '$$INBUND(ROOT,IEN,RIEN,BUNDLE) Q
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S DOMAIN=$$DOMAIN(ROOT,IEN,RIEN,TYPE)
 . Q:DOMAIN=""
 . Q:DOMAIN="Encounter"
 . S COUNT=COUNT+1
 . I DOMAIN="Observation" D LOAD^C0FWVIT(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Lab" D LOAD^C0FWLAB(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Condition" D LOAD^C0FWCON(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="DocumentReference" D LOAD^C0FWTIU(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Immunization" D LOAD^C0FWIMM(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Allergy" D LOAD^C0FWALG(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Medication" D LOAD^C0FWMED(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Procedure" D LOAD^C0FWPRC(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="CarePlan" D LOAD^C0FWCP(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Appointment" D LOAD^C0FWAPT(ROOT,IEN,RIEN,.RETURN) Q
 . D NI^C0FWSTAT(ROOT,IEN,RIEN,DOMAIN,TYPE,"No C0FW domain adapter selected",.RETURN)
 S RETURN("loadStatus")=$$SUMMARY(.RETURN,COUNT)
 S RETURN("load","engine")="C0FW"
 S RETURN("load","clinicalFiling")=$S($G(RETURN("loadStatus"))="loaded":"partial",1:$G(RETURN("loadStatus")))
 Q
 ;
DOMAIN(ROOT,IEN,RIEN,TYPE) ; $$ - map FHIR resourceType to C0FW domain
 S TYPE=$G(TYPE)
 I TYPE="Observation" Q $S($$ISVITAL^C0FWVIT(ROOT,IEN,RIEN):"Observation",1:"Lab")
 I TYPE="DiagnosticReport" Q "Lab"
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
INBUND(ROOT,IEN,RIEN,BUNDLE) ; $$ - true if entry belongs to requested bundle
 I $G(BUNDLE)="" Q 1
 I $G(@ROOT@(IEN,RIEN,"bundle"))=$G(BUNDLE) Q 1
 I $G(@ROOT@(IEN,"json","entry",RIEN,"bundle"))=$G(BUNDLE) Q 1
 Q 0
 ;
