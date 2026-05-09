C0FWFUTL ; VEHU/Codex - C0FW update utilities ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
ROOT() ; $$ - fhir-intake graph root
 Q $$ROOT^C0FWGRT("fhir-intake")
 ;
SETIDX(SUB,PRED,OBJ) ; Set graph indexes on fhir-intake
 N GN
 S GN=$$ROOT()
 Q:GN=""
 D SETIDXGN(GN,$G(SUB),$G(PRED),$G(OBJ))
 Q
 ;
SETIDXGN(GN,SUB,PRED,OBJ) ; Set graph indexes on supplied graph root
 Q:$G(GN)=""
 Q:$G(SUB)=""
 Q:$G(PRED)=""
 Q:$G(OBJ)=""
 S @GN@("SPO",SUB,PRED,OBJ)=""
 S @GN@("POS",PRED,OBJ,SUB)=""
 S @GN@("PSO",PRED,SUB,OBJ)=""
 S @GN@("OPS",OBJ,PRED,SUB)=""
 Q
 ;
DFN2IEN(DFN) ; $$ - graph ien for DFN
 N ROOT
 S ROOT=$$ROOT()
 Q:ROOT="" ""
 Q $O(@ROOT@("POS","DFN",+$G(DFN),""))
 ;
IEN2DFN(IEN) ; $$ - DFN for graph ien
 N ROOT
 S ROOT=$$ROOT()
 Q:ROOT="" ""
 Q $O(@ROOT@("PSO","DFN",+$G(IEN),""))
 ;
ICN2IEN(ICN) ; $$ - graph ien for ICN
 N ROOT
 S ROOT=$$ROOT()
 Q:ROOT="" ""
 Q $O(@ROOT@("POS","ICN",$G(ICN),""))
 ;
IEN2ICN(IEN) ; $$ - ICN for graph ien
 N ROOT
 S ROOT=$$ROOT()
 Q:ROOT="" ""
 Q $O(@ROOT@("PSO","ICN",+$G(IEN),""))
 ;
DFN2ICN(DFN) ; $$ - existing ICN for patient/graph link
 N ICN,IEN
 S DFN=+$G(DFN)
 Q:DFN<1 ""
 S IEN=$$DFN2IEN(DFN)
 I IEN>0 S ICN=$$IEN2ICN(IEN) I ICN'="" Q ICN
 S ICN=$O(^DPT("AFICN",DFN,""))
 I ICN'="" Q ICN
 S ICN=$O(^DPT("ARFICN",DFN,""))
 Q ICN
 ;
FHIRISO2HL7(DTIN) ; $$ - ISO/FHIR instant to compact HL7 timestamp
 N D,DONE,HMS,IN,J,T,DS
 S IN=$G(DTIN) Q:IN="" ""
 S DS=""
 I $L(IN),($E(IN,$L(IN))="Z"!($E(IN,$L(IN))="z")) S IN=$E(IN,1,$L(IN)-1)
 I IN'["-",IN'["T" D  Q DS
 . S DS=""
 . I IN?8N S DS=IN_"000000" Q
 . I IN?12N S DS=IN_"00" Q
 . I IN?14N S DS=IN
 S D=$P(IN,"T",1),T=$P(IN,"T",2)
 Q:D="" ""
 Q:$L(D)<10 ""
 S DS=$E(D,1,4)_$E(D,6,7)_$E(D,9,10)
 Q:DS'?8N ""
 S HMS="000000"
 I T'="" D
 . I T["." S T=$P(T,".",1)
 . I T["+" S T=$P(T,"+",1)
 . E  D
 . . S DONE=0
 . . F J=1:1:$L(T) Q:DONE  I $E(T,J)="-" D
 . . . I J>8,$E(T,J+1)?1N,$E(T,J+2)?1N,$E(T,J+3)=":" S T=$E(T,1,J-1),DONE=1
 . S HMS=$TR(T,":","")
 . I HMS="" S HMS="000000" Q
 . I HMS'?1.12N S HMS="000000" Q
 . I $L(HMS)=4 S HMS=HMS_"00"
 . I $L(HMS)=2 S HMS=HMS_"0000"
 . I $L(HMS)>6 S HMS=$E(HMS,1,6)
 Q DS_HMS
 ;
FHIRTFM(DTIN) ; $$ - ISO/FHIR instant to FileMan date/time
 N TS
 S TS=$$FHIRISO2HL7($G(DTIN))
 Q:TS="" -1
 Q $$HL7TFM^XLFDT(TS)
 ;
FHIRTHL7(DTIN) ; $$ - ISO/FHIR instant to compact HL7 timestamp
 Q $$FHIRISO2HL7($G(DTIN))
 ;
