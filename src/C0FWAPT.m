C0FWAPT ; VEHU/Codex - C0FW appointment writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Appointment/scheduling filing placeholder
 N MSG
 S MSG="Appointment filing requires a C0FW scheduling adapter; no SYNFAPT importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Appointment","Appointment",MSG,.RETURN)
 Q
 ;
