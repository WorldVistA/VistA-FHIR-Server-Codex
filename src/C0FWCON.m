C0FWCON ; VEHU/Codex - C0FW condition writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Condition/problem filing placeholder
 N MSG
 S MSG="Condition filing requires a C0FW Problem List adapter; no SYNFPR2 or ISI importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Condition","Condition",MSG,.RETURN)
 Q
 ;
