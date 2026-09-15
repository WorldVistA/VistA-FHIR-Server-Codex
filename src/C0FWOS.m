C0FWOS ; VEN/GPL - OS/platform shims (IRIS portability audit 2026-09) ;
 ;;1.0;C0FW;;Sep 9, 2026;Build 1
 ; Platform-conditional wrappers so product routines carry no
 ; GT.M-specific constructs. Mirrors the M-Web-Server %WOS pattern:
 ; $P($SYSTEM,",")=47 -> GT.M/YottaDB, else Cache/IRIS family.
 ; Platform-specific syntax lives inside XECUTE strings so each side
 ; compiles cleanly on the other. See docs/iris/IRIS_PORTABILITY_AUDIT_2026-09.md
 Q
 ;
ISGTM() ; $$ - true when running on GT.M/YottaDB
 Q $P($SYSTEM,",")=47
 ;
ENV(NAME) ; $$ - environment variable value ("" if unset)
 N VAL S VAL=""
 I $$ISGTM() X "S VAL=$ZTRNLNM(NAME)" Q VAL
 X "S VAL=$SYSTEM.Util.GetEnviron(NAME)"
 Q VAL
 ;
FOPENR(IO,SEC) ; $$ - open file IO read-only with timeout; 1 on success
 ; GT.M: READONLY:NOWRAP device params; IRIS: "R" mode string.
 ; (No EXCEPTION= on OPEN - STACKOFLOWs on this GT.M during READ loops.)
 N OK S OK=0
 I $$ISGTM() X "O IO:(READONLY:NOWRAP):SEC S OK=$T" Q OK
 X "O IO:(""R""):SEC S OK=$T"
 Q OK
 ;