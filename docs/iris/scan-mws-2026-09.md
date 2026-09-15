# IRIS portability scan

Scanned 22 routines in: /tmp/mws/web

| Construct | Class | Hits | Files | IRIS note |
|---|---|---:|---|---|
| $ZCMDLINE | rewrite | 0 | — | no IRIS equivalent; entry args must come from JOB params or a driver |
| ZSYSTEM | shim | 3 | _webreq.m, _webtest.m | IRIS: $ZF(-100,...); wrap in a $$OS^shim |
| PIPE device | shim | 10 | _webrsp.m, _webtest.m, _webutils.m | IRIS command pipes use |CPIPE|/OPEN cmd syntax; wrap OPEN/USE/CLOSE |
| $ZTRAP | portable* | 0 | — | supported on IRIS but unwind semantics differ from GT.M ($ETRAP-style); verify handlers |
| $ETRAP | portable | 9 | _webapi.m, _webreq.m, _webtest.m | same on IRIS |
| $ZTRNLNM | shim | 1 | _webreq.m | env lookup; IRIS: $SYSTEM.Util.GetEnviron() |
| $ZSEARCH | shim | 0 | — | file glob; IRIS: %File:FileSetFunc or $ZSEARCH exists on IRIS (different reset rules) |
| $ZF non-call | shim | 0 | — | GT.M external call table vs IRIS $ZF(-100) |
| $ZB/$ZA device | portable* | 4 | _webreq.m, _webutils.m | read-terminator checks; IRIS supports $ZB with device differences |
| $ZCHSET/$ZCONVERT | shim | 2 | _webutils.m | UTF-8 handling differs; IRIS $ZCONVERT signature differs |
| $ZDATE | portable* | 0 | — | IRIS $ZDATE exists, format codes differ |
| $ZUT/$ZH highres | shim | 0 | — | IRIS: $ZTIMESTAMP-derived microseconds |
| ZHALT | shim | 0 | — | IRIS HALT has no exit status; use $SYSTEM.Process.Terminate |
| ZGOTO | rewrite | 1 | _webreq.m | no IRIS equivalent; restructure control flow |
| ZLINK/ZRUPDATE | shim | 1 | _webapi.m | dev-time routine reload; IRIS auto-compiles from .int/.mac — belongs in tooling, not product code |
| JOB command | portable* | 2 | _webtest.m | JOB portable; GT.M-specific jobparams (STARTUP, PASSCURLVN...) are not |
| OPEN w/ params | portable* | 22 | _webapi.m, _webreq.m, _webrsp.m, _webtest.m, _webutils.m | device parameter lists differ (newversion/ochset vs IRIS keywords); audit each |
| extended global ref | shim | 0 | — | IRIS uses ^|"ns"| syntax too but ns naming differs |
| $VIEW/VIEW | rewrite | 4 | _webtest.m | implementation-specific |
| %ZTLOAD (TaskMan) | portable | 0 | — | VistA Kernel API — portable wherever Kernel runs (IRIS ships Kernel in VistA distros) |
| $ORDER 2-arg reverse etc. | portable | 0 | — | standard |
| $ZPIECE/$ZLENGTH | shim | 0 | — | byte-oriented variants; IRIS is char-oriented — usually replace with standard forms |
| $ZINTERRUPT | rewrite | 0 | — | signal handling differs entirely |


## ZSYSTEM (shim) — 3 hits

- `_webreq.m:33` `. I $T(JOBEXAM^ZSY)]"" S $ZINT="I $$JOBEXAM^ZSY($ZPOS),$$JOBEXAM^%webreq($ZPOS)"`
- `_webreq.m:119` `I $T(JOBEXAM^ZSY)]"" S $ZINT="I $$JOBEXAM^ZSY($ZPOS),$$JOBEXAM^%webreq($ZPOS)"`
- `_webtest.m:359` `zsy "mkdir -p /tmp/foo"`

## PIPE device (shim) — 10 hits

- `_webrsp.m:351` `O "D":(shell="/bin/sh":command="gzip "_file:parse):0:"pipe"`
- `_webtest.m:25` `open "p":(command="$gtm_dist/mupip stop "_myJob)::"pipe"`
- `_webtest.m:155` `open "p":(command="$gtm_dist/mupip stop "_gzipflagjob)::"pipe"`
- `_webtest.m:297` `open "p":(command="$gtm_dist/mupip intrpt "_myJob)::"pipe"`
- `_webtest.m:460` `open "p":(command="$gtm_dist/mupip stop "_passwdJob)::"pipe"`
- `_webtest.m:508` `open "p":(command="rm test.html")::"pipe"`
- `_webtest.m:532` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webtest.m:567` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webtest.m:590` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webutils.m:140` `. O D:(shell="/bin/sh":comm="date -u +'%a, %d %b %Y %H:%M:%S %Z'|sed 's/UTC/GMT/g'")::"pipe"`

## $ETRAP (portable) — 9 hits

- `_webapi.m:23` `S $ETRAP="S $ECODE="""" Q"`
- `_webapi.m:311` `N $ET S $ET="G FILESYSE"`
- `_webreq.m:104` `N $ET S $ET="BREAK"`
- `_webreq.m:152` `N $ET S $ET="G ETSOCK^%webreq"`
- `_webreq.m:205` `S $ETRAP="G ETCODE^%webreq"`
- `_webreq.m:208` `S $ETRAP="G ETSOCK^%webreq"`
- `_webreq.m:281` `S $ETRAP="G ETBAIL^%webreq"`
- `_webreq.m:302` `S $ETRAP="Q:$ESTACK&$QUIT 0 Q:$ESTACK  S $ECODE="""" G NEXT",$ECODE=",U-UNWIND,"`
- `_webtest.m:118` `. n $et,$es s $et="s ec=$ec,$ec="""""`

## $ZTRNLNM (shim) — 1 hits

- `_webreq.m:122` `S %="",@("%=$ZTRNLNM(""REMOTE_HOST"")") S:$L(%) IO("IP")=%`

## $ZB/$ZA device (portable*) — 4 hits

- `_webreq.m:66` `. i $ZA\8196#2=1 W *-2  ; job failed to clear bit`
- `_webreq.m:238` `F RETRY=1:1 R X:1 D:HTTPLOG LOGRAW(X) S LINE=LINE_X Q:$A($ZB)=13  Q:RETRY>10`
- `_webreq.m:337` `S ^%webhttp("log",DT,$J,ID,"raw",LN,"ZB")=$A($ZB)`
- `_webutils.m:28` `. N VAL  S VAL=$ZA(X,I)  ; byte value (0-255)`

## $ZCHSET/$ZCONVERT (shim) — 2 hits

- `_webutils.m:14` `I $L($SY,":")=2 Q $ZCONVERT(X,"O","URL")  ; Cache`
- `_webutils.m:36` `I $L($SY,":")=2 Q $ZCONVERT(X,"I","URL")  ; Cache`

## ZGOTO (rewrite) — 1 hits

- `_webreq.m:230` `I %WOS="GT.M"&$G(HTTPLOG) ZGOTO 0:NEXT^%webreq ; unlink all routines; only for debug mode`

## ZLINK/ZRUPDATE (shim) — 1 hits

- `_webapi.m:28` `ZLINK RN`

## JOB command (portable*) — 2 hits

- `_webtest.m:19` `job start^%webreq(55728,,,,1):(IN="/dev/null":OUT="/dev/null":ERR="/dev/null"):5`
- `_webtest.m:36` `job start^%webreq(55729,1,,,1):(IN="/dev/null":OUT="/dev/null":ERR="/dev/null"):5`

## OPEN w/ params (portable*) — 22 hits

- `_webapi.m:25` `O %F:(newversion:noreadonly:blocksize=2048:recordsize=2044) U %F`
- `_webapi.m:314` `I ISGTM O PATH:(REWIND:READONLY:FIXED:CHSET="M")`
- `_webapi.m:318` `I ISCACHE O PATH:("RU"):0  E  S POP=1  ; Cache must have a timeout; U = undefined.`
- `_webreq.m:43` `I %WOS="CACHE" O TCPIO:(:TCPPORT:"ACT"):15 E  U 0 W !,"error cannot open port "_TCPPORT Q`
- `_webreq.m:44` `I %WOS="GT.M" O TCPIO:(LISTEN=TCPPORT_":TCP":delim=$C(13,10):attach="server"):15:"socket" E  U 0 W !,"error ca`
- `_webrsp.m:335` `o file:(newversion:stream:nowrap:chset="M")`
- `_webrsp.m:351` `O "D":(shell="/bin/sh":command="gzip "_file:parse):0:"pipe"`
- `_webrsp.m:355` `o file_".gz":(readonly:fixed:nowrap:recordsize=255:chset="M"):0`
- `_webtest.m:25` `open "p":(command="$gtm_dist/mupip stop "_myJob)::"pipe"`
- `_webtest.m:155` `open "p":(command="$gtm_dist/mupip stop "_gzipflagjob)::"pipe"`
- `_webtest.m:291` `open "sock":(connect="127.0.0.1:55728:TCP":attach="client"):1:"socket"`
- `_webtest.m:297` `open "p":(command="$gtm_dist/mupip intrpt "_myJob)::"pipe"`
- `_webtest.m:348` `open "sock":(connect="127.0.0.1:55728:TCP":attach="client"):1:"socket"`
- `_webtest.m:361` `open "/tmp/foo/boo.html":(newversion)`
- `_webtest.m:386` `open "/tmp/index.html":(newversion)`
- `_webtest.m:460` `open "p":(command="$gtm_dist/mupip stop "_passwdJob)::"pipe"`
- `_webtest.m:495` `open "test.html":(newversion)`
- `_webtest.m:508` `open "p":(command="rm test.html")::"pipe"`
- `_webtest.m:532` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webtest.m:567` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webtest.m:590` `open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"`
- `_webutils.m:140` `. O D:(shell="/bin/sh":comm="date -u +'%a, %d %b %Y %H:%M:%S %Z'|sed 's/UTC/GMT/g'")::"pipe"`

## $VIEW/VIEW (rewrite) — 4 hits

- `_webtest.m:15` `VIEW "TRACE":1:"^%wtrace"`
- `_webtest.m:32` `VIEW "TRACE":0:"^%wtrace"`
- `_webtest.m:132` `view "nobadchar"`
- `_webtest.m:134` `view "badchar"`
