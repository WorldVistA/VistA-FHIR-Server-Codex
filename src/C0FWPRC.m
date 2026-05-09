C0FWPRC ; VEHU/Codex - C0FW procedure writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Procedure/PCE filing placeholder
 N MSG
 S MSG="Procedure filing requires a C0FW PCE/procedure adapter; no SYNFPROC importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Procedure","Procedure",MSG,.RETURN)
 Q
 ;
