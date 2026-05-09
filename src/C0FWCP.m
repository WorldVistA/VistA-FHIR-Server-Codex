C0FWCP ; VEHU/Codex - C0FW care plan writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; CarePlan/clinical procedure filing placeholder
 N MSG
 S MSG="CarePlan filing requires a C0FW care-plan or clinical-procedure adapter; no SYNFCP importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"CarePlan","CarePlan",MSG,.RETURN)
 Q
 ;
