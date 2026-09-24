C0FDM ; VEHU/Codex - repair R69 diabetes → E11.9 + active problem ;Sep 24, 2026
 ;;0.1;C0FHIR PROJECT;;Sep 24, 2026
 ;
 ; CMS122 playbook (same shape as C0FR69 HTN): Synthea DM filed as R69 or
 ; legacy ICD-9 250.* only. Prefer E11.9 + SCT 44054006 on an active problem
 ; with onset in/before the measurement period. Does not loosen C0X presets.
 ;
 Q
 ;
DFN(DFN) ; Repair one patient
 N EICD,MSG,NARR,ON,PROB,R69,USER
 S DFN=+$G(DFN) I DFN<1 W "need DFN",! Q
 I $G(U)="" S U="^"
 D DUZ^C0FWCTX()
 S R69=+$$ICDDX^ICDEX("R69.",30)
 S EICD=+$$ICDDX^ICDEX("E11.9",30)
 I EICD<1 S EICD=+$$ICDDX^ICDEX("E11.9 ",30)
 I R69<1!(EICD<1) W "ICD lookup failed R69=",R69," E11.9=",EICD,! Q
 W "DFN=",DFN," R69=",R69," E11.9=",EICD,!
 S USER=$$USER^C0FWENC()
 D FIXPOV(DFN,R69,EICD)
 S PROB=$$FINDDM(DFN,R69,EICD)
 I PROB>0 D  Q
 . D FIXPROB(PROB,EICD)
 . W "fixed problem IEN=",PROB,!
 S NARR="Type 2 diabetes mellitus"
 ; onset 2025-01-15 so it overlaps CY2026 / H1
 S ON=3250115
 S PROB=$$ADDPROB^C0FWCON(.MSG,DFN,EICD,NARR,ON,USER,44054006,"")
 I PROB<1 W "ADDPROB failed: ",$G(MSG),! Q
 ; force onset/recorded dates (ADDPROB may stamp NOW on some fields)
 D FIXPROB(PROB,EICD)
 W "added problem IEN=",PROB,!
 Q
 ;
FIXPOV(DFN,R69,EICD) ; V POV R69 + diabetes narrative → E11.9
 N NARR,POV,X0
 S POV=0
 F  S POV=$O(^AUPNVPOV(POV)) Q:'POV  D
 . S X0=$G(^AUPNVPOV(POV,0))
 . Q:+$P(X0,U,2)'=DFN
 . Q:+$P(X0,U)'=R69
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,4),0)),U))
 . Q:NARR'["DIABET"
 . Q:NARR["FAMILY HISTORY"
 . Q:NARR["OF MOTHER"
 . S $P(^AUPNVPOV(POV,0),U)=EICD
 . W "POV ",POV," R69→E11.9 narr=",$E(NARR,1,40),!
 Q
 ;
FINDDM(DFN,R69,EICD) ; $$ - problem IEN for diabetes
 N IEN,NARR,SCT,X0,HIT,ICD
 S (IEN,HIT)=0
 F  S IEN=$O(^AUPNPROB("AC",DFN,IEN)) Q:'IEN  D  Q:HIT
 . S X0=$G(^AUPNPROB(IEN,0))
 . S SCT=$P($G(^AUPNPROB(IEN,800)),U)
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,5),0)),U))
 . I SCT=44054006!(SCT=73211009)!(SCT=46635009)!(SCT=313436004) S HIT=IEN Q
 . I NARR["DIABET",NARR'["FAMILY HISTORY",NARR'["OF MOTHER" S HIT=IEN Q
 . I +$P(X0,U)=EICD S HIT=IEN Q
 . I +$P(X0,U)=R69,NARR["DIABET" S HIT=IEN Q
 Q +HIT
 ;
FIXPROB(PROB,EICD) ; Point problem at E11.9, active, SCT 44054006, onset 2025-01-15
 N ON,SCT
 S ON=3250115
 S $P(^AUPNPROB(PROB,0),U)=EICD
 S $P(^AUPNPROB(PROB,0),U,3)=ON
 S $P(^AUPNPROB(PROB,0),U,8)=ON
 S $P(^AUPNPROB(PROB,0),U,12)="A"
 S $P(^AUPNPROB(PROB,0),U,13)=ON
 I $D(^AUPNPROB(PROB,1)) S $P(^AUPNPROB(PROB,1),U,7)=""
 S SCT=$P($G(^AUPNPROB(PROB,800)),U)
 I SCT=""!(SCT'?1.N) S $P(^AUPNPROB(PROB,800),U)=44054006
 Q
 ;
SCAN(LO,HI) ; Scan range; repair DM gaps
 N DFN,EICD,R69,NEED
 S LO=+$G(LO,1),HI=+$G(HI,50)
 I $G(U)="" S U="^"
 S R69=+$$ICDDX^ICDEX("R69.",30),EICD=+$$ICDDX^ICDEX("E11.9",30)
 F DFN=LO:1:HI I $D(^DPT(DFN,0)) D
 . S NEED=$$NEED(DFN,R69,EICD)
 . I NEED'="" W "NEED DFN=",DFN," ",NEED,! D DFN(DFN)
 Q
 ;
NEED(DFN,R69,EICD) ; $$ - reason if repair needed
 N IEN,NARR,POV,SCT,X0,HASDM,HASNARR
 S (HASDM,HASNARR)=0
 S IEN=0 F  S IEN=$O(^AUPNPROB("AC",DFN,IEN)) Q:'IEN  D
 . S X0=$G(^AUPNPROB(IEN,0))
 . S SCT=$P($G(^AUPNPROB(IEN,800)),U)
 . I $P(X0,U,12)'="A" Q
 . I +$P(X0,U)=EICD!(SCT=44054006)!(SCT=73211009) S HASDM=1
 S POV=0 F  S POV=$O(^AUPNVPOV(POV)) Q:'POV  D
 . S X0=$G(^AUPNVPOV(POV,0))
 . Q:+$P(X0,U,2)'=DFN
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,4),0)),U))
 . I NARR["DIABET",NARR'["FAMILY HISTORY" S HASNARR=1
 I HASNARR,'HASDM Q "DM-POV-no-active-E11-problem"
 I 'HASDM,$$HASDMNARR(DFN) Q "DM-narrative-no-active-E11"
 Q ""
 ;
HASDMNARR(DFN) ; $$ - any POV/problem narrative mentions diabetes
 N IEN,NARR,POV,X0,HIT
 S HIT=0
 S POV=0 F  S POV=$O(^AUPNVPOV(POV)) Q:'POV  D  Q:HIT
 . S X0=$G(^AUPNVPOV(POV,0)) Q:+$P(X0,U,2)'=DFN
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,4),0)),U))
 . I NARR["DIABET",NARR'["FAMILY HISTORY" S HIT=1
 S IEN=0 F  S IEN=$O(^AUPNPROB("AC",DFN,IEN)) Q:'IEN  D  Q:HIT
 . S X0=$G(^AUPNPROB(IEN,0))
 . S NARR=$$UP^XLFSTR($P($G(^AUTNPOV(+$P(X0,U,5),0)),U))
 . I NARR["DIABET",NARR'["FAMILY HISTORY" S HIT=1
 Q HIT
 ;
