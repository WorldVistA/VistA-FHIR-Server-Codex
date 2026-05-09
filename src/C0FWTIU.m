C0FWTIU ; VEHU/Codex - C0FW TIU document writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; DocumentReference/TIU filing placeholder
 N MSG
 S MSG="TIU filing requires a C0FW TIU service adapter; no SYNFTIU importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"DocumentReference","DocumentReference",MSG,.RETURN)
 Q
 ;
