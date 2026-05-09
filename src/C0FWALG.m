C0FWALG ; VEHU/Codex - C0FW allergy writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Allergy filing placeholder
 N MSG
 S MSG="Allergy filing requires a C0FW allergy package adapter; no SYNFALG importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Allergy","AllergyIntolerance",MSG,.RETURN)
 Q
 ;
