C0FHIRQ ; VAMC/Codex - ServiceRequest builders (radiology orders) ;Jul 30, 2026
 ;;0.1;VISTA FHIR SERVER;**0**;Jul 30, 2026
 ;
 ; Emits FHIR ServiceRequest resources from Radiology/Nuclear Med Orders
 ; (file #75.1). Complements Procedure extract (completed exams) with the
 ; outstanding/ordered imaging requests created by C0FWSR / ORDER^RAMAG02.
 ;
 QUIT  ; No default action
 ;
GETSRQ(RTN,DFN,BEG,END,MAX) ; Add ServiceRequest resources for patient/date range
 NEW CNT,RAOIFN
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=$GET(END)
 IF END="" SET END=4141015
 IF END'["." SET END=END_".24"
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 SET CNT=0
 SET RAOIFN=0
 FOR  SET RAOIFN=$ORDER(^RAO(75.1,"B",DFN,RAOIFN)) QUIT:RAOIFN<1!(CNT'<MAX)  DO
 . IF $$INWIN(RAOIFN,BEG,END) DO SETRAO(.RTN,RAOIFN,DFN) SET CNT=CNT+1
 ; Fallback when "B" index is missing/incomplete on a site.
 IF CNT=0 DO SCAN(.RTN,DFN,BEG,END,MAX,.CNT)
 QUIT
 ;
SCAN(RTN,DFN,BEG,END,MAX,CNT) ; Linear fallback scan of file 75.1 by patient
 NEW RAOIFN,N0
 SET RAOIFN=0
 FOR  SET RAOIFN=$ORDER(^RAO(75.1,RAOIFN)) QUIT:RAOIFN<1!(CNT'<MAX)  DO
 . SET N0=$GET(^RAO(75.1,RAOIFN,0))
 . IF +N0'=DFN QUIT
 . IF '$$INWIN(RAOIFN,BEG,END) QUIT
 . DO SETRAO(.RTN,RAOIFN,DFN)
 . SET CNT=CNT+1
 QUIT
 ;
INWIN(RAOIFN,BEG,END) ; $$ - true when request date is inside [BEG,END]
 NEW DT
 SET DT=$$REQDT(+$GET(RAOIFN))
 IF DT<1 QUIT 1
 IF DT<+$GET(BEG) QUIT 0
 IF DT>+$GET(END) QUIT 0
 QUIT 1
 ;
SETRAO(RTN,RAOIFN,DFN) ; Map one #75.1 radiology order to FHIR ServiceRequest
 NEW CODE,IDX,NAME,N0,ORIFN,PROV,RID,STAT,WHEN
 SET RAOIFN=+$GET(RAOIFN)
 IF RAOIFN<1 QUIT
 SET N0=$GET(^RAO(75.1,RAOIFN,0))
 IF N0="" QUIT
 SET RID="RA"_RAOIFN
 DO ADDRES^C0FHIRBU(.RTN,"ServiceRequest",RID,.IDX)
 QUIT:IDX=""
 SET RTN("entry",IDX,"resource","resourceType")="ServiceRequest"
 SET RTN("entry",IDX,"resource","id")=RID
 SET STAT=$$SRSTAT(RAOIFN)
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","intent")="order"
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/service-category"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"code")="imaging"
 SET RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Imaging"
 SET RTN("entry",IDX,"resource","category",1,"text")="Imaging"
 SET CODE=+$PIECE(N0,U,2)
 SET NAME=$PIECE($GET(^RAMIS(71,CODE,0)),U)
 IF NAME="" SET NAME="Radiology order"
 SET RTN("entry",IDX,"resource","code","text")=NAME
 DO SRCODE(.RTN,IDX,CODE,NAME)
 SET WHEN=$$REQDT(RAOIFN)
 IF WHEN>0 SET RTN("entry",IDX,"resource","authoredOn")=$$FM2FHIR^C0FHIRBU(WHEN)
 SET ORIFN=$$ORIFN(RAOIFN,N0)
 IF ORIFN>0 DO
 . SET RTN("entry",IDX,"resource","identifier",1,"system")="urn:oid:2.16.840.1.113883.4.349.100"
 . SET RTN("entry",IDX,"resource","identifier",1,"value")=ORIFN
 . SET RTN("entry",IDX,"resource","identifier",1,"value","\s")=""
 SET PROV=+$PIECE(N0,U,14)
 IF PROV<1 SET PROV=+$PIECE(N0,U,6)
 IF PROV>0,$PIECE($GET(^VA(200,PROV,0)),U)'="" DO
 . SET RTN("entry",IDX,"resource","requester","reference")="Practitioner/P"_PROV
 . SET RTN("entry",IDX,"resource","requester","display")=$PIECE($GET(^VA(200,PROV,0)),U)
 IF $PIECE($GET(^RAO(75.1,RAOIFN,"H")),U)'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,$PIECE($GET(^RAO(75.1,RAOIFN,"H")),U))
 QUIT
 ;
SRCODE(RTN,IDX,CODE,NAME) ; Add procedure coding (CPT / SNOMED bridge for mammo)
 NEW CPT,UP
 SET CODE=+$GET(CODE),NAME=$GET(NAME)
 SET CPT=$PIECE($GET(^RAMIS(71,CODE,0)),U,9)
 IF CPT="" SET CPT=$PIECE($GET(^RAMIS(71,CODE,0)),U,10)
 IF CPT'="" DO
 . SET RTN("entry",IDX,"resource","code","coding",1,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","code","coding",1,"code")=CPT
 . IF NAME'="" SET RTN("entry",IDX,"resource","code","coding",1,"display")=NAME
 SET UP=$$UP(NAME)
 IF UP["MAMM" DO
 . SET RTN("entry",IDX,"resource","code","coding",2,"system")="http://snomed.info/sct"
 . SET RTN("entry",IDX,"resource","code","coding",2,"code")="71651007"
 . SET RTN("entry",IDX,"resource","code","coding",2,"display")="Mammography"
 QUIT
 ;
SRSTAT(RAOIFN) ; $$ - map #75.1 status to FHIR ServiceRequest.status
 NEW S
 SET S=$$GET1^DIQ(75.1,+$GET(RAOIFN)_",",5,"I")
 IF S="" SET S=$PIECE($GET(^RAO(75.1,+$GET(RAOIFN),0)),U,5)
 SET S=$$UP(S)
 IF S=1!(S="D")!(S["DISC") QUIT "revoked"
 IF S=3!(S="H")!(S["HOLD") QUIT "on-hold"
 IF S=6!(S="C")!(S["COMP") QUIT "completed"
 IF S=5!(S="P")!(S["PEND")!(S["ORDER") QUIT "active"
 IF S="R"!(S["REGIST") QUIT "active"
 QUIT "active"
 ;
REQDT(RAOIFN) ; $$ - request / desired date from #75.1
 NEW DT,N0
 SET N0=$GET(^RAO(75.1,+$GET(RAOIFN),0))
 ; Piece 16 is request date/time on current VEHU/fhirdev builds.
 SET DT=+$PIECE(N0,U,16)
 IF DT<1 SET DT=+$PIECE(N0,U,21)
 IF DT<1 SET DT=+$$GET1^DIQ(75.1,+$GET(RAOIFN)_",",21,"I")
 QUIT +DT
 ;
ORIFN(RAOIFN,N0) ; $$ - File 100 IEN linked from radiology order
 NEW ORIFN
 SET ORIFN=+$PIECE($GET(N0),U,7)
 IF ORIFN<1 SET ORIFN=+$PIECE($GET(N0),U,11)
 IF ORIFN<1 SET ORIFN=+$$GET1^DIQ(75.1,+$GET(RAOIFN)_",",7,"I")
 QUIT ORIFN
 ;
UP(X) ; $$ - uppercase
 QUIT $TRANSLATE($GET(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
