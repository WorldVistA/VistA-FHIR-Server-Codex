C0FWVITR ; VEHU/Codex - repair GMV vitals filed without unit conversion ;Oct 11, 2026
 ;;0.1;C0FHIR PROJECT;;Oct 11, 2026
 ;
 ; Before Codex 87d3bbf, LOAD^C0FWVIT filed FHIR heights/weights/temperatures
 ; into GMV (#120.5) with the raw cm/kg/Cel number, so 165 cm read back as
 ; 419.1 cm. This walks every fhir-intake graph row's vital load nodes and
 ; finds the ones whose FHIR unit is SI but whose GMV row still holds the raw
 ; value. FIX=0 reports only; FIX=1 marks the GMV row entered-in-error
 ; (ERROR^GMVUTL1, reason 2 = incorrect reading - what CPRS does), re-files
 ; the converted value through EN1^GMVDCSAV, and updates the load node.
 ;
 ;   D EN^C0FWVITR      ; report
 ;   D EN^C0FWVITR(1)   ; repair
 Q
 ;
EN(FIX) ; scan every graph row
 N ROOT,IEN,CNT
 I $G(U)="" S U="^"
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" W "fhir-intake graph not available",! Q
 S FIX=+$G(FIX)
 S IEN=0 F  S IEN=$O(@ROOT@(IEN)) Q:IEN'>0  D ROW(ROOT,IEN,FIX,.CNT)
 W "vital nodes ",+$G(CNT("nodes"))," mis-filed ",+$G(CNT("bad"))," ",$S(FIX:"repaired ",1:"would repair "),+$G(CNT("fixed"))," failed ",+$G(CNT("failed")),!
 Q
 ;
ROW(ROOT,IEN,FIX,CNT) ; one graph row
 N ABBR,DFN,EXP,FMDT,GIEN,LOC,RAW,RIEN,TYPE,UNIT,VAL
 S RIEN=0 F  S RIEN=$O(@ROOT@(IEN,"load","Observation",RIEN)) Q:RIEN'>0  D
 . Q:$G(@ROOT@(IEN,"load","Observation",RIEN,"file"))'=120.5
 . S TYPE=+$G(@ROOT@(IEN,"load","Observation",RIEN,"vitalType"))
 . S ABBR=$P($G(^GMRD(120.51,TYPE,0)),U,2)
 . Q:'("^HT^WT^T^"[(U_ABBR_U))
 . S CNT("nodes")=$G(CNT("nodes"))+1
 . S VAL=$G(@ROOT@(IEN,"load","Observation",RIEN,"value")) Q:VAL=""
 . S RAW=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueQuantity","value")) Q:RAW=""
 . S UNIT=$$UNIT^C0FWVIT(ROOT,IEN,RIEN)
 . S EXP=$$CNV^C0FWVIT(ABBR,RAW,UNIT)
 . Q:EXP=RAW  ; non-SI unit: nothing to convert
 . Q:VAL'=RAW  ; load node already holds the converted value (filed after 87d3bbf)
 . S FMDT=$G(@ROOT@(IEN,"load","Observation",RIEN,"dateTime"))
 . S DFN=+$O(@ROOT@("SPO",IEN,"DFN","")) Q:DFN<1
 . S GIEN=$$GMVIEN(DFN,TYPE,FMDT,RAW) Q:GIEN<1  ; already repaired by hand, or never filed
 . S CNT("bad")=$G(CNT("bad"))+1
 . W "DFN ",DFN," ",ABBR," ",RAW," ",UNIT," -> ",EXP," @",FMDT," gmv ",GIEN
 . I 'FIX W ! Q
 . S LOC=+$G(@ROOT@(IEN,"load","Observation",RIEN,"location"))
 . I $$REFILE(DFN,TYPE,FMDT,EXP,LOC,GIEN) D  Q
 . . S @ROOT@(IEN,"load","Observation",RIEN,"value")=EXP
 . . S @ROOT@(IEN,"load","Observation",RIEN,"repaired")=$$NOW^XLFDT_U_GIEN
 . . S CNT("fixed")=$G(CNT("fixed"))+1 W " OK",!
 . S CNT("failed")=$G(CNT("failed"))+1 W " FAILED",!
 Q
 ;
GMVIEN(DFN,TYPE,FMDT,VAL) ; $$ - live GMV row for patient/type/date/value, 0 if none
 N IEN,X0,HIT
 S (IEN,HIT)=0
 F  S IEN=$O(^GMR(120.5,"C",DFN,IEN)) Q:IEN'>0  D  Q:HIT
 . S X0=$G(^GMR(120.5,IEN,0)) Q:X0=""
 . Q:+$P(X0,U)'=+FMDT  Q:$P(X0,U,2)'=DFN  Q:$P(X0,U,3)'=TYPE  Q:$P(X0,U,8)'=VAL
 . Q:+$P($G(^GMR(120.5,IEN,2)),U)=1  ; already entered-in-error
 . S HIT=IEN
 Q HIT
 ;
REFILE(DFN,TYPE,FMDT,VAL,LOC,GIEN) ; $$ - mark GIEN entered-in-error, file VAL in its place; 1 on success
 N ENT,INVAR,OUT,RSLT
 S ENT=$$DUZ^C0FWCTX()
 I LOC<1 S LOC=+$P($G(^GMR(120.5,GIEN,0)),U,5)
 I LOC<1 Q 0
 D ERROR^GMVUTL1(.RSLT,GIEN_U_ENT_U_2)
 I +$P($G(^GMR(120.5,GIEN,2)),U)'=1 Q 0
 S INVAR=FMDT_U_DFN_U_TYPE_";"_VAL_";"_U_LOC_U_ENT
 D EN1^GMVDCSAV(.OUT,INVAR)
 I $G(OUT(0))["ERROR" Q 0
 Q 1
