C0FWDOM ; VEHU/Codex - C0FW update domain dispatcher ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(RETURN,IEN,ARGS) ; Process appended update resources through C0FW policy
 ; Loop-control vars are C0FW-namespaced: Kernel code reached via the
 ; domain filers (PSO/TIU/PCE) can KILL common names like LAST without
 ; NEWing them (seen: %YDB-E-LVUNDEF on LAST mid-bundle via LOAD^C0FWMED).
 N ROOT,BUNDLE,RIEN,TYPE,DOMAIN,COUNT,C0FWFST,C0FWLST
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 D DEPCHK(ROOT,IEN,.RETURN)
 S BUNDLE=$G(ARGS("bundle"))
 S C0FWFST=+$G(ARGS("firstEntry"))
 S C0FWLST=+$G(ARGS("lastEntry"))
 S COUNT=0
 ; Encounters are filed first so later domains can resolve a visit pointer.
 ; Notes/TIU filing is visit-linked; C0FWTIU will skip/error until the visit resolves.
 S RIEN=$S(C0FWFST>0:C0FWFST-1,1:0)
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  Q:(C0FWLST>0)&(RIEN>C0FWLST)  D
 . I '$$INBUND(ROOT,IEN,RIEN,BUNDLE) Q
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S DOMAIN=$$DOMAIN(ROOT,IEN,RIEN,TYPE)
 . Q:DOMAIN'="Encounter"
 . S COUNT=COUNT+1
 . D DISPATCH(ROOT,IEN,RIEN,DOMAIN,TYPE,.ARGS,.RETURN)
 . D PERSIST(ROOT,IEN,RIEN,"Encounter",.RETURN)
 . D LOADENC^C0FWTIU(ROOT,IEN,RIEN,.RETURN)
 S RIEN=$S(C0FWFST>0:C0FWFST-1,1:0)
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0  Q:(C0FWLST>0)&(RIEN>C0FWLST)  D
 . I '$$INBUND(ROOT,IEN,RIEN,BUNDLE) Q
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S DOMAIN=$$DOMAIN(ROOT,IEN,RIEN,TYPE)
 . Q:DOMAIN=""
 . Q:DOMAIN="Encounter"
 . S COUNT=COUNT+1
 . D DISPATCH(ROOT,IEN,RIEN,DOMAIN,TYPE,.ARGS,.RETURN)
 S RETURN("loadStatus")=$$SUMMARY(.RETURN,COUNT)
 S RETURN("load","engine")="C0FW"
 S RETURN("load","profile")=$$PROFILE^C0FWPOL(.ARGS)
 S RETURN("load","clinicalFiling")=$S($G(RETURN("loadStatus"))="loaded":"partial",1:$G(RETURN("loadStatus")))
 I $T(INV^C0FWCAC)'="" D INV^C0FWCAC(IEN,ROOT)
 Q
 ;
DEPCHK(ROOT,IEN,RETURN) ; Surface missing filer routines once, up front
 ; The per-domain filers each guard their own dependency and skip resource-by-
 ; resource, so a missing routine drowns in thousands of per-resource rows
 ; (IRIS 2026-09-10: 4,162 of 4,834 losses were four uninstalled SYN routines).
 ; This puts one loud line per missing routine into the load response and the
 ; graph load log BEFORE filing starts. Advisory only — filing proceeds and
 ; the per-resource guards still record exact skips.
 N C0FDEP,C0FI,C0FRTN,C0FMSG,C0FN,C0FX
 S C0FDEP(1)="SYNWEBUT^DocumentReference attachment decode"
 S C0FDEP(2)="SYNFHF^CarePlan/HealthFactor filing"
 S C0FDEP(3)="SYNFMED^outpatient prescription filing"
 S C0FDEP(4)="SYNDHP65^procedure filing"
 S C0FDEP(5)="SYNDHP63^lab filing"
 S C0FDEP(6)="TIUSRVP^TIU note filing"
 S C0FN=0
 F C0FI=1:1:6 D
 . S C0FRTN=$P(C0FDEP(C0FI),"^"),C0FMSG=$P(C0FDEP(C0FI),"^",2)
 . S C0FX="+0^"_C0FRTN
 . Q:$T(@C0FX)'=""
 . S C0FN=C0FN+1
 . S RETURN("load","missingRoutines",C0FN)=C0FRTN_" is not installed; "_C0FMSG_" will be skipped"
 . S @ROOT@(IEN,"load","_dependencies",C0FRTN)="missing"
 Q
 ;
DISPATCH(ROOT,IEN,RIEN,DOMAIN,TYPE,ARGS,RETURN) ; Policy-aware domain dispatch
 N ENG
 S ENG=$$ENGINE^C0FWPOL(DOMAIN,.ARGS)
 I ENG="off" D SKIP^C0FWSTAT(ROOT,IEN,RIEN,DOMAIN,TYPE,$$REASON^C0FWPOL(DOMAIN,ENG,.ARGS),.RETURN) Q
 I ENG="syn" D  Q
 . I DOMAIN="HealthFactor" D LOAD^C0FWHSYN(ROOT,IEN,RIEN,.RETURN) Q
 . I DOMAIN="Lab" D LOAD^C0FWLAB(ROOT,IEN,RIEN,.RETURN) Q
 . D NI^C0FWSTAT(ROOT,IEN,RIEN,DOMAIN,TYPE,"C0FW policy requested SYN but no SYN wrapper is implemented for "_DOMAIN,.RETURN)
 I ENG="isi" D  Q
 . I DOMAIN="Lab" D LOAD^C0FWLAB(ROOT,IEN,RIEN,.RETURN) Q
 . D NI^C0FWSTAT(ROOT,IEN,RIEN,DOMAIN,TYPE,"C0FW policy requested ISI but no ISI wrapper is implemented for "_DOMAIN,.RETURN)
 D SAFE(ROOT,IEN,RIEN,DOMAIN,TYPE,ENG,.ARGS,.RETURN)
 Q
 ;
SAFE(ROOT,IEN,RIEN,DOMAIN,TYPE,ENG,ARGS,RETURN) ; Run native adapter with one-resource error isolation
 N $ETRAP,$ESTACK
 S $ETRAP="D DERR^C0FWDOM(ROOT,IEN,RIEN,DOMAIN,TYPE,.RETURN) S $ECODE="""" Q"
 I DOMAIN="Encounter" D HFPOL(ROOT,IEN,RIEN,TYPE,.ARGS,.RETURN)
 D NATIVE(ROOT,IEN,RIEN,DOMAIN,TYPE,.RETURN)
 I ENG="auto",$G(RETURN("domains",DOMAIN,"entries",RIEN))="not_implemented",DOMAIN="HealthFactor" D LOAD^C0FWHSYN(ROOT,IEN,RIEN,.RETURN)
 I ENG="auto",$G(RETURN("domains",DOMAIN,"entries",RIEN))="not_implemented",DOMAIN="Lab" D LOAD^C0FWLAB(ROOT,IEN,RIEN,.RETURN)
 Q
 ;
HFPOL(ROOT,IEN,RIEN,TYPE,ARGS,RETURN) ; Optional SYN pre-resolution for Encounter Health Factors
 N HFENG
 Q:'$$HFEXT(ROOT,IEN,RIEN)
 S HFENG=$$ENGINE^C0FWPOL("HealthFactor",.ARGS)
 I HFENG="syn"!(HFENG="auto") D LOAD^C0FWHSYN(ROOT,IEN,RIEN,.RETURN)
 Q
 ;
HFEXT(ROOT,IEN,RIEN) ; $$ - true if Encounter has C0FW Health Factor extensions
 N EI
 S EI=0
 F  S EI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI)) Q:+EI=0  I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","extension",EI,"url"))=$$HFURL^C0FWENC() Q
 Q $S(+EI>0:1,1:0)
 ;
NATIVE(ROOT,IEN,RIEN,DOMAIN,TYPE,RETURN) ; Native C0FW adapter dispatch
 I DOMAIN="Observation" D LOAD^C0FWVIT(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Smoking" D LOAD^C0FWSMOK(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="AIConsult" D LOAD^C0FWAIC(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Lab" D LOAD^C0FWLAB(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Condition" D LOAD^C0FWCON(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="DocumentReference" D LOAD^C0FWTIU(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Immunization" D LOAD^C0FWIMM(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Allergy" D LOAD^C0FWALG(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Medication" D LOAD^C0FWMED(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Procedure" D LOAD^C0FWPRC(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="ServiceRequest" D LOAD^C0FWSR(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="CarePlan" D LOAD^C0FWCP(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Appointment" D LOAD^C0FWAPT(ROOT,IEN,RIEN,.RETURN) Q
 I DOMAIN="Encounter" D LOAD^C0FWENC(ROOT,IEN,RIEN,.RETURN) Q
 D NI^C0FWSTAT(ROOT,IEN,RIEN,DOMAIN,TYPE,"No C0FW domain adapter selected",.RETURN)
 Q
 ;
DERR(ROOT,IEN,RIEN,DOMAIN,TYPE,RETURN) ; Trap one domain adapter failure and continue
 ; $ZS is $ZSTATUS (error text) on GT.M but $ZSTORAGE (memory limit) on
 ; IRIS/Cache - a bare $ZS here reported every IRIS adapter error as
 ; "2147483647". XECUTE keeps each platform's special variable compilable.
 N MSG
 S MSG=""
 X $S($P($SY,",")=47:"S MSG=$ZSTATUS",1:"S MSG=$ZE")
 I MSG="" S MSG=$ECODE
 I MSG="" S MSG="unknown M error"
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,$G(DOMAIN),$G(TYPE),"C0FW "_$G(DOMAIN)_" adapter error: "_MSG,.RETURN)
 Q
 ;
PERSIST(ROOT,IEN,RIEN,DOMAIN,RETURN) ; Persist response-only domain facts needed by later resources
 N VISIT
 Q:$G(ROOT)=""
 Q:+$G(IEN)<1
 Q:+$G(RIEN)<1
 Q:$G(DOMAIN)=""
 S VISIT=+$G(RETURN("domains",DOMAIN,"visitIen"))
 I VISIT<1,DOMAIN="Encounter" S VISIT=$$MATCHVIS^C0FWENC(ROOT,IEN,RIEN)
 I VISIT>0 S @ROOT@(IEN,"load",DOMAIN,RIEN,"visitIen")=VISIT
 Q
 ;
DOMAIN(ROOT,IEN,RIEN,TYPE) ; $$ - map FHIR resourceType to C0FW domain
 S TYPE=$G(TYPE)
 I TYPE="Observation" Q $S($$ISVITAL^C0FWVIT(ROOT,IEN,RIEN):"Observation",$$ISSMOK^C0FWSMOK(ROOT,IEN,RIEN):"Smoking",1:"Lab")
 I TYPE="DiagnosticReport" Q $S($$ISAIC^C0FWAIC(ROOT,IEN,RIEN):"AIConsult",1:"Lab")
 I TYPE="Encounter" Q "Encounter"
 I TYPE="Condition" Q "Condition"
 I TYPE="DocumentReference" Q "DocumentReference"
 I TYPE="Immunization" Q "Immunization"
 I TYPE="AllergyIntolerance" Q "Allergy"
 I TYPE="MedicationRequest" Q "Medication"
 I TYPE="Medication" Q "Medication"
 I TYPE="Procedure" Q "Procedure"
 I TYPE="ServiceRequest" Q "ServiceRequest"
 I TYPE="CarePlan" Q "CarePlan"
 I TYPE="Appointment" Q "Appointment"
 Q ""
 ;
SUMMARY(RETURN,COUNT) ; $$ - overall load summary
 N DOM,LOADED,NOTIMP,ERROR,SKIPPED
 I +$G(COUNT)<1 Q "no_applicable_resources"
 S (LOADED,NOTIMP,ERROR,SKIPPED)=0
 S DOM=""
 F  S DOM=$O(RETURN("domains",DOM)) Q:DOM=""  D
 . I $G(RETURN("domains",DOM,"status"))="loaded" S LOADED=1
 . I $G(RETURN("domains",DOM,"status"))="not_implemented" S NOTIMP=1
 . I $G(RETURN("domains",DOM,"status"))="error" S ERROR=1
 . I $G(RETURN("domains",DOM,"status"))="skipped" S SKIPPED=1
 I ERROR Q "error"
 I LOADED,(NOTIMP!SKIPPED) Q "partial"
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
