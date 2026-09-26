C0FWALG ; VEHU/Codex - C0FW allergy writeback adapter ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File one FHIR AllergyIntolerance
 N ALG,DFN,DTM,GNT,ORY,SYM,TMP,TYPE,USER
 I $G(ROOT)="" D ERR(ROOT,IEN,RIEN,"Missing graph root",.RETURN) Q
 I $G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="AllergyIntolerance" D ERR(ROOT,IEN,RIEN,"Resource is not AllergyIntolerance",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR(ROOT,IEN,RIEN,"No DFN linked to graph row",.RETURN) Q
 I $$VERERR(ROOT,IEN,RIEN) D SKIP(ROOT,IEN,RIEN,0,"AllergyIntolerance is entered in error",.RETURN) Q
 S ALG=$$ALG(ROOT,IEN,RIEN)
 I ALG<1 D ERR(ROOT,IEN,RIEN,"Unable to resolve allergen in ^GMRD(120.82)",.RETURN) Q
 I $$HASALG(DFN,ALG) D SKIP(ROOT,IEN,RIEN,ALG,"Allergy already filed for patient",.RETURN) Q
 S USER=$$DUZ^C0FWCTX()
 S DTM=$$RECDT(ROOT,IEN,RIEN)
 I DTM<1 S DTM=$$NOW^XLFDT
 S TYPE=$$ALGTYP(ROOT,IEN,RIEN,ALG)
 S SYM=$$SYMPT(ROOT,IEN,RIEN)
 S TMP=$NA(^TMP("C0FWALG",$J))
 K @TMP
 S @TMP@("GMRAGNT")=$P($G(^GMRD(120.82,ALG,0)),U)_U_ALG_";GMRD(120.82,"
 S @TMP@("GMRATYPE")=TYPE
 S @TMP@("GMRANATR")="A"
 S @TMP@("GMRAORIG")=USER
 S @TMP@("GMRAORDT")=DTM
 S @TMP@("GMRACHT",0)=1
 S @TMP@("GMRACHT",1)=$$NOW^XLFDT
 S @TMP@("GMRAOBHX")="h"
 I SYM>0 D
 . S @TMP@("GMRASYMP",0)=1
 . S @TMP@("GMRASYMP",1)=SYM_U_$P($G(^GMRD(120.83,SYM,0)),U)
 D UPDATE^GMRAGUI1(0,DFN,TMP)
 K @TMP
 I +$G(ORY)=-1 D ERR(ROOT,IEN,RIEN,"GMRAGUI1 allergy filing failed: "_$P($G(ORY),U,2,99),.RETURN) Q
 D LOADED(ROOT,IEN,RIEN,$$ALG(ROOT,IEN,RIEN),$$SYMPT(ROOT,IEN,RIEN),"Allergy filed through GMRAGUI1",.RETURN)
 Q
 ;
VERERR(ROOT,IEN,RIEN) ; $$ - true if FHIR says entered-in-error
 N CODE
 S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","verificationStatus","coding",1,"code"))
 Q $S($$UP(CODE)="ENTERED-IN-ERROR":1,1:0)
 ;
ALG(ROOT,IEN,RIEN) ; $$ - allergen ien from FHIR code text/display
 N CODE,TXT
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display"))
 S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 Q $$ALGIEN(CODE,TXT)
 ;
ALGIEN(CODE,TXT) ; $$ - local allergen ien
 N IEN,X
 S X=$$CANON($G(TXT))
 I X'="" S IEN=+$O(^GMRD(120.82,"B",X,0)) I IEN>0 Q IEN
 I X["EGG" S IEN=+$O(^GMRD(120.82,"B","EGGS",0)) I IEN>0 Q IEN
 I X["MILK"!(X["DAIRY") S IEN=+$O(^GMRD(120.82,"B","DAIRY PRODUCTS",0)) I IEN>0 Q IEN
 I X["FISH" S IEN=+$O(^GMRD(120.82,"B","FISH",0)) I IEN>0 Q IEN
 I X["SHELL" S IEN=+$O(^GMRD(120.82,"B","SHELL FISH",0)) I IEN>0 Q IEN
 I X["POLLEN" S IEN=+$O(^GMRD(120.82,"B","POLLEN",0)) I IEN>0 Q IEN
 Q +$O(^GMRD(120.82,"B","OTHER ALLERGY/ADVERSE REACTION",0))
 ;
CANON(TXT) ; $$ - uppercase display without common SNOMED suffix
 N X
 S X=$$UP($G(TXT))
 I X[" (" S X=$P(X," (",1)
 Q X
 ;
ALGTYP(ROOT,IEN,RIEN,ALG) ; $$ - allergy package type D/F/O
 N CAT,TYPE
 S CAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",1))
 S CAT=$$UP(CAT)
 I CAT="FOOD" Q "F"
 I CAT="MEDICATION" Q "D"
 S TYPE=$P($G(^GMRD(120.82,+$G(ALG),0)),U,2)
 I TYPE["D" Q "D"
 I TYPE["F" Q "F"
 Q "O"
 ;
SYMPT(ROOT,IEN,RIEN) ; $$ - first reaction manifestation mapped to local symptom
 N SIEN,TXT,X
 S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reaction",1,"manifestation",1,"text"))
 I TXT="" S TXT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","reaction",1,"manifestation",1,"coding",1,"display"))
 S X=$$CANON(TXT)
 I X'="" S SIEN=+$O(^GMRD(120.83,"B",X,0)) I SIEN>0 Q SIEN
 I X["WHEAL"!(X["HIVE") S SIEN=+$O(^GMRD(120.83,"B","HIVES",0)) I SIEN>0 Q SIEN
 Q 0
 ;
RECDT(ROOT,IEN,RIEN) ; $$ - recorded date/time as FileMan
 N DT
 S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","recordedDate"))
 I DT="" S DT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","onsetDateTime"))
 Q $$FHIRTFM^C0FWFUTL(DT)
 ;
HASALG(DFN,ALG) ; $$ - true if patient already has this allergen
 N DA,GNT
 S DA=0
 F  S DA=$O(^GMR(120.8,"B",+$G(DFN),DA)) Q:DA<1  D  Q:$G(GNT)
 . I $P($G(^GMR(120.8,DA,0)),U,3)=(+$G(ALG)_";GMRD(120.82,") S GNT=1
 Q +$G(GNT)
 ;
LOADED(ROOT,IEN,RIEN,ALG,SYM,MSG,RETURN) ; Record loaded status
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Allergy","AllergyIntolerance","loaded",$G(MSG),.RETURN)
 S @ROOT@(IEN,"load","Allergy",RIEN,"allergenIen")=+ALG
 I $G(SYM)'="" S @ROOT@(IEN,"load","Allergy",RIEN,"symptomIen")=+SYM
 Q
 ;
SKIP(ROOT,IEN,RIEN,ALG,MSG,RETURN) ; Record skipped status
 D SKIP^C0FWSTAT(ROOT,IEN,RIEN,"Allergy","AllergyIntolerance",$G(MSG),.RETURN)
 I +$G(ALG)>0 S @ROOT@(IEN,"load","Allergy",RIEN,"allergenIen")=+ALG
 Q
 ;
ERR(ROOT,IEN,RIEN,MSG,RETURN) ; Record error status
 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Allergy","AllergyIntolerance",$G(MSG),.RETURN)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
