C0FMAM ; VEHU/Codex - file screening mammography V CPT for CMS125 ;Sep 24, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 24, 2026
 ;
 ; P2 enrichment: Synthea cohort often lacks in-window mammography. File a
 ; completed screening mammography V CPT on an existing visit (or create a
 ; thin visit) so C0FHIRP PROCTXT emits SCT 24623002.
 ;
 Q
 ;
GO(LO,HI) ; File mammo for DFN range (default 1-14)
 N DFN
 S LO=+$G(LO,1),HI=+$G(HI,50)
 F DFN=LO:1:HI I $D(^DPT(DFN,0)) D DFN(DFN)
 Q
 ;
DFN(DFN) ; File one screening mammography in CY2026 if female / unknown
 N CPTIEN,FMDT,NAME,SEX,VISIT
 S DFN=+$G(DFN) Q:DFN<1
 I $G(U)="" S U="^"
 S SEX=$P($G(^DPT(DFN,0)),U,2)
 I SEX="M" W "skip male DFN=",DFN,! Q
 I $$HASMAM(DFN) W "already has 2025-2026 mammo DFN=",DFN,! Q
 S FMDT=3260315.1 ; 2026-03-15
 S VISIT=$$VISIT(DFN,FMDT) I VISIT<1 W "no visit DFN=",DFN,! Q
 S NAME="Screening mammography"
 S CPTIEN=$$ENSURECPT^C0FWPRC("77067",NAME)
 I CPTIEN<1 S CPTIEN=$$ENSURECPT^C0FWPRC("24623002",NAME)
 I CPTIEN<1 D  ; seed OS5 hybrid like Synthea
 . S CPTIEN=$$ENSURECPT^C0FWPRC("77067M",NAME)
 I CPTIEN<1 W "no CPT seed DFN=",DFN,! Q
 I $$DIRECT^C0FWPRC(VISIT,CPTIEN) D
 . ; stamp narrative into V CPT provider narrative if present
 . N IEN S IEN=$O(^AUPNVCPT("AD",VISIT,""),-1)
 . I IEN,$D(^AUPNVCPT(IEN,0)) S $P(^AUPNVCPT(IEN,0),U,4)="" ; no POV ptr needed
 . ; Ensure name surfaces: store in CPT file display if blank
 . I $P($G(^ICPT(CPTIEN,0)),U,2)="" S $P(^ICPT(CPTIEN,0),U,2)=NAME
 . W "mammo filed DFN=",DFN," visit=",VISIT," cptien=",CPTIEN,!
 E  W "DIRECT failed DFN=",DFN,!
 Q
 ;
HASMAM(DFN) ; $$ - recent mammo V CPT text/code already present
 N DA,HIT,N,X0
 S HIT=0,DA=0
 F  S DA=$O(^AUPNVCPT("C",DFN,DA)) Q:'DA  D  Q:HIT
 . S X0=$G(^AUPNVCPT(DA,0))
 . S N=$$UP^XLFSTR($P($G(^ICPT(+X0,0)),U,2))
 . I N["MAMMOG",$P(X0,U,3)>3250000 S HIT=1
 Q HIT
 ;
VISIT(DFN,FMDT) ; $$ - prefer existing visit on/near date; else newest visit
 N V,X0,BEST,DT
 S BEST=0,V=0
 F  S V=$O(^AUPNVSIT("C",DFN,V)) Q:'V  D
 . S X0=$G(^AUPNVSIT(V,0)),DT=+X0
 . I DT>3250101,DT<3270101 S BEST=V
 I BEST Q BEST
 S V=$O(^AUPNVSIT("C",DFN,""),-1)
 Q +V
 ;
