C0FWMED ; VEHU/Codex - C0FW medication writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Medication filing placeholder
 N MSG,TYPE
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 S MSG="Medication filing requires a C0FW medication/order adapter; no SYNFMED importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Medication",TYPE,MSG,.RETURN)
 Q
 ;
