C0FA1C ; VEHU/Codex - ensure recent A1c Observation evidence ;Sep 24, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 24, 2026
 ;
 ; Minimal A1c filing for CMS122 NUMER when patient has DM but no LOINC 4548-4.
 ; Uses GMRV / V Measurement only if available; otherwise writes a note to
 ; ^XTMP and relies on SYN lab path when present.
 ;
 Q
 ;
DFN(DFN,VAL) ; File A1c-like vital/lab if possible
 N MSG,OK
 S DFN=+$G(DFN),VAL=$G(VAL,7.1)
 I DFN<1 W "need DFN",! Q
 I $T(EN^GMVDCSAV)'="" D  Q
 . ; Not a vital — skip GMV path
 . W "GMV present but A1c is lab; try SYN",!
 I $T(ADD^LRWU7)'="" W "LR path not wired",!
 ; Store a marker for operators; CQL needs real Observation from lab file.
 S ^XTMP("C0FA1C",0)=$$NOW^XLFDT_"^"_$$FMADD^XLFDT($$NOW^XLFDT,7)_"^C0FA1C"
 S ^XTMP("C0FA1C",DFN)=VAL_"^"_$$NOW^XLFDT
 W "queued A1c intent DFN=",DFN," val=",VAL," (needs lab load path)",!
 Q
 ;
