C0FWLNK ; VEHU/Codex - C0FW graph patient link helpers ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LNKPAT(IEN,DFN,ICN,ROOT) ; Link an existing VistA patient to a graph row
 I $G(ROOT)="" S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:$G(ROOT)=""
 Q:+$G(IEN)<1
 Q:+$G(DFN)<1
 Q:'$D(^DPT(DFN,0))
 S @ROOT@("DFN",DFN,IEN)=""
 S @ROOT@(IEN,"DFN",DFN)=""
 D SETIDXGN^C0FWFUTL(ROOT,IEN,"DFN",DFN)
 I $G(@ROOT@(IEN,"load","Patient","status","DFN"))="" S @ROOT@(IEN,"load","Patient","status","DFN")=DFN
 I $G(@ROOT@(IEN,"load","Patient","status","loadStatus"))="" S @ROOT@(IEN,"load","Patient","status","loadStatus")="loaded"
 S ICN=$$DPTICN(DFN,$G(ICN))
 I ICN'="",ICN'=-1 D
 . S @ROOT@("ICN",ICN,IEN)=""
 . S @ROOT@(IEN,"ICN",ICN)=""
 . D SETIDXGN^C0FWFUTL(ROOT,IEN,"ICN",ICN)
 . I $G(@ROOT@(IEN,"load","Patient","status","ICN"))="" S @ROOT@(IEN,"load","Patient","status","ICN")=ICN
 Q
 ;
DPTICN(DFN,ICN) ; $$ - existing patient ICN without assigning one
 S ICN=$G(ICN)
 I ICN'="" Q ICN
 Q $$DFN2ICN^C0FWFUTL(+$G(DFN))
 ;
HASPAT(ARY) ; $$ - graph row already has a Patient resource
 N ZI
 S ZI=0
 F  S ZI=$O(@ARY@("json","entry",ZI)) Q:+ZI=0  I $G(@ARY@("json","entry",ZI,"resource","resourceType"))="Patient" Q
 Q $S(+ZI>0:1,1:0)
 ;
