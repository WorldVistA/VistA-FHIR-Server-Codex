# IRIS portability scan

Scanned 72 routines in: /home/glilly/work/vista-stack/VistA-FHIR-Server-Codex/src, /home/glilly/work/vista-stack/rehmp/C0RG

| Construct | Class | Hits | Files | IRIS note |
|---|---|---:|---|---|
| $ZCMDLINE | rewrite | 0 | — | no IRIS equivalent; entry args must come from JOB params or a driver |
| ZSYSTEM | shim | 0 | — | IRIS: $ZF(-100,...); wrap in a $$OS^shim |
| PIPE device | shim | 1 | _WC.m | IRIS command pipes use |CPIPE|/OPEN cmd syntax; wrap OPEN/USE/CLOSE |
| $ZTRAP | portable* | 0 | — | supported on IRIS but unwind semantics differ from GT.M ($ETRAP-style); verify handlers |
| $ETRAP | portable | 4 | C0FHIR.m, C0FHIRWS.m, C0FWDOM.m, C0FWLAB.m | same on IRIS |
| $ZTRNLNM | shim | 2 | C0FHIRWS.m, C0FQUAL.m | env lookup; IRIS: $SYSTEM.Util.GetEnviron() |
| $ZSEARCH | shim | 0 | — | file glob; IRIS: %File:FileSetFunc or $ZSEARCH exists on IRIS (different reset rules) |
| $ZF non-call | shim | 0 | — | GT.M external call table vs IRIS $ZF(-100) |
| $ZB/$ZA device | portable* | 0 | — | read-terminator checks; IRIS supports $ZB with device differences |
| $ZCHSET/$ZCONVERT | shim | 0 | — | UTF-8 handling differs; IRIS $ZCONVERT signature differs |
| $ZDATE | portable* | 0 | — | IRIS $ZDATE exists, format codes differ |
| $ZUT/$ZH highres | shim | 0 | — | IRIS: $ZTIMESTAMP-derived microseconds |
| ZHALT | shim | 0 | — | IRIS HALT has no exit status; use $SYSTEM.Process.Terminate |
| ZGOTO | rewrite | 0 | — | no IRIS equivalent; restructure control flow |
| ZLINK/ZRUPDATE | shim | 0 | — | dev-time routine reload; IRIS auto-compiles from .int/.mac — belongs in tooling, not product code |
| JOB command | portable* | 0 | — | JOB portable; GT.M-specific jobparams (STARTUP, PASSCURLVN...) are not |
| OPEN w/ params | portable* | 4 | C0FWBULK.m, _WC.m | device parameter lists differ (newversion/ochset vs IRIS keywords); audit each |
| extended global ref | shim | 0 | — | IRIS uses ^|"ns"| syntax too but ns naming differs |
| $VIEW/VIEW | rewrite | 0 | — | implementation-specific |
| %ZTLOAD (TaskMan) | portable | 2 | C0FQRPT.m, C0FQUAL.m | VistA Kernel API — portable wherever Kernel runs (IRIS ships Kernel in VistA distros) |
| $ORDER 2-arg reverse etc. | portable | 0 | — | standard |
| $ZPIECE/$ZLENGTH | shim | 0 | — | byte-oriented variants; IRIS is char-oriented — usually replace with standard forms |
| $ZINTERRUPT | rewrite | 0 | — | signal handling differs entirely |


## PIPE device (shim) — 1 hits

- `_WC.m:80` `O D:(shell="/bin/sh":command=CMD:PARSE)::"PIPE" U D`

## $ETRAP (portable) — 4 hits

- `C0FHIR.m:217` `SET $ETRAP="SET $ECODE="""",VAL="""" QUIT"`
- `C0FHIRWS.m:122` `S $ETRAP="S $ECODE="""",OK=0 Q"`
- `C0FWDOM.m:58` `S $ETRAP="D DERR^C0FWDOM(ROOT,IEN,RIEN,DOMAIN,TYPE,.RETURN) S $ECODE="""" Q"`
- `C0FWLAB.m:116` `. . S $ETRAP="S TRY="""",$ECODE="""" Q"`

## $ZTRNLNM (shim) — 2 hits

- `C0FHIRWS.m:104` `S HOME=$ZTRNLNM("HOME")`
- `C0FQUAL.m:601` `SET HOME=$ZTRNLNM("HOME")`

## OPEN w/ params (portable*) — 4 hits

- `C0FWBULK.m:51` `O IO:(READONLY:NOWRAP):5`
- `_WC.m:61` `. O F:(NEWVERSION) U F`
- `_WC.m:80` `O D:(shell="/bin/sh":command=CMD:PARSE)::"PIPE" U D`
- `_WC.m:123` `I $D(PAYLOAD) O F C F:(DELETE)`

## %ZTLOAD (TaskMan) (portable) — 2 hits

- `C0FQRPT.m:226` `DO ^%ZTLOAD`
- `C0FQUAL.m:764` `DO ^%ZTLOAD`
