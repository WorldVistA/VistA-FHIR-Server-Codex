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
 IF $T(wsTIUStats^C0FTIUST)'="" DO addService^%webutils("GET","tiustats","wsTIUStats^C0FTIUST")
 IF $T(wsTIUVPatients^C0FTIUST)'="" DO addService^%webutils("GET","tiuvpatients","wsTIUVPatients^C0FTIUST")
 IF $T(WSSAVE^C0RGWBS)'="" DO
 . DO addService^%webutils("POST","writebacksaves","WSSAVE^C0RGWBS")
 . DO addService^%webutils("GET","writebacksaves","WSLIST^C0RGWBS")
 . DO addService^%webutils("GET","writebacksaves/{id}","WSGET^C0RGWBS")
 . DO addService^%webutils("POST","writebacksaves/{id}/rename","WSRENAME^C0RGWBS")
 . DO addService^%webutils("POST","writebacksaves/{id}/archive","WSARCH^C0RGWBS")
 QUIT
 ;
LOADDEF ; Same routes as SYNINIT LOADHAND^SYNINIT (master) when branch has no LOADHAND
 ; addpatient: new bundle -> new graph row + IMPORTPT. updatepatient: merge bundle into existing row (use ?ien=&dfn=&icn=).
 DO addService^%webutils("POST","addpatient","wsPostFHIR^SYNFHIR")
 DO addService^%webutils("POST","updatepatient","wsUpdatePatient^SYNFHIRU")
 DO addService^%webutils("GET","loadstatus","wsLoadStatus^SYNFHIR")
 DO addService^%webutils("GET","showfhir","wsShow^SYNFHIR")
 DO addService^%webutils("GET","vpr/{dfn}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","vpr?icn={icn}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","vpr?ien={ien}","wsVPR^SYNVPR")
 DO addService^%webutils("GET","global/{root}","wsGLOBAL^SYNVPR")
 DO addService^%webutils("GET","gtree/{root}","wsGtree^SYNVPR")
 DO addService^%webutils("GET","graph/{graph}","wsGetGraph^SYNGRAPH")
 QUIT
 ;
