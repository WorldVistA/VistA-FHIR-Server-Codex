C0FWBULK ; VEHU/Codex - C0FW directory bulk Synthea load ;Aug 07, 2026
 ;;0.1;C0FHIR PROJECT;;Aug 07, 2026
 ; Reads large JSON via OPEN into 12k chunks (avoids TEMP REC2BIG from ^TMP/FTG).
 Q
 ;
FILE(DIR,MAX) ; Load *.json Bundles from DIR via ADDJSON^C0FWADD (ICN dedupe)
 N ARGS,BCNT,BUF,DUP,ERR,FILE,GR1,JERR,MASK,OK,PCT,RETURN,ROOT,SKIP,STAT,SYNFILES
 S DIR=$G(DIR)
 I DIR="" W !,"Usage: D FILE^C0FWBULK(""/path/to/fhir""[,max])",! Q
 I $E(DIR,$L(DIR))="/" S DIR=$E(DIR,1,$L(DIR)-1)
 S MAX=+$G(MAX)
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I ROOT="" W !,"ERROR: fhir-intake graph not available",! Q
 K SYNFILES
 S MASK("*.json")=""
 S STAT=$$LIST^%ZISH(DIR,$NA(MASK),$NA(SYNFILES))
 I 'STAT W !,"ERROR: LIST^%ZISH failed for ",DIR,! Q
 S (BCNT,OK,DUP,ERR,SKIP)=0
 S FILE=""
 F  S FILE=$O(SYNFILES(FILE)) Q:FILE=""  D  Q:(MAX>0)&(BCNT'<MAX)
 . I FILE["Information" S SKIP=SKIP+1 Q
 . S BCNT=BCNT+1
 . W !,"[",BCNT,"] ",FILE," ... "
 . I $D(@ROOT@("filename",FILE)) D  Q
 . . W "duplicate (filename)"
 . . S DUP=DUP+1
 . K ARGS,GR1,RETURN,JERR,BUF
 . I '$$READJSON(DIR,FILE,.BUF) W "read-fail" S ERR=ERR+1 Q
 . D DECODE^XLFJSON("BUF","GR1","JERR")
 . I $D(JERR)!('$D(GR1("entry"))) W "json-fail" S ERR=ERR+1 Q
 . S ARGS("load")=1
 . S ARGS("filename")=FILE
 . D ADDJSON^C0FWADD(.ARGS,.GR1,.RETURN)
 . S PCT=$G(RETURN("status"))
 . I PCT="duplicate" W "duplicate icn=",$G(RETURN("icn"))," dfn=",$G(RETURN("dfn")) S DUP=DUP+1 Q
 . I PCT'="ok",$G(RETURN("patient","loadStatus"))="duplicate" W "duplicate" S DUP=DUP+1 Q
 . I +$G(RETURN("dfn"))>0 W "ok dfn=",RETURN("dfn")," icn=",$G(RETURN("icn"))," ien=",$G(RETURN("ien")) S OK=OK+1 Q
 . W "error status=",PCT," msg=",$G(RETURN("patient","message")),$G(RETURN("error","message"))
 . S ERR=ERR+1
 W !!,"C0FWBULK done dir=",DIR
 W !," processed=",BCNT," ok=",OK," duplicate=",DUP," error=",ERR," skippedInfo=",SKIP,!
 Q
 ;
READJSON(DIR,FILE,OUT) ; $$1 if OUT(1..n) filled with ≤12k chunks of FILE
 N EOF,IO,N,PATH,X
 K OUT
 S PATH=$G(DIR)_"/"_$G(FILE)
 I $G(FILE)="" Q 0
 S IO=PATH
 ; Platform-conditional open (READONLY:NOWRAP on GT.M, "R" on IRIS);
 ; no EXCEPTION= on OPEN — it STACKOFLOWs on this GT.M during READ loops.
 I '$$FOPENR^C0FWOS(IO,5) Q 0
 U IO
 S (N,EOF)=0
 F  Q:EOF  D
 . S X=""
 . R X#12000:5
 . I '$T!($ZEOF) S EOF=1
 . I X="" Q
 . S N=N+1,OUT(N)=X
 C IO
 U $P
 Q (N>0)
 ;
EOR
 ;