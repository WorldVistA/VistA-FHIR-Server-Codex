SYNWEBRG ; VEHU/Codex - Register SYN + C0FHIR HTTP routes in ^%web(17.6001)
 ;;0.1;FHIR WEB REGISTRATION;;Mar 28, 2026
 ;
 ; After copying routines to ~/p, ZL this routine then:
 ;   D EN^SYNWEBRG
 ; Restart listener if your site requires it after route edits, e.g.:
 ;   D stop^%webreq D go^%webreq
 ;
 Q
 ;
EN ; Register (or refresh) routes - idempotent for same method+pattern
 IF $T(addService^%webutils)="" QUIT
 ; Use the local route definitions directly; addService^%webutils is idempotent for
 ; the same method+pattern, so this safely refreshes the shared SYN routes too.
 DO LOADDEF^SYNWEBRG
 IF $T(wsReplayIntake^SYNFHIR)'="" DO addService^%webutils("GET","replayIntake","wsReplayIntake^SYNFHIR")
 IF $T(wsReplayIntake^SYNFHIR)'="" DO addService^%webutils("GET","replayImport","wsReplayIntake^SYNFHIR")
 NEW VIT,ENC,CON
 SET VIT="wsIntakeVitals^SYNFVIT",ENC="wsIntakeEncounters^SYNFENC",CON="wsIntakeConditions^SYNFCON"
 IF $T(@VIT)'="" DO addService^%webutils("POST","addvitals",VIT)
 IF $T(@ENC)'="" DO addService^%webutils("POST","addencounter",ENC)
 IF $T(@CON)'="" DO addService^%webutils("POST","addcondition",CON)
 IF $T(WSREHMP^C0RGWEB)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","rehmp","WSREHMP^C0RGWEB","","","",.PARAMS)
 IF $T(REGTFHIR^C0FHIR)'="" DO REGTFHIR^C0FHIR
 IF $T(WEB^C0FHIRWS)'="" DO addService^%webutils("GET","fhir","WEB^C0FHIRWS")
 IF $T(WS^C0FWCAC)'="" DO
 . IF $T(deleteService^%webutils)'="" DO
 . . DO deleteService^%webutils("GET","fhir/{resource}")
 . . DO deleteService^%webutils("GET","fhir/{resource}/{id}")
 . . DO deleteService^%webutils("POST","fhir/{resource}/_search")
 . . DO deleteService^%webutils("POST","fhir/{resource}")
 . DO ADDREADS
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("GET","fhir/{resource}/{id}","WSREAD^C0FWCAC")
 . DO addService^%webutils("GET","fhir/{resource}","WS^C0FWCAC")
 . DO addService^%webutils("POST","fhir/{resource}/_search","WSPOST^C0FWCAC","","","",.PARAMS)
 . DO addService^%webutils("POST","fhir/{resource}","WSPOST^C0FWCAC","","","",.PARAMS)
 IF $T(WSALT^C0FHIR)'="" DO
 . IF $T(deleteService^%webutils)'="" DO
 . . DO deleteService^%webutils("GET","altfhir")
 . . DO deleteService^%webutils("GET","altfhir/{resource}")
 . . DO deleteService^%webutils("GET","altfhir/{resource}/{id}")
 . . DO deleteService^%webutils("POST","altfhir/{resource}/_search")
 . . DO deleteService^%webutils("POST","altfhir/{resource}")
 . DO ADDALTREADS
 . NEW APARAMS
 . SET APARAMS(1)="U^resource",APARAMS(2)="U^id"
 . DO addService^%webutils("GET","altfhir/{resource}/{id}","WSALTREST^C0FHIR","","","",.APARAMS)
 . KILL APARAMS SET APARAMS(1)="U^resource"
 . DO addService^%webutils("GET","altfhir/{resource}","WSALTREST^C0FHIR","","","",.APARAMS)
 . KILL APARAMS SET APARAMS(1)="B"
 . DO addService^%webutils("POST","altfhir/{resource}/_search","WSALTPOST^C0FHIR","","","",.APARAMS)
 . DO addService^%webutils("POST","altfhir/{resource}","WSALTPOST^C0FHIR","","","",.APARAMS)
 . DO addService^%webutils("GET","altfhir","WSALT^C0FHIR")
 IF $T(REG^C0XWS)'="" DO REG^C0XWS
 IF $T(DASH^C0FHIRWS)'="" DO addService^%webutils("GET","fhir-dashboard","DASH^C0FHIRWS")
 IF $T(QDASH^C0FHIRWS)'="" DO addService^%webutils("GET","fhir-quality-dashboard","QDASH^C0FHIRWS")
 IF $T(QDASHES^C0FHIRWS)'="" DO
 . DO addService^%webutils("GET","fhir-quality-dashboards","QDASHES^C0FHIRWS")
 . NEW QPARAMS
 . SET QPARAMS(1)="U^measure"
 . DO addService^%webutils("GET","fhir-quality-dashboards/{measure}","QDASHES^C0FHIRWS","","","",.QPARAMS)
 IF $T(WSASSET^C0FHIRWS)'="" DO addService^%webutils("GET","filesystem/{file}","WSASSET^C0FHIRWS")
 ; MeasureReport indexes: bare/trailing-slash dirs fail in FILESYS^%webapi (EISDIR).
 IF $T(QMRHTML^C0FQUAL)'="" DO
 . DO addService^%webutils("GET","filesystem/quality/measurereports","QMRHTML^C0FQUAL")
 . DO addService^%webutils("GET","filesystem/quality/measurereports/","QMRHTML^C0FQUAL")
 . NEW MQ
 . SET MQ(1)="U^measure"
 . DO addService^%webutils("GET","filesystem/quality/measurereports/{measure}","QMRHTML^C0FQUAL","","","",.MQ)
 . DO addService^%webutils("GET","filesystem/quality/measurereports/{measure}/","QMRHTML^C0FQUAL","","","",.MQ)
 ; Seed quality-measure catalog when routine is present
 IF $T(SEED^C0FQUAL)'="" DO SEED^C0FQUAL
 IF $T(WS^C0FWAIS)'="" DO addService^%webutils("GET","aiconsult","WS^C0FWAIS")
 IF $T(WSUPD^C0FWAIS)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","aiconsult/update-bundle","WSUPD^C0FWAIS","","","",.PARAMS)
 IF $T(WSREV^C0FWAIS)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","aiconsult/update-review","WSREV^C0FWAIS","","","",.PARAMS)
 IF $T(WSRECOMP^C0FQUAL)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","fhir-quality-recompute","WSRECOMP^C0FQUAL","","","",.PARAMS)
 IF $T(WSREEVAL^C0FQUAL)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","fhir-quality-reeval","WSREEVAL^C0FQUAL","","","",.PARAMS)
 IF $T(WSAPP^C0FWAIR)'="" DO
 . NEW PARAMS
 . SET PARAMS(1)="B"
 . DO addService^%webutils("POST","aiconsult/apply-review","WSAPP^C0FWAIR","","","",.PARAMS)
 IF $T(wsTIUStats^C0FTIUST)'="" DO addService^%webutils("GET","tiustats","wsTIUStats^C0FTIUST")
 IF $T(wsTIUVPatients^C0FTIUST)'="" DO addService^%webutils("GET","tiuvpatients","wsTIUVPatients^C0FTIUST")
 IF $T(wsLists^C0FPSL)'="" DO
 . DO addService^%webutils("GET","problemselection/lists","wsLists^C0FPSL")
 . DO addService^%webutils("GET","problemselection/categories","wsCategories^C0FPSL")
 . DO addService^%webutils("GET","problemselection/problems","wsProblems^C0FPSL")
 IF $T(WSSAVE^C0FWWBS)'="" DO
 . IF $T(deleteService^%webutils)'="" DO
 . . DO deleteService^%webutils("GET","writebacksaves")
 . . DO deleteService^%webutils("GET","writebacksaves/{id}")
 . . DO deleteService^%webutils("POST","writebacksaves/{id}/rename")
 . . DO deleteService^%webutils("POST","writebacksaves/{id}/archive")
 . NEW PARAMS
 . SET PARAMS(1)="U^id"
 . DO addService^%webutils("GET","writebacksaves/{id}","WSGET^C0FWWBS","","","",.PARAMS)
 . DO addService^%webutils("GET","writebacksaves","WSLIST^C0FWWBS")
 . DO addService^%webutils("POST","writebacksaves","WSSAVE^C0FWWBS")
 . KILL PARAMS SET PARAMS(1)="U^id",PARAMS(2)="B"
 . DO addService^%webutils("POST","writebacksaves/{id}/rename","WSRENAME^C0FWWBS","","","",.PARAMS)
 . DO addService^%webutils("POST","writebacksaves/{id}/archive","WSARCH^C0FWWBS","","","",.PARAMS)
 E  IF $T(WSSAVE^C0RGWBS)'="" DO
 . IF $T(deleteService^%webutils)'="" DO
 . . DO deleteService^%webutils("GET","writebacksaves")
 . . DO deleteService^%webutils("GET","writebacksaves/{id}")
 . NEW PARAMS
 . SET PARAMS(1)="U^id"
 . DO addService^%webutils("GET","writebacksaves/{id}","WSGET^C0RGWBS","","","",.PARAMS)
 . DO addService^%webutils("GET","writebacksaves","WSLIST^C0RGWBS")
 . DO addService^%webutils("POST","writebacksaves","WSSAVE^C0RGWBS")
 . DO addService^%webutils("POST","writebacksaves/{id}/rename","WSRENAME^C0RGWBS")
 . DO addService^%webutils("POST","writebacksaves/{id}/archive","WSARCH^C0RGWBS")
 QUIT
 ;
ADDREADS ; Register concrete read routes before broad FHIR search routes
 DO ADDREAD("Patient")
 DO ADDREAD("Observation")
 DO ADDREAD("Condition")
 DO ADDREAD("DiagnosticReport")
 DO ADDREAD("Organization")
 DO ADDREAD("Location")
 DO ADDREAD("Practitioner")
 DO ADDREAD("Encounter")
 DO ADDREAD("AllergyIntolerance")
 DO ADDREAD("Immunization")
 DO ADDREAD("Procedure")
 DO ADDREAD("MedicationRequest")
 DO ADDREAD("Medication")
 DO ADDREAD("CarePlan")
 DO ADDREAD("DocumentReference")
 DO ADDREAD("Provenance")
 QUIT
 ;
ADDREAD(RT) ; Register one concrete read route
 IF $T(deleteService^%webutils)'="" DO deleteService^%webutils("GET","fhir/"_RT_"/{id}")
 DO addService^%webutils("GET","fhir/"_RT_"/{id}","WSREAD^C0FWCAC")
 QUIT
 ;
ADDALTREADS ; Register concrete altfhir read routes before broad search routes
 DO ADDALTREAD("Patient")
 DO ADDALTREAD("Observation")
 DO ADDALTREAD("Condition")
 DO ADDALTREAD("DiagnosticReport")
 DO ADDALTREAD("Organization")
 DO ADDALTREAD("Location")
 DO ADDALTREAD("Practitioner")
 DO ADDALTREAD("Encounter")
 DO ADDALTREAD("AllergyIntolerance")
 DO ADDALTREAD("Immunization")
 DO ADDALTREAD("Procedure")
 DO ADDALTREAD("MedicationRequest")
 DO ADDALTREAD("Medication")
 DO ADDALTREAD("DocumentReference")
 DO ADDALTREAD("Provenance")
 DO ADDALTREAD("AdverseEvent")
 DO ADDALTREAD("CarePlan")
 DO ADDALTREAD("CareTeam")
 DO ADDALTREAD("Coverage")
 DO ADDALTREAD("Device")
 DO ADDALTREAD("DeviceRequest")
 DO ADDALTREAD("FamilyMemberHistory")
 DO ADDALTREAD("Goal")
 DO ADDALTREAD("MedicationAdministration")
 DO ADDALTREAD("MedicationDispense")
 DO ADDALTREAD("QuestionnaireResponse")
 DO ADDALTREAD("RelatedPerson")
 DO ADDALTREAD("ServiceRequest")
 DO ADDALTREAD("Task")
 QUIT
 ;
ADDALTREAD(RT) ; Register one concrete altfhir read route
 NEW PARAMS
 SET PARAMS(1)="U^id"
 IF $T(deleteService^%webutils)'="" DO deleteService^%webutils("GET","altfhir/"_RT_"/{id}")
 DO addService^%webutils("GET","altfhir/"_RT_"/{id}","WSALTREST^C0FHIR","","","",.PARAMS)
 QUIT
 ;
LOADDEF ; Same routes as SYNINIT LOADHAND^SYNINIT (master) when branch has no LOADHAND
 ; addpatient: new bundle -> new graph row. updatepatient: merge bundle into existing row (use ?ien=&dfn=&icn=).
 IF $T(WSPAT^C0FWADD)'="" DO addService^%webutils("POST","addpatient","WSPAT^C0FWADD")
 E  DO addService^%webutils("POST","addpatient","wsPostFHIR^SYNFHIR")
 IF $T(wsUpdatePatient^C0FWUPD)'="" DO addService^%webutils("POST","updatepatient","wsUpdatePatient^C0FWUPD")
 E  DO addService^%webutils("POST","updatepatient","wsUpdatePatient^SYNFHIRU")
 DO addService^%webutils("GET","loadstatus","wsLoadStatus^SYNFHIR")
 IF $T(wsShow^C0FHIR)'="" DO addService^%webutils("GET","showfhir","wsShow^C0FHIR")
 E  DO addService^%webutils("GET","showfhir","wsShow^SYNFHIR")
 DO addService^%webutils("GET","vpr/{dfn}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","vpr?icn={icn}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","vpr?ien={ien}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","global/{root}","wsGLOBAL^SYNVPR")
 DO addService^%webutils("GET","gtree/{root}","wsGtree^SYNVPR")
 DO addService^%webutils("GET","graph/{graph}","wsGetGraph^SYNGRAPH")
 QUIT
 ;
