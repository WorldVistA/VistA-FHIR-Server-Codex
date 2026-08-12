C0FWUPD ; VEHU/Codex - C0FW /updatepatient handler ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
wsUpdatePatient(ARGS,BODY,RESULT) ; POST /updatepatient
 N CNT,DNX,ERR,GR,GR1,HAD,HASPAT,ICN,ID,IEN,JSON,LASTRIEN,NEWROW,RDFN,RETURN,RIEN,ROOT,USER,ZI
 S U="^"
 S HTTPRSP("mime")="application/json"
 S USER=$$DUZ^C0FWCTX()
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" D ERR(.RESULT,"GRAPH","Unable to open fhir-intake graph") Q 0
 S ID=$G(ARGS("id"))
 S (DNX,NEWROW,HAD)=0
 S IEN=+$G(ARGS("ien")) I IEN>0 S HAD=1
 I IEN<1 S DNX=+$G(ARGS("dfn")) I DNX>0 S HAD=1,IEN=$$DFN2IEN^C0FWFUTL(DNX)
 S ICN=$G(ARGS("icn")) I ICN="" S ICN=$G(ARGS("id"))
 I IEN<1,ICN'="" S HAD=1,IEN=$O(@ROOT@("POS","ICN",ICN,""))
 I IEN<1,DNX<1,ICN'="" S DNX=+$O(^DPT("AFICN",ICN,""))
 I IEN<1,DNX>0,$D(^DPT(DNX,0)) D
 . S IEN=$O(@ROOT@(" "),-1)+1
 . S NEWROW=1
 I IEN<1 D  Q 0
 . S HTTPERR=$S($G(HAD):404,1:400)
 . D ERR(.RESULT,$S($G(HAD):"NOT_FOUND",1:"VALIDATION"),$S($G(HAD):"Patient graph row not found",1:"Missing patient graph identifier"))
 I 'NEWROW,'$D(@ROOT@(IEN,"json","entry")) D  Q 0
 . S HTTPERR=404
 . D ERR(.RESULT,"NOT_FOUND","Patient graph row has no FHIR entries")
 I '$D(BODY) D  Q 0
 . S HTTPERR=400
 . D ERR(.RESULT,"VALIDATION","Empty request body")
 M JSON=BODY
 D DECODE^XLFJSON("JSON","GR1","ERR")
 I $D(ERR) D  Q 0
 . S HTTPERR=400
 . D ERR(.RESULT,"JSON","Unable to decode updatepatient JSON")
 I NEWROW D
 . ; New graph row: build local, full INDEX, then store
 . M GR(IEN,"json")=GR1
 . S LASTRIEN=0
 . S (ZI,CNT)=0
 . F  S ZI=$O(GR1("entry",ZI)) Q:+ZI=0  S CNT=CNT+1
 . D INDEX^C0FWIDX(IEN,"GR")
 . M @ROOT@(IEN)=GR(IEN)
 E  D
 . ; Existing row: append only — never M-copy/reindex the whole graph
 . ; (rpmsfhir DFN 55 is ~20k entries; full INDEX hung /updatepatient).
 . S LASTRIEN=$O(@ROOT@(IEN,"json","entry"," "),-1)
 . S HASPAT=$$HASPAT^C0FWLNK($NA(@ROOT@(IEN)))
 . S (ZI,CNT)=0
 . F  S ZI=$O(GR1("entry",ZI)) Q:+ZI=0  D
 . . I HASPAT,$G(GR1("entry",ZI,"resource","resourceType"))="Patient" Q
 . . S CNT=CNT+1
 . . S RIEN=LASTRIEN+CNT
 . . M @ROOT@(IEN,"json","entry",RIEN)=GR1("entry",ZI)
 . I CNT>0 D INDEXADD^C0FWIDX(IEN,LASTRIEN+1,LASTRIEN+CNT,ROOT)
 S RETURN("status")="ok"
 I ICN="" D
 . N DFR S DFR=$O(@ROOT@(IEN,"SPO",IEN,"DFN",""))
 . I DFR="" S DFR=$O(@ROOT@("SPO",IEN,"DFN",""))
 . I DFR'="" S ICN=$$DFN2ICN^C0FWFUTL(DFR)
 S RETURN("icn")=ICN
 S RETURN("ien")=IEN
 I NEWROW S RETURN("createdGraph")=1
 N BUNDLE S BUNDLE=$$BUNDLE^C0FWIDX($NA(@ROOT@(IEN)))
 S RETURN("bundle")=BUNDLE
 S ARGS("bundle")=BUNDLE
 S ARGS("firstEntry")=LASTRIEN+1
 S ARGS("lastEntry")=LASTRIEN+CNT
 S C0FWBUNDLE=BUNDLE
 S RDFN=$S(DNX>0:DNX,1:$O(@ROOT@("SPO",IEN,"DFN","")))
 I RDFN="" S RDFN=$O(@ROOT@(IEN,"SPO",IEN,"DFN",""))
 I RDFN'="" D LNKPAT^C0FWLNK(IEN,RDFN,.ICN,ROOT)
 I ICN'="" S RETURN("icn")=ICN
 I RDFN'="" D
 . I $G(ARGS("load"))="" S ARGS("load")=1
 . I +$G(ARGS("load"))=0 S RETURN("loadStatus")="skipped" Q
 . D LOAD^C0FWDOM(.RETURN,IEN,.ARGS)
 E  D
 . S RETURN("loadStatus")="skipped"
 . S RETURN("load","message")="No DFN resolved for updatepatient graph row"
 I $G(ARGS("returngraph"))=1 D TXLOAD^C0FWIDX(.RETURN,IEN,LASTRIEN+1,LASTRIEN+CNT)
 I $T(INV^C0FWCAC)'="" D INV^C0FWCAC(IEN,ROOT)
 K C0FWBUNDLE
 D ENCODE^XLFJSON("RETURN","RESULT")
 Q 1
 ;
ERR(RESULT,CODE,MESSAGE) ; Encode JSON error
 K OUT
 S OUT("status")="error"
 S OUT("error","code")=$G(CODE)
 S OUT("error","message")=$G(MESSAGE)
 D ENCODE^XLFJSON("OUT","RESULT")
 Q
 ;
