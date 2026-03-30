C0FTIUST ; VEHU/Codex - Read-only TIU / visit linkage stats (dev diagnostics)
 ;;0.1;C0FHIR PROJECT;;Mar 27, 2026
 ;
 ; JSON GET endpoints:
 ;   /tiustats?dfn= (integer patient DFN)
 ;   /tiuvpatients?limit=n&dfn= (optional) — distinct DFNs with ^TIU(8925,"V",vst,...)
 ; Counts PCE visits via ^AUPNVSIT("AET",...) and TIU documents linked on the
 ; visit xref ^TIU(8925,"V",visitIEN,...). Patient-wide TIU count uses the
 ; standard ^TIU(8925,"C",dfn,...) index when present (shape may vary by site).
 ;
 QUIT
 ;
wsTIUStats(OUT,FILTER) ; %web GET handler; OUT, FILTER by reference
 NEW DFN,TMP,ERR
 IF '$DATA(DT) NEW DIQUIET SET DIQUIET=1 DO DT^DICRW
 KILL OUT
 SET DFN=+$GET(FILTER("dfn"))
 IF DFN<1 DO  QUIT
 . DO ERR^C0FHIRBU("Missing or invalid query parameter: dfn",.TMP)
 . DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 . SET HTTPRSP("mime")="application/json"
 DO STATS(DFN,.TMP)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
wsTIUVPatients(OUT,FILTER) ; GET tiuvpatients?limit=&dfn=
 ; limit: max rows in patients[] (0 = count only). Capped at 500.
 ; dfn: optional; adds hasVisitLinkedTiu true/false for that DFN after scan.
 NEW TMP,ERR,LIM,CHK
 IF '$DATA(DT) NEW DIQUIET SET DIQUIET=1 DO DT^DICRW
 KILL OUT
 SET LIM=+$GET(FILTER("limit"))
 SET CHK=+$GET(FILTER("dfn"))
 DO GATHERVP(.TMP,LIM,CHK)
 DO TOJSON^C0FHIRBU(.TMP,.OUT,.ERR)
 SET HTTPRSP("mime")="application/json"
 QUIT
 ;
GATHERVP(OUT,LIMIT,CHKDFN) ; Patients with >=1 TIU on ^TIU(8925,"V",visitIEN,docIEN)
 ; Visit IEN must resolve DFN via $P(^AUPNVSIT(visit,0),"^",5).
 NEW VST,DFN,TOT,N,MX,CHK0
 KILL OUT
 KILL ^TMP($JOB,"C0FTIUST","VP")
 SET VST=0
 FOR  SET VST=$ORDER(^TIU(8925,"V",VST)) QUIT:VST=""  QUIT:VST<1  DO
 . QUIT:'$ORDER(^TIU(8925,"V",VST,0))
 . SET DFN=+$PIECE($GET(^AUPNVSIT(VST,0)),"^",5) QUIT:DFN<1
 . SET ^TMP($JOB,"C0FTIUST","VP",DFN)=""
 SET DFN=0,TOT=0
 FOR  SET DFN=$ORDER(^TMP($JOB,"C0FTIUST","VP",DFN)) QUIT:DFN<1  SET TOT=TOT+1
 SET OUT("distinctPatientsWithVisitLinkedTIU")=TOT
 SET CHK0=+$GET(CHKDFN)
 IF CHK0>0 DO
 . SET OUT("checkDfn")=CHK0
 . IF $DATA(^TMP($JOB,"C0FTIUST","VP",CHK0)) SET OUT("hasVisitLinkedTiu")="true"
 . ELSE  SET OUT("hasVisitLinkedTiu")="false"
 SET MX=+$GET(LIMIT)
 IF MX>500 SET MX=500
 IF MX>0 DO
 . SET DFN=0,N=0
 . FOR  SET DFN=$ORDER(^TMP($JOB,"C0FTIUST","VP",DFN)) QUIT:DFN<1  DO  QUIT:N'<MX
 .. SET N=N+1
 .. SET OUT("patients",N,"dfn")=DFN
 .. SET OUT("patients",N,"name")=$PIECE($GET(^DPT(DFN,0)),"^")
 KILL ^TMP($JOB,"C0FTIUST","VP")
 QUIT
 ;
STATS(DFN,OUT) ; Build a flat object for ENCODE^XLFJSON (via TOJSON^C0FHIRBU)
 NEW VDT,LOC,VST,TIUDA,VCNT,VWC,UNIQUE
 KILL OUT
 SET DFN=+$GET(DFN)
 SET (VWC,VCNT,UNIQUE)=0
 KILL ^TMP($JOB,"C0FTIUST")
 SET OUT("dfn")=DFN
 IF DFN<1 SET OUT("patientFound")="false"
 ELSE  IF '$DATA(^DPT(DFN,0)) SET OUT("patientFound")="false"
 ELSE  SET OUT("patientFound")="true"
 SET VDT=0
 FOR  SET VDT=$ORDER(^AUPNVSIT("AET",DFN,VDT)) QUIT:VDT=""  DO
 . SET LOC=0
 . FOR  SET LOC=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC)) QUIT:LOC=""  QUIT:LOC<1  DO
 .. SET VST=0
 .. FOR  SET VST=$ORDER(^AUPNVSIT("AET",DFN,VDT,LOC,"P",VST)) QUIT:VST=""  QUIT:VST<1  DO
 ... SET VCNT=VCNT+1
 ... NEW NDOCV SET NDOCV=0
 ... SET TIUDA=0
 ... FOR  SET TIUDA=$ORDER(^TIU(8925,"V",VST,TIUDA)) QUIT:TIUDA<1  DO
 .... SET NDOCV=NDOCV+1
 .... IF '$DATA(^TMP($JOB,"C0FTIUST","U",TIUDA)) DO
 ..... SET ^TMP($JOB,"C0FTIUST","U",TIUDA)=1
 ..... SET UNIQUE=UNIQUE+1
 ... IF NDOCV>0 SET VWC=VWC+1
 KILL ^TMP($JOB,"C0FTIUST")
 SET OUT("visitCount")=VCNT
 SET OUT("visitsWithTiuLinkedDocuments")=VWC
 SET OUT("distinctTiuDocumentsOnVisits")=UNIQUE
 SET OUT("tiuDocumentsByPatientIndexC")=$$CNTC(DFN)
 QUIT
 ;
CNTC(DFN) ; Count TIU notes for patient using ^TIU(8925,"C",DFN,...)
 NEW A,B,C,CNT
 SET CNT=0
 SET DFN=+$GET(DFN)
 QUIT:DFN<1 0
 QUIT:'$DATA(^TIU(8925,"C",DFN)) 0
 SET A=""
 FOR  SET A=$ORDER(^TIU(8925,"C",DFN,A)) QUIT:A=""  DO
 . SET B=""
 . FOR  SET B=$ORDER(^TIU(8925,"C",DFN,A,B)) QUIT:B=""  DO
 .. SET C=""
 .. FOR  SET C=$ORDER(^TIU(8925,"C",DFN,A,B,C)) QUIT:C=""  QUIT:C<1  DO
 ... IF $PIECE($GET(^TIU(8925,C,0)),U,2)=DFN SET CNT=CNT+1
 IF CNT>0 QUIT CNT
 SET A=""
 FOR  SET A=$ORDER(^TIU(8925,"C",DFN,A)) QUIT:A=""  DO
 . SET B=""
 . FOR  SET B=$ORDER(^TIU(8925,"C",DFN,A,B)) QUIT:B=""  QUIT:B<1  DO
 .. IF $PIECE($GET(^TIU(8925,B,0)),U,2)=DFN SET CNT=CNT+1
 IF CNT>0 QUIT CNT
 SET A=""
 FOR  SET A=$ORDER(^TIU(8925,"C",DFN,A)) QUIT:A=""  QUIT:A<1  DO
 . IF $PIECE($GET(^TIU(8925,A,0)),U,2)=DFN SET CNT=CNT+1
 QUIT CNT
