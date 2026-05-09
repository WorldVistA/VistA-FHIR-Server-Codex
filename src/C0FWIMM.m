C0FWIMM ; VEHU/Codex - C0FW immunization writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Immunization/PCE filing placeholder
 N MSG
 S MSG="Immunization filing requires a C0FW PCE immunization adapter; no SYNFIMM importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Immunization","Immunization",MSG,.RETURN)
 Q
 ;
