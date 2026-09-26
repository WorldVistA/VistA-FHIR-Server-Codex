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
 N FULL,ICN,IEN
 S DFN=+$G(DFN)
 Q:DFN<1 ""
 S IEN=$$DFN2IEN(DFN)
 I IEN>0 S ICN=$$IEN2ICN(IEN) I ICN'="" Q ICN
 ; Prefer full ICN used as ^DPT("AFICN") key (991.1), not bare 991.01.
 S ICN=$$GET1^DIQ(2,DFN_",",991.1,"E")
 I ICN'="" Q ICN
 S ICN=$P($G(^DPT(DFN,"MPI")),U,10)
 I ICN'="" Q ICN
 S ICN=$$GET1^DIQ(2,DFN_",",991.01,"E")
 I ICN'="",$D(^DPT("AFICN",ICN)) Q ICN
 I ICN'="",ICN'["V" S FULL=ICN_"V"_$P($G(^DPT(DFN,"MPI")),U,2) I $D(^DPT("AFICN",FULL)) Q FULL
 ; Legacy reverse probes (not the normal AFICN shape)
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
HEX2DEC(HEX) ; $$ - decimal from hex (Synthea UUID tail)
 N II,DEC,DIG
 S DEC=0,HEX=$TR($G(HEX),"ABCDEF","abcdef")
 F II=1:1:$L(HEX) S DIG=$F("0123456789abcdef",$E(HEX,II)) Q:'DIG  S DEC=(DEC*16)+(DIG-2)
 Q DEC
 ;
PID2ICN(PID) ; $$ - 10-digit ICN base from Synthea UUID / urn:uuid
 ; example: urn:uuid:0a01efae-0662-41ae-a20d-4646ce42b687
 N HPID,DPID
 S HPID=$P($G(PID),"-",5)
 I HPID="" Q ""
 S DPID=$$HEX2DEC(HPID)
 S DPID=$E(DPID,1,10)
 I DPID'?1.10N Q ""
 I $L(DPID)<10 S DPID=$E("0000000000",1,10-$L(DPID))_DPID
 Q DPID
 ;
FULLICN(BASE) ; $$ - BASE_V_checksum (MPIFSPC or local fallback)
 N CHK
 S BASE=$G(BASE)
 I BASE'?10N Q ""
 S CHK=$$CHKSUM(BASE)
 I CHK="" Q ""
 Q BASE_"V"_CHK
 ;
CHKSUM(BASE) ; $$ - ICN check digits; prefer MPI API when present
 N CHK
 S BASE=$G(BASE)
 I BASE'?10N Q ""
 I $T(CHECKDG^MPIFSPC)'="" D  Q CHK
 . S CHK=$$CHECKDG^MPIFSPC(BASE)
 Q $$LOCCHK(BASE)
 ;
LOCCHK(BASE) ; $$ - deterministic 6-digit checksum when MPIFSPC absent
 N I,S,D
 S S=0
 F I=1:1:$L(BASE) S D=$E(BASE,I) S S=S+(D*I)
 S S=S#1000000
 Q $E(1000000+S,2,7)
 ;
ICNEXISTS(FULL) ; $$ - 1 if ICN already on File 2 or graph
 N BASE,NXT,ROOT
 S FULL=$G(FULL)
 I FULL="" Q 0
 I $D(^DPT("AFICN",FULL)) Q 1
 ; Also match any AFICN with same 10-digit base (checksum may differ by site)
 S BASE=$P(FULL,"V",1)
 I BASE?10N D  I NXT'="" Q 1
 . S NXT=$O(^DPT("AFICN",BASE_"V"))
 . I NXT'="",$E(NXT,1,11)'=(BASE_"V") S NXT=""
 S ROOT=$$ROOT()
 I ROOT'="",$O(@ROOT@("POS","ICN",FULL,""))'="" Q 1
 Q 0
 ;
SYNCPID(ROOT,IEN) ; $$ - Synthea UUID string from Patient in graph row
 N PENT,ID,IDX,SYS,VAL,LOW,FU
 S ROOT=$G(ROOT) I ROOT="" S ROOT=$$ROOT()
 I ROOT=""!(+$G(IEN)<1) Q ""
 S PENT=0
 F  S PENT=$O(@ROOT@(IEN,"json","entry",PENT)) Q:+PENT=0  I $G(@ROOT@(IEN,"json","entry",PENT,"resource","resourceType"))="Patient" Q
 I +PENT<1 Q ""
 S ID=$$TRIM($G(@ROOT@(IEN,"json","entry",PENT,"resource","id")))
 I $$ISUUID(ID) Q $S(ID["urn:uuid:":ID,1:"urn:uuid:"_ID)
 S FU=$$TRIM($G(@ROOT@(IEN,"json","entry",PENT,"fullUrl")))
 I $$ISUUID(FU) Q $S(FU["urn:uuid:":FU,FU["urn:uuid":FU,1:FU)
 S (IDX,VAL)=""
 F  S IDX=$O(@ROOT@(IEN,"json","entry",PENT,"resource","identifier",IDX)) Q:IDX=""  D  Q:VAL'=""
 . S LOW=$$LOW($G(@ROOT@(IEN,"json","entry",PENT,"resource","identifier",IDX,"system")))
 . S VAL=$$TRIM($G(@ROOT@(IEN,"json","entry",PENT,"resource","identifier",IDX,"value")))
 . Q:VAL=""
 . I LOW'["synthetichealth",LOW'["synthea" S VAL="" Q
 . I '$$ISUUID(VAL) S VAL="" Q
 I VAL'="" Q $S(VAL["urn:uuid:":VAL,1:"urn:uuid:"_VAL)
 Q ""
 ;
SYNCFULL(ROOT,IEN) ; $$ - full ICN (baseVchk) from Synthea UUID in graph
 N PID,BASE
 S PID=$$SYNCPID($G(ROOT),+$G(IEN))
 I PID="" Q ""
 S BASE=$$PID2ICN(PID)
 I BASE="" Q ""
 Q $$FULLICN(BASE)
 ;
ISUUID(X) ; $$ - looks like UUID or urn:uuid
 N S
 S S=$$LOW($G(X))
 I S["urn:uuid:" S S=$P(S,"urn:uuid:",2)
 I $L(S)'=36 Q 0
 I $E(S,9)'="-"!($E(S,14)'="-")!($E(S,19)'="-")!($E(S,24)'="-") Q 0
 I $TR(S,"0123456789abcdef-","")'="" Q 0
 Q 1
 ;
TRIM(X) ;
 N S S S=$G(X)
 F  Q:$E(S)'=" "  S S=$E(S,2,$L(S))
 F  Q:$E(S,$L(S))'=" "  S S=$E(S,1,$L(S)-1)
 Q S
 ;
LOW(X) ;
 N Y
 S X=$G(X)
 I $T(LOW^XLFSTR)'="" Q $$LOW^XLFSTR(X)
 S Y=X
 Q $TR(Y,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")
 ;
