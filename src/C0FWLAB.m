C0FWLAB ; VEHU/Codex - C0FW lab writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; Lab observation/DiagnosticReport filing placeholder
 N TYPE,MSG
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 S MSG="Lab filing requires a C0FW accession/result adapter; no SYNFLAB or ISI lab importer is called."
 D NI^C0FWSTAT(ROOT,IEN,RIEN,"Lab",TYPE,MSG,.RETURN)
 Q
 ;
