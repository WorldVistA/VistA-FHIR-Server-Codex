C0FPSL ; VEHU/Codex - Problem Selection List JSON endpoints
 ;;0.1;C0FHIR PROJECT;;May 28, 2026
 ;
 ; Read-only endpoints for CPRS-style Problem Selection Lists:
;   /problemselection/lists
 ;   /problemselection/categories?duz=&clinic=&list=
 ;   /problemselection/problems?category=
 ;
 QUIT
 ;
wsLists(OUT,FILTER) ; GET problemselection/lists
 NEW TMP,ERR
 IF '$DATA(DT) NEW DIQUIET SET DIQUIET=1 DO DT^DICRW
 KILL OUT
 DO LISTS(.TMP,.FILTER)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
wsCategories(OUT,FILTER) ; GET problemselection/categories
 NEW TMP,ERR,LIST,DUZ0
 IF '$DATA(DT) NEW DIQUIET SET DIQUIET=1 DO DT^DICRW
 KILL OUT
 SET DUZ0=+$GET(FILTER("duz"))
 IF DUZ0>0 SET DUZ=DUZ0
 IF '$DATA(DUZ) SET DUZ=1
 IF '$DATA(DUZ(2)) SET DUZ(2)=0
 DO CATS(.TMP,.FILTER)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
wsProblems(OUT,FILTER) ; GET problemselection/problems?category=
 NEW TMP,ERR
 IF '$DATA(DT) NEW DIQUIET SET DIQUIET=1 DO DT^DICRW
 KILL OUT
 DO PROBS(.TMP,.FILTER)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
LISTS(OUT,FILTER) ; Build available Problem Selection Lists
 NEW I,CNT,NODE
 KILL OUT
 SET OUT("resourceType")="ProblemSelectionLists"
 SET CNT=0,I=0
 FOR  SET I=$ORDER(^GMPL(125,I)) QUIT:I'>0  DO
 . SET NODE=$GET(^GMPL(125,I,0)) QUIT:$PIECE(NODE,U)=""
 . SET CNT=CNT+1
 . SET OUT("lists",CNT,"id")=I
 . SET OUT("lists",CNT,"name")=$PIECE(NODE,U)
 . SET OUT("lists",CNT,"clinic")=$PIECE(NODE,U,3)
 . SET OUT("lists",CNT,"class")=$PIECE(NODE,U,4)
 . SET OUT("lists",CNT,"categoryCount")=$$CATCNT(I)
 SET OUT("count")=CNT
 QUIT
 ;
CATS(OUT,FILTER) ; Build categories for selected list
 NEW LIST,CLIN,SEQ,IFN,ITEM,CAT,CNT
 KILL OUT
 SET CLIN=+$GET(FILTER("clinic"))
 SET LIST=+$GET(FILTER("list"))
 IF LIST<1 SET LIST=+$$GET^XPAR("USR^LOC.`"_CLIN_"^DIV^SYS^PKG","ORQQPL SELECTION LIST",1)
 SET OUT("resourceType")="ProblemSelectionCategories"
 SET OUT("list","id")=LIST
 SET OUT("list","name")=$PIECE($GET(^GMPL(125,LIST,0)),U)
 SET OUT("clinic")=CLIN
 SET CNT=0,SEQ=0
 FOR  SET SEQ=$ORDER(^GMPL(125,"AD",LIST,SEQ)) QUIT:SEQ'>0  DO
 . SET IFN=0
 . FOR  SET IFN=$ORDER(^GMPL(125,"AD",LIST,SEQ,IFN)) QUIT:IFN'>0  DO
 . . SET ITEM=$GET(^GMPL(125,LIST,1,IFN,0))
 . . SET CAT=+$PIECE(ITEM,U) QUIT:CAT<1
 . . SET CNT=CNT+1
 . . SET OUT("categories",CNT,"id")=CAT
 . . SET OUT("categories",CNT,"name")=$PIECE($GET(^GMPL(125.11,CAT,0)),U)
 . . SET OUT("categories",CNT,"sequence")=SEQ
 . . SET OUT("categories",CNT,"subheader")=$PIECE(ITEM,U,3)
 . . SET OUT("categories",CNT,"showProblems")=$SELECT(+$PIECE(ITEM,U,4):"true",1:"false")
 SET OUT("count")=CNT
 QUIT
 ;
CATCNT(LIST) ; Count categories attached to one list
 NEW N,SEQ,IFN
 SET N=0,SEQ=0,LIST=+$GET(LIST)
 FOR  SET SEQ=$ORDER(^GMPL(125,"AD",LIST,SEQ)) QUIT:SEQ'>0  DO
 . SET IFN=0
 . FOR  SET IFN=$ORDER(^GMPL(125,"AD",LIST,SEQ,IFN)) QUIT:IFN'>0  SET N=N+1
 QUIT N
 ;
PROBS(OUT,FILTER) ; Build problems for one category
 NEW CAT,SEQ,IFN,ITEM,CNT,ICD,ICDSYS,ICDIEN
 KILL OUT
 SET CAT=+$GET(FILTER("category"))
 SET OUT("resourceType")="ProblemSelectionProblems"
 SET OUT("category","id")=CAT
 SET OUT("category","name")=$PIECE($GET(^GMPL(125.11,CAT,0)),U)
 IF CAT<1 DO  QUIT
 . SET OUT("error")="Missing or invalid query parameter: category"
 SET CNT=0,SEQ=0
 FOR  SET SEQ=$ORDER(^GMPL(125.11,"C",CAT,SEQ)) QUIT:SEQ'>0  DO
 . SET IFN=0
 . FOR  SET IFN=$ORDER(^GMPL(125.11,"C",CAT,SEQ,IFN)) QUIT:IFN'>0  DO
 . . SET ITEM=$GET(^GMPL(125.11,CAT,1,IFN,0)) QUIT:ITEM=""
 . . SET ICD=$PIECE(ITEM,U,4)
 . . SET ICDSYS=$$ICDSYS(ICD)
 . . SET ICDIEN=+$$ICDIEN(ICD,ICDSYS)
 . . SET CNT=CNT+1
 . . SET OUT("problems",CNT,"id")=IFN
 . . SET OUT("problems",CNT,"lexIen")=$PIECE(ITEM,U)
 . . SET OUT("problems",CNT,"sequence")=SEQ
 . . SET OUT("problems",CNT,"display")=$PIECE(ITEM,U,3)
 . . SET OUT("problems",CNT,"icdCode")=ICD
 . . SET OUT("problems",CNT,"icdSystem")=ICDSYS
 . . SET OUT("problems",CNT,"icdIen")=ICDIEN
 . . SET OUT("problems",CNT,"snomedCode")=$PIECE(ITEM,U,5)
 . . SET OUT("problems",CNT,"snomedDesignationCode")=$PIECE(ITEM,U,6)
 . . SET OUT("problems",CNT,"fileable")=$SELECT(ICD'="":"true",1:"false")
 SET OUT("count")=CNT
 QUIT
 ;
ICDSYS(ICD) ; Return ICD coding system abbreviation for first code
 NEW CODE,PTR,SYS
 SET CODE=$PIECE($GET(ICD),"/")
 QUIT:CODE="" ""
 SET PTR=+$$CODECS^ICDEX(CODE,80,$GET(DT))
 SET SYS=$$SAB^ICDEX(PTR,$GET(DT))
 QUIT $SELECT(SYS'="":SYS,1:"ICD")
 ;
ICDIEN(ICD,SYS) ; Return ICD diagnosis IEN for first code
 NEW CODE
 SET CODE=$PIECE($GET(ICD),"/")
 QUIT:CODE="" ""
 QUIT +$$ICDDX^ICDEX(CODE,$GET(DT),$GET(SYS))
 ;
