C0FWGRT ; VEHU/Codex - C0FW graph root adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 ; Detects the installed graph backend and returns the active graph root.
 ; The physical graph store is site-owned: either ^%wd or ^SYNGRAPH.
 ;
 Q
 ;
ROOT(GRAPH) ; $$ - active root for named graph
 N RTN
 S GRAPH=$G(GRAPH)
 I GRAPH="" Q ""
 S RTN=$$GRTN(GRAPH)
 I RTN="%wd",$T(setroot^%wd)'="" Q $$setroot^%wd(GRAPH)
 I RTN="SYNGRAF",$T(setroot^SYNGRAF)'="" Q $$setroot^SYNGRAF(GRAPH)
 I RTN="WDIRECT" Q $$WDROOT(GRAPH)
 Q ""
 ;
GRTN(GRAPH) ; $$ - backend name for graph
 S GRAPH=$G(GRAPH)
 I $$SYNHAS(GRAPH) Q "SYNGRAF"
 I $$WDHAS(GRAPH) Q "%wd"
 I $$WDHASD(GRAPH) Q "WDIRECT"
 I $$SYNHAS("fhir-intake") Q "SYNGRAF"
 I $$WDHAS("fhir-intake") Q "%wd"
 I $$WDHASD("fhir-intake") Q "WDIRECT"
 I $$SYNHAS("loinc-lab-map") Q "SYNGRAF"
 I $$WDHAS("loinc-lab-map") Q "%wd"
 I $$SYNHAS("html-cache") Q "SYNGRAF"
 I $$WDHAS("html-cache") Q "%wd"
 I $$SYNHAS("seeGraph") Q "SYNGRAF"
 I $$WDHAS("seeGraph") Q "%wd"
 I $$SYNOK(),'$$WDOK() Q "SYNGRAF"
 I $$WDOK(),'$$SYNOK() Q "%wd"
 I $$SYNOK() Q "SYNGRAF"
 I $$WDOK() Q "%wd"
 I GRAPH="fhir-intake" Q "WDIRECT"
 Q ""
 ;
WDOK() ; $$ - legacy %wd graph store available
 Q $S($T(setroot^%wd)="":0,$P($G(^DIC(17.040801,0)),"^")="":0,1:1)
 ;
SYNOK() ; $$ - SYNGRAPH graph store available
 Q $S($T(setroot^SYNGRAF)="":0,$P($G(^DIC(2002.801,0)),"^")="":0,1:1)
 ;
WDHAS(GRAPH) ; $$ - named graph exists in %wd
 N GIEN,ROOT
 I $G(GRAPH)="" Q 0
 I '$$WDOK() Q 0
 S ROOT="^"_$C(37)_"wd(17.040801,""B"")"
 S GIEN=$O(@ROOT@(GRAPH,0))
 Q $S(+GIEN>0:1,1:0)
 ;
SYNHAS(GRAPH) ; $$ - named graph exists in SYNGRAPH
 N GIEN
 I $G(GRAPH)="" Q 0
 I '$$SYNOK() Q 0
 S GIEN=$O(^SYNGRAPH(2002.801,"B",GRAPH,0))
 Q $S(+GIEN>0:1,1:0)
 ;
WDHASD(GRAPH) ; $$ - named graph exists in direct ^%wd fallback
 N GIEN,ROOT
 I $G(GRAPH)="" Q 0
 S ROOT="^"_$C(37)_"wd(17.040801,""B"")"
 S GIEN=$O(@ROOT@(GRAPH,0))
 Q $S(+GIEN>0:1,1:0)
 ;
WDROOT(GRAPH) ; $$ - direct ^%wd graph root for sites without %wd routine
 N BROOT,GIEN,ROOT
 S GRAPH=$G(GRAPH)
 I GRAPH="" Q ""
 S ROOT="^"_$C(37)_"wd(17.040801)"
 S BROOT="^"_$C(37)_"wd(17.040801,""B"")"
 S GIEN=$O(@BROOT@(GRAPH,0))
 I GIEN<1 D
 . S GIEN=$S(GRAPH="fhir-intake":3,1:$O(@ROOT@(" "),-1)+1)
 . I GIEN<1 S GIEN=1
 . S @ROOT@(GIEN,0)=GRAPH
 . S @BROOT@(GRAPH,GIEN)=""
 . I $G(@ROOT@(0))="" S @ROOT@(0)="graph^17.040801"
 . I +$P($G(@ROOT@(0)),"^",3)<GIEN S $P(@ROOT@(0),"^",3)=GIEN
 . S $P(@ROOT@(0),"^",4)=+$P($G(@ROOT@(0)),"^",4)+1
 Q "^"_$C(37)_"wd(17.040801,"_GIEN_")"
 ;
