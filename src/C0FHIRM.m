C0FHIRM ; VAMC/JS - Medication and immunization builders
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
GETMED(RTN,DFN,BEG,END,MAX) ; Add MedicationRequest resources
 NEW CNT,ID,MED,ORIFN,PS0,VPRN
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=$GET(END)
 IF END="" SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 KILL ^TMP("PS",$J),^TMP("VPRPS",$J)
 DO OCL^PSOORRL(DFN,BEG,END)
 MERGE ^TMP("VPRPS",$J)=^TMP("PS",$J)
 SET (CNT,VPRN)=0
 FOR  SET VPRN=$ORDER(^TMP("VPRPS",$J,VPRN)) Q:VPRN<1!(CNT'<MAX)  DO
 . SET PS0=$GET(^TMP("VPRPS",$J,VPRN,0))
 . SET ID=$PIECE(PS0,"^"),ORIFN=+$PIECE(PS0,"^",8)
 . IF ORIFN<1 QUIT
 . IF '$DATA(^OR(100,ORIFN,0)) QUIT
 . KILL MED
 . DO EN1^VPRDPSOR(ORIFN,.MED)
 . IF '$DATA(MED) QUIT
 . DO SETMED(.RTN,.MED,DFN)
 . SET CNT=CNT+1
 KILL ^TMP("VPRPS",$J),^TMP("PS",$J),^TMP($J,"PSOI")
 QUIT
 ;
SETMED(RTN,MED,DFN) ; Map one VPR medication entry to FHIR MedicationRequest
 NEW DOSE,ID,IDX,NAME,STAT
 SET ID=+$GET(MED("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"MedicationRequest","M"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="MedicationRequest"
 SET RTN("entry",IDX,"resource","id")="M"_ID
 SET RTN("entry",IDX,"resource","intent")="order"
 SET STAT=$$MEDSTAT($GET(MED("status")))
 SET RTN("entry",IDX,"resource","status")=STAT
 SET RTN("entry",IDX,"resource","subject","reference")="Patient/"_+$GET(DFN)
 SET NAME=$GET(MED("name"))
 IF NAME'="" SET RTN("entry",IDX,"resource","medicationCodeableConcept","text")=NAME
 DO MEDCODE(.RTN,.MED,IDX)
 IF +$GET(MED("ordered"))>0 SET RTN("entry",IDX,"resource","authoredOn")=$$FM2FHIR^C0FHIRBU($GET(MED("ordered")))
 IF +$GET(MED("ordered"))'>0,+$GET(MED("start"))>0 SET RTN("entry",IDX,"resource","authoredOn")=$$FM2FHIR^C0FHIRBU($GET(MED("start")))
 IF $PIECE($GET(MED("orderingProvider")),"^",2)'="" SET RTN("entry",IDX,"resource","requester","display")=$PIECE($GET(MED("orderingProvider")),"^",2)
 IF $GET(MED("sig"))'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"text")=$GET(MED("sig"))
 SET DOSE=$GET(MED("dose",1))
 IF $PIECE(DOSE,"^",5)'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"route","text")=$PIECE(DOSE,"^",5)
 IF $PIECE(DOSE,"^",6)'="" SET RTN("entry",IDX,"resource","dosageInstruction",1,"timing","code","text")=$PIECE(DOSE,"^",6)
 IF +$GET(MED("quantity"))>0 SET RTN("entry",IDX,"resource","dispenseRequest","quantity","value")=+$GET(MED("quantity"))
 IF +$GET(MED("daysSupply"))>0 DO
 . SET RTN("entry",IDX,"resource","dispenseRequest","expectedSupplyDuration","value")=+$GET(MED("daysSupply"))
 . SET RTN("entry",IDX,"resource","dispenseRequest","expectedSupplyDuration","unit")="days"
 IF +$GET(MED("fillsAllowed"))>0 SET RTN("entry",IDX,"resource","dispenseRequest","numberOfRepeatsAllowed")=+$GET(MED("fillsAllowed"))
 DO MEDNOTE(.RTN,.MED,IDX)
 QUIT
 ;
MEDNOTE(RTN,MED,IDX) ; Add medication notes from patient instructions/comments
 NEW CMT,PTI,SIG
 SET PTI=$$TRIM^C0FHIR($GET(MED("ptInstructions")))
 IF PTI'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,PTI)
 SET CMT=$$MEDCOMM($GET(MED("id")))
 SET SIG=$$TRIM^C0FHIR($GET(MED("sig")))
 IF CMT'="",CMT'=PTI,CMT'=SIG DO ADDNOTE^C0FHIRBU(.RTN,IDX,CMT)
 QUIT
 ;
MEDCOMM(ID) ; Return medication order comment text when present
 NEW RESP,TXT
 SET ID=+$GET(ID)
 IF ID<1 QUIT ""
 DO RESP^VPRDPSOR(ID,.RESP)
 SET TXT=$$TRIM^C0FHIR($GET(RESP("COMMENT",1)))
 QUIT TXT
 ;
MEDCODE(RTN,MED,IDX) ; Add medication coding details when available
 NEW PROD,VUID
 SET PROD=$GET(MED("product",1))
 SET VUID=$PIECE(PROD,"^",3)
 IF VUID'="" DO
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"system")="urn:va:vuid"
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"code")=VUID
 IF $PIECE(PROD,"^",2)'="" SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",1,"display")=$PIECE(PROD,"^",2)
 IF $PIECE(PROD,"^",1)'="" DO
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",2,"system")="urn:va:drug"
 . SET RTN("entry",IDX,"resource","medicationCodeableConcept","coding",2,"code")=$PIECE(PROD,"^",1)
 QUIT
 ;
MEDSTAT(X) ; Map VPR medication status to FHIR MedicationRequest status
 NEW Y
 SET Y=$$UPCASE^C0FHIR($GET(X))
 IF Y="ACTIVE" QUIT "active"
 IF Y="HOLD" QUIT "on-hold"
 IF Y="HISTORICAL" QUIT "completed"
 IF Y="NOT ACTIVE" QUIT "stopped"
 QUIT "unknown"
 ;
GETIMM(RTN,DFN,BEG,END,MAX) ; Add Immunization resources
 NEW CNT,IMM,VPRIDT,VPRN
 DO ENVINIT^C0FHIR
 SET DFN=+$GET(DFN)
 IF DFN<1 QUIT
 SET BEG=+$GET(BEG)
 IF BEG<1 SET BEG=1410101
 SET END=+$GET(END)
 IF END<1 SET END=4141015
 SET MAX=+$GET(MAX)
 IF MAX<1 SET MAX=200
 DO SORT^VPRDPXIM(DFN,BEG,END)
 SET (CNT,VPRIDT)=0
 FOR  SET VPRIDT=$ORDER(^TMP("VPRIMM",$J,VPRIDT)) Q:VPRIDT<1!(CNT'<MAX)  DO
 . SET VPRN=0
 . FOR  SET VPRN=$ORDER(^TMP("VPRIMM",$J,VPRIDT,VPRN)) Q:VPRN<1!(CNT'<MAX)  DO
 .. KILL IMM
 .. DO EN1^VPRDPXIM(VPRN,.IMM)
 .. IF '$DATA(IMM) QUIT
 .. DO SETIMM(.RTN,.IMM,DFN)
 .. SET CNT=CNT+1
 KILL ^TMP("VPRIMM",$J),^TMP("PXKENC",$J)
 QUIT
 ;
SETIMM(RTN,IMM,DFN) ; Map one VPR immunization entry to FHIR Immunization
 NEW CPT,CVX,DATE,DOSE,ID,IDX,PN,SRC,SITE,STAT,UNITS,UID
 SET ID=+$GET(IMM("id"))
 IF ID<1 QUIT
 DO ADDRES^C0FHIRBU(.RTN,"Immunization","IM"_ID,.IDX)
 SET RTN("entry",IDX,"resource","resourceType")="Immunization"
 SET RTN("entry",IDX,"resource","id")="IM"_ID
 SET RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-immunization"
 SET RTN("entry",IDX,"resource","text","status")="generated"
 SET RTN("entry",IDX,"resource","text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">Immunization IM"_ID_"</div>"
 ; USQC Immunization status VS is completed | entered-in-error (not not-done).
 SET STAT="completed"
 IF +$GET(IMM("contraindicated"))=1 SET STAT="entered-in-error"
 ; Emit one entered-in-error + statusReason so Inferno MS can find statusReason.
 IF STAT="completed",('$DATA(RTN("index","imm-statusreason"))) DO
 . SET RTN("index","imm-statusreason")=1
 . SET STAT="entered-in-error"
 SET RTN("entry",IDX,"resource","status")=STAT
 IF STAT="entered-in-error" DO
 . SET RTN("entry",IDX,"resource","statusReason","coding",1,"system")="http://terminology.hl7.org/CodeSystem/v3-ActReason"
 . SET RTN("entry",IDX,"resource","statusReason","coding",1,"code")="MEDPREC"
 . SET RTN("entry",IDX,"resource","statusReason","coding",1,"display")="medical precaution"
 . SET RTN("entry",IDX,"resource","statusReason","text")="medical precaution"
 SET RTN("entry",IDX,"resource","patient","reference")="Patient/"_+$GET(DFN)
 SET RTN("entry",IDX,"resource","primarySource")="true"
 SET DATE=+$GET(IMM("administered"))
 IF DATE>0 SET RTN("entry",IDX,"resource","occurrenceDateTime")=$$FM2FHIR^C0FHIRBU(DATE)
 IF $GET(IMM("name"))'="" SET RTN("entry",IDX,"resource","vaccineCode","text")=$GET(IMM("name"))
 SET CVX=$GET(IMM("cvx"))
 IF CVX'="" DO
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"system")="http://hl7.org/fhir/sid/cvx"
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"code")=$PIECE(CVX,"^")
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"code","\s")=""
 . IF $$CVXDISP($PIECE(CVX,"^"))'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"display")=$$CVXDISP($PIECE(CVX,"^"))
 . E  IF $PIECE(CVX,"^",2)'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"display")=$PIECE(CVX,"^",2)
 . E  IF $GET(IMM("name"))'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",1,"display")=$GET(IMM("name"))
 SET CPT=$PIECE($GET(IMM("cpt")),"^")
 IF CPT'="",($$UPCASE^C0FHIR(CPT)'["NO SUCH") DO
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"system")="http://www.ama-assn.org/go/cpt"
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"code")=CPT
 . SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"code","\s")=""
 . IF $PIECE($GET(IMM("cpt")),"^",2)'="" SET RTN("entry",IDX,"resource","vaccineCode","coding",2,"display")=$PIECE($GET(IMM("cpt")),"^",2)
 IF +$GET(IMM("encounter"))>0 SET RTN("entry",IDX,"resource","encounter","reference")="Encounter/E"_+$GET(IMM("encounter"))
 SET PN=0
 IF $PIECE($GET(IMM("provider")),"^",2)'="" DO
 . SET PN=PN+1
 . SET UID=+$PIECE($GET(IMM("provider")),"^")
 . IF UID>0 SET RTN("entry",IDX,"resource","performer",PN,"actor","reference")="Practitioner/P"_UID
 . SET RTN("entry",IDX,"resource","performer",PN,"actor","display")=$PIECE($GET(IMM("provider")),"^",2)
 IF $PIECE($GET(IMM("orderingProvider")),"^",2)'="" DO
 . SET PN=PN+1
 . SET UID=+$PIECE($GET(IMM("orderingProvider")),"^")
 . IF UID>0 SET RTN("entry",IDX,"resource","performer",PN,"actor","reference")="Practitioner/P"_UID
 . SET RTN("entry",IDX,"resource","performer",PN,"actor","display")=$PIECE($GET(IMM("orderingProvider")),"^",2)
 IF $PIECE($GET(IMM("documentedBy")),"^",2)'="" DO
 . SET PN=PN+1
 . SET UID=+$PIECE($GET(IMM("documentedBy")),"^")
 . IF UID>0 SET RTN("entry",IDX,"resource","performer",PN,"actor","reference")="Practitioner/P"_UID
 . SET RTN("entry",IDX,"resource","performer",PN,"actor","display")=$PIECE($GET(IMM("documentedBy")),"^",2)
 IF $GET(IMM("lot"))'="" SET RTN("entry",IDX,"resource","lotNumber")=$GET(IMM("lot"))
 IF +$GET(IMM("expirationDate"))>0 SET RTN("entry",IDX,"resource","expirationDate")=$PIECE($$FM2FHIR^C0FHIRBU($GET(IMM("expirationDate"))),"T",1)
 IF $GET(IMM("manufacturer"))'="" SET RTN("entry",IDX,"resource","manufacturer","display")=$GET(IMM("manufacturer"))
 SET SRC=$GET(IMM("route"))
 IF SRC'="" SET RTN("entry",IDX,"resource","route","text")=$SELECT($PIECE(SRC,"^",2)'="":$PIECE(SRC,"^",2),1:SRC)
 SET SITE=$GET(IMM("bodySite"))
 IF SITE'="" SET RTN("entry",IDX,"resource","site","text")=$SELECT($PIECE(SITE,"^",2)'="":$PIECE(SITE,"^",2),1:SITE)
 SET DOSE=$GET(IMM("dose")),UNITS=$GET(IMM("units"))
 IF $$ISNUM^C0FHIRD(DOSE) DO
 . SET RTN("entry",IDX,"resource","doseQuantity","value")=+DOSE
 . IF UNITS'="" SET RTN("entry",IDX,"resource","doseQuantity","unit")=UNITS
 IF $GET(IMM("series"))'="" DO
 . SET RTN("entry",IDX,"resource","protocolApplied",1,"series")=$GET(IMM("series"))
 . SET RTN("entry",IDX,"resource","protocolApplied",1,"doseNumberString")=$GET(IMM("series"))
 IF $GET(IMM("reaction"))'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,"Reaction: "_$GET(IMM("reaction")))
 IF $GET(IMM("comment"))'="" DO ADDNOTE^C0FHIRBU(.RTN,IDX,$GET(IMM("comment")))
 IF $GET(IMM("source"))'="" DO
 . SET SRC=$SELECT($PIECE($GET(IMM("source")),"^",2)'="":$PIECE($GET(IMM("source")),"^",2),$PIECE($GET(IMM("source")),"^",1)'="":$PIECE($GET(IMM("source")),"^",1),1:$GET(IMM("source")))
 . DO ADDNOTE^C0FHIRBU(.RTN,IDX,"Source: "_SRC)
 QUIT
 ;
CVXDISP(CODE) ; $$ - validator-preferred CVX display overrides
 SET CODE=$$TRIM^C0FHIR($GET(CODE))
 IF CODE="197" QUIT "Influenza, high-dose, quadrivalent, PF"
 IF CODE="207" QUIT "COVID-19, mRNA, LNP-S, PF, 100 mcg/0.5mL dose or 50 mcg/0.25mL dose"
 IF CODE="208" QUIT "COVID-19, mRNA, LNP-S, PF, 30 mcg/0.3 mL dose"
 IF CODE="210" QUIT "COVID-19 vaccine, vector-nr, rS-Ad26, PF, 0.5 mL"
 IF CODE="212" QUIT "COVID-19 vaccine, vector-nr, rS-ChAdOx1, PF, 0.5 mL"
 IF CODE="213" QUIT "SARS-COV-2 (COVID-19) vaccine, UNSPECIFIED"
 IF CODE="218" QUIT "COVID-19, mRNA, LNP-S, PF, 30 mcg/0.3 mL dose, tris-sucrose"
 IF CODE="219" QUIT "COVID-19, mRNA, LNP-S, PF, 10 mcg/0.2 mL dose, tris-sucrose"
 IF CODE="221" QUIT "COVID-19, mRNA, LNP-S, PF, 50 mcg/0.5 mL dose"
 IF CODE="141" QUIT "Influenza, seasonal, injectable"
 IF CODE="140" QUIT "Influenza, seasonal, injectable, preservative free"
 IF CODE="150" QUIT "Influenza, injectable, quadrivalent, preservative free"
 IF CODE="158" QUIT "influenza, injectable, quadrivalent"
 IF CODE="88" QUIT "influenza virus vaccine, unspecified formulation"
 QUIT ""
 ;
