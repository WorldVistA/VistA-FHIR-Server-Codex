C0FR69 ; VEHU/Codex - repair R69 HTN → I10 + active problem ;Sep 24, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 24, 2026
 ;
 ; One-shot repair for CMS165: Synthea HTN filed as R69 (Illness, unspecified)
 ; because stale Lexicon / SYNDHP61 invent. Prefer I10 + SCT 59621000 on an
 ; active problem-list row. Does not loosen C0X presets.
 ;
 Q
 ;
DFN(DFN) ; Repair one patient. W ! messages.
 N I10,MSG,NARR,PROB,R69,USER
 S DFN=+$G(DFN) I DFN<1 W "need DFN",! Q
 I $G(U)="" S U="^"
 D DUZ^C0FWCTX()
 S R69=+$$ICDDX^ICDEX("R69.",30)
 S I10=+$$ICDDX^ICDEX("I10.",30)
 I R69<1!(I10<1) W "ICD lookup failed R69=",R69," I10=",I10,! Q
 W "DFN=",DFN," R69=",R69," I10=",I10,!
 S USER=$$USER^C0FWENC()
 D FIXPOV(DFN,R69,I10)
 S PROB=$$FINDHTN(DFN,R69,I10)
 I PROB>0 D  Q
 . D FIXPROB(PROB,I10)
 . W "fixed problem IEN=",PROB,!
 S NARR="Essential hypertension"
 S PROB=$$ADDPROB^C0FWCON(.MSG,DFN,I10,NARR,$$NOW^XLFDT,USER,59621000,"")
 I PROB<1 W "ADDPROB failed: ",$G(MSG),! Q
 W "added problem IEN=",PROB,!
 Q
 ;
FIXPOV(DFN,R69,I10) ; V POV .01 R69 + HTN narrative → I10
 N NARR,POV,X0
 S POV=0
 F  S POV=$O(^AUPNVPOV(POV)) Q:'POV  D
 . S X0=$G(^AUPNVPOV(POV,0))
 . Q:+$P(X0,U,2)'=DFN
 . Q:+$P(X0,U)'=R69
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,4),0)),U))
 . Q:NARR'["HYPERTENS"
 . S $P(^AUPNVPOV(POV,0),U)=I10
 . W "POV ",POV," R69→I10 narr=",$E(NARR,1,40),!
 Q
 ;
FINDHTN(DFN,R69,I10) ; $$ - problem IEN for HTN (prefer existing)
 N IEN,NARR,SCT,X0,HIT
 S (IEN,HIT)=0
 F  S IEN=$O(^AUPNPROB("AC",DFN,IEN)) Q:'IEN  D  Q:HIT
 . S X0=$G(^AUPNPROB(IEN,0))
 . S SCT=$P($G(^AUPNPROB(IEN,800)),U)
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,5),0)),U))
 . I SCT=59621000!(SCT=38341003)!(SCT=1201005) S HIT=IEN Q
 . I NARR["HYPERTENS" S HIT=IEN Q
 . I +$P(X0,U)=I10 S HIT=IEN Q
 . I +$P(X0,U)=R69,NARR["HYPERTENS" S HIT=IEN Q
 Q +HIT
 ;
FIXPROB(PROB,I10) ; Point problem at I10, active, SCT 59621000
 N SCT
 S $P(^AUPNPROB(PROB,0),U)=I10
 S $P(^AUPNPROB(PROB,0),U,12)="A" ; status active
 ; clear date resolved (1.07) if present
 I $D(^AUPNPROB(PROB,1)) S $P(^AUPNPROB(PROB,1),U,7)=""
 S SCT=$P($G(^AUPNPROB(PROB,800)),U)
 I SCT="" S $P(^AUPNPROB(PROB,800),U)=59621000
 Q
 ;
SCAN(LO,HI) ; Scan DFN range; repair when R69 HTN POV without active I10
 N DFN,I10,R69,NEED
 S LO=+$G(LO,1),HI=+$G(HI,50)
 I $G(U)="" S U="^"
 S R69=+$$ICDDX^ICDEX("R69.",30),I10=+$$ICDDX^ICDEX("I10.",30)
 F DFN=LO:1:HI I $D(^DPT(DFN,0)) D
 . S NEED=$$NEED(DFN,R69,I10)
 . I NEED'="" W "NEED DFN=",DFN," ",NEED,! D DFN(DFN)
 Q
 ;
NEED(DFN,R69,I10) ; $$ - reason string if repair needed, else ""
 N IEN,NARR,POV,SCT,X0,HASI10,HASHTN
 S (HASI10,HASHTN)=0
 S IEN=0 F  S IEN=$O(^AUPNPROB("AC",DFN,IEN)) Q:'IEN  D
 . S X0=$G(^AUPNPROB(IEN,0))
 . S SCT=$P($G(^AUPNPROB(IEN,800)),U)
 . I $P(X0,U,12)'="A" Q
 . I +$P(X0,U)=I10!(SCT=59621000) S HASI10=1
 S POV=0 F  S POV=$O(^AUPNVPOV(POV)) Q:'POV  D
 . S X0=$G(^AUPNVPOV(POV,0))
 . Q:+$P(X0,U,2)'=DFN
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,4),0)),U))
 . I NARR["HYPERTENS" S HASHTN=1
 I HASHTN,'HASI10 Q "HTN-POV-no-active-I10-problem"
 Q ""
 ;
