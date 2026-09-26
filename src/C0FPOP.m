C0FPOP ; VEHU/Codex - seed quality POP for dashboard DFNs ;Sep 24, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 24, 2026
 ;
 ; Ensure curated POP exists for active measures on DFNs 1-14 so official
 ; reeval has someone to score. Flags start zero; REEVAL fills from CQL.
 ;
 Q
 ;
GO ; Seed all active dashboard measures for DFNs 1-14
 N CMS,DFN,U
 S U="^"
 F CMS="CMS165v14","CMS122v14","CMS125v14","CMS130v14","CMS138v14","CMS2v15" D SEED(CMS)
 Q
 ;
SEED(CMS) ;
 N DFN
 W "SEED ",CMS,!
 F DFN=1:1:14 I $D(^DPT(DFN,0)) D
 . ; Keep existing CQL flags if present; only create missing POP rows
 . I $D(^C0FQUAL("POP",CMS,DFN)) Q
 . D SETPOP^C0FQUAL(CMS,DFN,0,0,0,0,"dashboard-seed","seed")
 . W "  +DFN ",DFN,!
 Q
 ;
