C0FGRPLAB ; Codex - probe fhir-intake Observation coverage ;Aug 03, 2026
 ;;0.1;C0FHIR PROJECT;;Aug 03, 2026
 Q
 ;
EN ; List DFNs with Observation rows / key LOINCs
 N ROOT,DFN,IEN,OC,R,P,N,HIT
 S ROOT=$$ROOT^C0FWFUTL()
 I ROOT="" W "no fhir-intake root",! Q
 W "ROOT=",ROOT,!
 S (DFN,N)=0
 F  S DFN=$O(@ROOT@("POS","DFN",DFN)) Q:'DFN  D
 . S IEN=$O(@ROOT@("POS","DFN",DFN,"")) Q:'IEN
 . S OC=0,R=0
 . F  S R=$O(@ROOT@(IEN,"type","Observation",R)) Q:'R  S OC=OC+1
 . S HIT=0,P=""
 . F  S P=$O(@ROOT@(IEN,"POS","code",P)) Q:P=""  D
 . . I P="72166-2"!(P="44249-1") S HIT=1
 . I OC<1,'HIT Q
 . S N=N+1
 . W "DFN=",DFN," IEN=",IEN," obs=",OC
 . S P="" F  S P=$O(@ROOT@(IEN,"POS","code",P)) Q:P=""  D
 . . I P="72166-2"!(P="44249-1")!(P["4548") W " code=",P
 . W !
 W "patientsWithObs=",N,!
 Q
 ;
