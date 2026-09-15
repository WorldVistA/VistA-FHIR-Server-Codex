C0FWSTAT ; VEHU/Codex - C0FW domain status helpers ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
NI(ROOT,IEN,RIEN,DOMAIN,TYPE,MSG,RETURN) ; Record not-implemented domain status
 I $G(MSG)="" S MSG="C0FW "_$G(DOMAIN)_" clinical filing is not implemented; SYNF/ISI importers are intentionally not called."
 D SET(ROOT,IEN,RIEN,$G(DOMAIN),$G(TYPE),"not_implemented",MSG,.RETURN)
 Q
 ;
ERR(ROOT,IEN,RIEN,DOMAIN,TYPE,MSG,RETURN) ; Record error status
 D SET(ROOT,IEN,RIEN,$G(DOMAIN),$G(TYPE),"error",$G(MSG),.RETURN)
 Q
 ;
SKIP(ROOT,IEN,RIEN,DOMAIN,TYPE,MSG,RETURN) ; Record skipped status
 D SET(ROOT,IEN,RIEN,$G(DOMAIN),$G(TYPE),"skipped",$G(MSG),.RETURN)
 Q
 ;
SET(ROOT,IEN,RIEN,DOMAIN,TYPE,STATUS,MSG,RETURN) ; Record domain load status
 Q:$G(ROOT)=""
 Q:$G(DOMAIN)=""
 S IEN=+$G(IEN),RIEN=+$G(RIEN)
 Q:IEN<1
 Q:RIEN<1
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"loadStatus")=$G(STATUS)
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"resourceType")=$G(TYPE)
 S @ROOT@(IEN,"load",DOMAIN,RIEN,"message")=$G(MSG)
 S RETURN("domains",DOMAIN,"status")=$G(STATUS)
 S RETURN("domains",DOMAIN,"message")=$G(MSG)
 S RETURN("domains",DOMAIN,"entries",RIEN)=$G(STATUS)
 Q
 ;
STAGED(ROOT,IEN,FROM,TO,RETURN) ; Mark simulation-staged entries as skipped
 ; Simulation writes (load=0) append entries to the intake graph with no
 ; per-entry loadStatus, so the legacy replay (wsReplayIntake^SYNFHIR)
 ; would FILE the staged simulation data into the chart (proven on a
 ; ci-roundtrip container 2026-09-13: harness simulation write, entry
 ; zx=567, duplicated the visit on replay). "skipped" is honored by both
 ; marker families via the C0FWLD^SYNFHIRU cross-vintage guard.
 ; NOTE: do NOT call this for the no-DFN orphan-row path — replaying that
 ; row later with an explicit dfn is the documented duplicate-SSN
 ; recovery flow and must still file.
 N RIEN,TYPE
 S FROM=+$G(FROM),TO=+$G(TO)
 Q:FROM<1!(TO<FROM)
 F RIEN=FROM:1:TO D
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . Q:TYPE=""
 . D SKIP(ROOT,IEN,RIEN,TYPE,TYPE,"staged only (load=0 simulation): not filed; replay must not file simulation data",.RETURN)
 Q
 ;
CAP(NAME,ROUTINE) ; $$ - capability text
 I $G(ROUTINE)'="",$T(@ROUTINE)'="" Q NAME_" API present but C0FW adapter is not implemented yet."
 Q NAME_" API/capability not implemented or not probed for this C0FW slice."
 ;
