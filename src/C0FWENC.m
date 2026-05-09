C0FWENC ; VEHU/Codex - C0FW encounter writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Encounter/PCC visit filing placeholder
 N MSG
 S MSG="Encounter filing requires a C0FW PCE/PCC visit adapter; no SYNFENC importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Encounter","Encounter",MSG,.RETURN)
 Q
 ;
