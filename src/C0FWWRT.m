C0FWWRT ; VEHU/Codex - patient.fhir.write filing engine (CFH-WRITE-001) ;Sep 09, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 09, 2026
 ;
 ; Frozen contract: CPRS-on-FHIR/docs/specs/CFH-WRITE-001.md
 ; Shares the intake-graph append/index/link/load path with C0FWUPD, but:
 ;   - takes a decoded Bundle array (BROOT) instead of a JSON body string
 ;   - requires the patient to already exist in ^DPT (never registers)
 ;   - enforces requestId idempotency (^...("writeReq",REQID))
 ;   - returns the RETURN array unencoded for the C0RG envelope
 ;
 Q
 ;
WRITE(RETURN,DFN,ICN,BROOT,LOAD,RETG,REQID) ; $$ - file a clinical write bundle
 N ROOT,IEN,NEWROW,GR,GR1,LASTRIEN,CNT,ZI,HASPAT,BUNDLE,ARGS
 K RETURN
 S U="^"
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" D ERRO(.RETURN,"INTERNAL","Unable to open fhir-intake graph") Q 0
 ; -- patient must already exist in ^DPT
 S DFN=+$G(DFN)
 I DFN<1,$G(ICN)'="" S DFN=+$O(^DPT("AFICN",ICN,""))
 I DFN<1 D ERRO(.RETURN,"VALIDATION","payload.dfn or payload.icn required") Q 0
 I '$D(^DPT(DFN,0)) D ERRO(.RETURN,"NOT_FOUND","No patient with DFN "_DFN_"; patient.fhir.write never registers patients") Q 0
 ; -- bundle sanity
 I $G(@BROOT@("resourceType"))'="Bundle" D ERRO(.RETURN,"VALIDATION","payload.bundle must be a FHIR Bundle") Q 0
 I '$D(@BROOT@("entry")) D ERRO(.RETURN,"VALIDATION","payload.bundle has no entries") Q 0
 ; -- idempotency (requestId is required by the gateway)
 I $G(REQID)'="",$D(@ROOT@("writeReq",REQID)) D  Q 0
 . D ERRO(.RETURN,"DUPLICATE","requestId already processed: "_REQID_" ("_$G(@ROOT@("writeReq",REQID))_")")
 M GR1=@BROOT
 ; -- graph row: reuse the patient's row, or create one (patient exists in
 ;    ^DPT but has no intake graph yet)
 S IEN=$$DFN2IEN^C0FWFUTL(DFN),NEWROW=0
 I IEN<1 S IEN=$O(@ROOT@(" "),-1)+1,NEWROW=1
 I NEWROW D
 . ; New graph row: build local, full INDEX, then store (mirrors C0FWUPD)
 . M GR(IEN,"json")=GR1
 . S LASTRIEN=0
 . S (ZI,CNT)=0
 . F  S ZI=$O(GR1("entry",ZI)) Q:+ZI=0  S CNT=CNT+1
 . D INDEX^C0FWIDX(IEN,"GR")
 . M @ROOT@(IEN)=GR(IEN)
 E  D
 . ; Existing row: append only - never M-copy/reindex the whole graph
 . S LASTRIEN=$O(@ROOT@(IEN,"json","entry"," "),-1)
 . S HASPAT=$$HASPAT^C0FWLNK($NA(@ROOT@(IEN)))
 . S (ZI,CNT)=0
 . F  S ZI=$O(GR1("entry",ZI)) Q:+ZI=0  D
 . . I HASPAT,$G(GR1("entry",ZI,"resource","resourceType"))="Patient" Q
 . . S CNT=CNT+1
 . . M @ROOT@(IEN,"json","entry",LASTRIEN+CNT)=GR1("entry",ZI)
 . I CNT>0 D INDEXADD^C0FWIDX(IEN,LASTRIEN+1,LASTRIEN+CNT,ROOT)
 I CNT<1 D ERRO(.RETURN,"VALIDATION","No fileable entries in bundle (Patient resources are ignored on existing rows)") Q 0
 ; -- record the requestId only after a successful append
 I $G(REQID)'="" S @ROOT@("writeReq",REQID)="dfn="_DFN_";ien="_IEN_";entries="_(LASTRIEN+1)_"-"_(LASTRIEN+CNT)_";at="_$H
 ; -- same downstream sequence as C0FWUPD
 S BUNDLE=$$BUNDLE^C0FWIDX($NA(@ROOT@(IEN)))
 S ARGS("bundle")=BUNDLE
 S ARGS("firstEntry")=LASTRIEN+1
 S ARGS("lastEntry")=LASTRIEN+CNT
 S C0FWBUNDLE=BUNDLE
 D LNKPAT^C0FWLNK(IEN,DFN,.ICN,ROOT)
 S RETURN("dfn")=DFN
 S RETURN("ien")=IEN
 I $G(ICN)'="" S RETURN("icn")=ICN
 S RETURN("entriesReceived")=CNT
 S RETURN("firstEntry")=LASTRIEN+1
 S RETURN("lastEntry")=LASTRIEN+CNT
 I NEWROW S RETURN("createdGraph")=1
 I +$G(LOAD) D
 . S ARGS("load")=1
 . S RETURN("simulation")=0
 . D LOAD^C0FWDOM(.RETURN,IEN,.ARGS)
 E  D
 . S RETURN("loadStatus")="skipped"
 . S RETURN("simulation")=1
 . S RETURN("load","message")="simulation: entries staged in the intake graph, nothing filed"
 I +$G(RETG) D TXLOAD^C0FWIDX(.RETURN,IEN,LASTRIEN+1,LASTRIEN+CNT)
 I $T(INV^C0FWCAC)'="" D INV^C0FWCAC(IEN,ROOT)
 K C0FWBUNDLE
 Q 1
 ;
ERRO(RETURN,CODE,MSG) ; error shape consumed by the C0RG gateway shell
 S RETURN("error","code")=$G(CODE)
 S RETURN("error","message")=$G(MSG)
 Q
 ;
