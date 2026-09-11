C0FWMED ; VEHU/Codex - C0FW medication writeback via SYNFMED Rx ;Sep 09, 2026
 ;;0.2;C0FHIR PROJECT;;Sep 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR MedicationRequest as an outpatient Rx
 N DFN,DRUG,FMDT,GIEN,GRIEN,NAME,RET,RXN,TYPE,X
 I $G(U)="" S U="^"
 S GIEN=+$G(IEN),GRIEN=+$G(RIEN)
 I $G(ROOT)="" D ERR(ROOT,GIEN,GRIEN,"Medication","Missing graph root",.RETURN) Q
 S TYPE=$G(@ROOT@(GIEN,"json","entry",GRIEN,"resource","resourceType"))
 I TYPE="Medication" D SKIP(ROOT,GIEN,GRIEN,TYPE,0,0,"Medication resource is a code companion; filing is on MedicationRequest",.RETURN) Q
 I TYPE'="MedicationRequest" D ERR(ROOT,GIEN,GRIEN,TYPE,"Resource is not MedicationRequest",.RETURN) Q
 S X="WRITERXRXN^SYNFMED"
 I $T(@X)="" D SKIP(ROOT,GIEN,GRIEN,TYPE,0,0,"SYNFMED is not installed; cannot file outpatient prescriptions",.RETURN) Q
 S X="EN^PSON52"
 I $T(@X)="" D SKIP(ROOT,GIEN,GRIEN,TYPE,0,0,"Outpatient pharmacy PSON52 is not present; medication filing skipped",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",GIEN,"DFN",""))
 I DFN<1 D ERR(ROOT,GIEN,GRIEN,TYPE,"No DFN linked to graph row",.RETURN) Q
 S RXN=$$RXN(ROOT,GIEN,GRIEN)
 I RXN="" D SKIP(ROOT,GIEN,GRIEN,TYPE,0,0,"MedicationRequest has no RxNorm code; skipped",.RETURN) Q
 S NAME=$$NAME(ROOT,GIEN,GRIEN,RXN)
 S FMDT=$$FMDT(ROOT,GIEN,GRIEN)
 I FMDT<1 S FMDT=$$DT^XLFDT
 S DRUG=$$PREP(RXN)
 I DRUG<1 D SKIP(ROOT,GIEN,GRIEN,TYPE,0,RXN,"No VistA drug match for RxNorm "_RXN_" "_NAME,.RETURN) Q
 I $$HASRX(DFN,DRUG) D SKIP(ROOT,GIEN,GRIEN,TYPE,DRUG,RXN,"Medication already on patient outpatient profile: "_NAME,.RETURN) Q
 I $$ISNARC(DRUG) D SKIP(ROOT,GIEN,GRIEN,TYPE,DRUG,RXN,"Scheduled/narcotic drug skipped; SYNFMED default refill is not allowed: "_NAME,.RETURN) Q
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 ; The PSO/Kernel chain under FILEPS KILLs common local names (seen on IRIS
 ; 2026-09-11: RXN gone at the success log). Snapshot into C0FW-namespaced
 ; storage and restore after - same defense as the Sept sprint LAST fix.
 N C0FWSAV
 S C0FWSAV("ROOT")=ROOT,C0FWSAV("RXN")=RXN,C0FWSAV("NAME")=NAME,C0FWSAV("TYPE")=TYPE,C0FWSAV("DRUG")=DRUG,C0FWSAV("GIEN")=GIEN,C0FWSAV("GRIEN")=GRIEN
 S RET=$$FILEPS(DFN,DRUG,FMDT)
 S ROOT=C0FWSAV("ROOT"),RXN=C0FWSAV("RXN"),NAME=C0FWSAV("NAME"),TYPE=C0FWSAV("TYPE"),DRUG=C0FWSAV("DRUG"),GIEN=C0FWSAV("GIEN"),GRIEN=C0FWSAV("GRIEN")
 S IEN=GIEN,RIEN=GRIEN
 I +RET>1 D  Q
 . D LOADED(ROOT,GIEN,GRIEN,TYPE,+RET,RXN,"Medication filed as outpatient Rx "_RET_": "_NAME,.RETURN)
 . I $T(INV^C0FWCAC)'="" D INV^C0FWCAC(GIEN,ROOT)
 I +RET=-1!(+RET=-2) D SKIP(ROOT,GIEN,GRIEN,TYPE,DRUG,RXN,"WRITERXPS^SYNFMED rejected RxNorm "_RXN_" "_NAME,.RETURN) Q
 I $G(RET)="" D ERR(ROOT,GIEN,GRIEN,TYPE,"WRITERXPS^SYNFMED returned empty status for RxNorm "_RXN,.RETURN) Q
 D ERR(ROOT,GIEN,GRIEN,TYPE,"WRITERXPS^SYNFMED failed: "_RET,.RETURN)
 Q
 ;
PREP(RXN) ; $$ - convert RxNorm and ensure a file 50 IEN (may laygo)
 N IEN,SCD,X
 S X="ADDDRUG^SYNFMED"
 I $T(@X)="" Q 0
 S SCD=$G(RXN)
 I $T(RXNCONV^SYNFMED)'="" S SCD=$$RXNCONV^SYNFMED(RXN)
 I 'SCD Q 0
 Q +$$ADDDRUG^SYNFMED(SCD)
 ;
FILEPS(DFN,DRUG,FMDT) ; $$ - file one Rx with PSO locals isolated
 N IEN,OT,PSONEW,PSODRUG,PSOY,PSOSITE,PSOPAR,PSOPAR7,PSOSYS,PSODTCUT,PSOPRPAS
 N PSOCOU,PSOCOUU,PSONOOR,PSOMAILX,PSOSCP,PPL,PDUZ,POERR,RXP,PSRH,PSIN,IOP
 N SYNRXN,SYNRXIEN,SYNPHARM,PSODFN
 S PSODFN=+$G(DFN)
 I $G(DT)<1 S DT=$$DT^XLFDT
 I $G(U)="" S U="^"
 Q $$WRITERXPS^SYNFMED(PSODFN,+$G(DRUG),+$G(FMDT))
 ;
RXN(ROOT,IEN,RIEN) ; $$ - RxNorm code from MedicationRequest or referenced Medication
 N CODE,MRIEN,REF,SYS
 S CODE=$$RXNCC(ROOT,IEN,RIEN,"resource","medicationCodeableConcept")
 I CODE'="" Q CODE
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","medicationReference","reference"))
 I REF="" Q ""
 S MRIEN=$$REFIND(ROOT,IEN,REF,"Medication")
 I MRIEN<1 Q ""
 Q $$RXNCC(ROOT,IEN,MRIEN,"resource","code")
 ;
RXNCC(ROOT,IEN,RIEN,P1,P2) ; $$ - first RxNorm coding under path P1,P2
 N CI,CODE,SYS
 S (CODE,CI)=""
 F  S CI=$O(@ROOT@(IEN,"json","entry",RIEN,P1,P2,"coding",CI)) Q:+CI=0  D  Q:CODE'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,P1,P2,"coding",CI,"system")))
 . I SYS'["RXNORM",SYS'["RXN" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,P1,P2,"coding",CI,"code"))
 I CODE="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,P1,P2,"coding",1,"code"))
 Q CODE
 ;
NAME(ROOT,IEN,RIEN,RXN) ; $$ - display text for logging
 N MRIEN,REF,TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","medicationCodeableConcept","coding",1,"display"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","medicationCodeableConcept","text"))
 I TXT="" D
 . S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","medicationReference","reference"))
 . S MRIEN=$$REFIND(ROOT,IEN,REF,"Medication")
 . I MRIEN<1 Q
 . S TXT=$G(@ROOT@(IEN,"json","entry",MRIEN,"resource","code","coding",1,"display"))
 I TXT="" S TXT="RxNorm "_$G(RXN)
 Q TXT
 ;
FMDT(ROOT,IEN,RIEN) ; $$ - authoredOn as FileMan date
 N DT
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","authoredOn")))
 I DT>0 Q (DT\1)
 S DT=$$FHIRTFM^C0FWFUTL($G(@ROOT@(IEN,"json","entry",RIEN,"resource","dispenseRequest","validityPeriod","start")))
 I DT>0 Q (DT\1)
 Q 0
 ;
ISNARC(DRUG) ; $$ - true if file 50 DEA/special handling disallows the SYN 1-refill default
 N DEA
 S DEA=$$UP($P($G(^PSDRUG(+$G(DRUG),0)),U,3))
 I DEA="" Q 0
 I DEA["2" Q 1
 I DEA["A",DEA'["F" Q 1
 Q 0
 ;
HASRX(DFN,DRUG) ; $$ - true if patient already has this drug on file 52
 N IEN,RX
 S (IEN,RX)=0
 F  S IEN=$O(^PS(55,+$G(DFN),"P",IEN)) Q:+IEN=0  D  Q:RX
 . S RX=+$G(^PS(55,DFN,"P",IEN,0))
 . I RX<1 S RX=0 Q
 . I +$P($G(^PSRX(RX,0)),U,6)'=+$G(DRUG) S RX=0
 Q $S(RX>0:1,1:0)
 ;
REFIND(ROOT,IEN,REF,TYPE) ; $$ - entry index for a same-bundle reference
 N ERIEN,ID,HIT
 S REF=$G(REF),TYPE=$G(TYPE)
 I REF="" Q 0
 I REF["urn:uuid:" S ID=$P(REF,"urn:uuid:",2)
 E  I REF["/" S ID=$P(REF,"/",$L(REF,"/"))
 E  S ID=REF
 S ID=$P(ID,";",1)
 S (ERIEN,HIT)=0
 F  S ERIEN=$O(@ROOT@(IEN,"json","entry",ERIEN)) Q:+ERIEN=0  D  Q:HIT
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"resource","resourceType"))'=TYPE Q
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"fullUrl"))=REF S HIT=ERIEN Q
 . I $G(@ROOT@(IEN,"json","entry",ERIEN,"resource","id"))=ID S HIT=ERIEN Q
 Q +HIT
 ;
LOADED(ROOT,IEN,RIEN,TYPE,RX,RXN,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Medication",TYPE,"loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Medication",RIEN,"rx")=+RX
 S @ROOT@(IEN,"load","Medication",RIEN,"rxnorm")=$G(RXN)
 S @ROOT@(IEN,"load","Medication",RIEN,"engine")="C0FW"
 Q
 ;
SKIP(ROOT,IEN,RIEN,TYPE,DRUG,RXN,MSG,RETURN) ; Record skip
 D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Medication",TYPE,$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Medication",RIEN,"drugIen")=+DRUG
 S @ROOT@(IEN,"load","Medication",RIEN,"rxnorm")=$G(RXN)
 Q
 ;
ERR(ROOT,IEN,RIEN,TYPE,MSG,RETURN) ; Record error
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Medication",$G(TYPE),$G(MSG),.RETURN)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
