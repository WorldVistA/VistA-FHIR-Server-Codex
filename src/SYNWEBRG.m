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
EN ; Register (or refresh) routes — idempotent for same method+pattern
 IF $T(addService^%webutils)="" QUIT
 ; vaready-wd-compat SYNINIT may omit LOADHAND — use LOADDEF^SYNWEBRG then
 IF $T(LOADHAND^SYNINIT)'="" DO LOADHAND^SYNINIT
 ELSE  DO LOADDEF^SYNWEBRG
 IF $T(wsReplayIntake^SYNFHIR)'="" DO addService^%webutils("GET","replayIntake","wsReplayIntake^SYNFHIR")
 IF $T(wsReplayIntake^SYNFHIR)'="" DO addService^%webutils("GET","replayImport","wsReplayIntake^SYNFHIR")
 IF $T(wsIntakeVitals^SYNFVIT)'="" DO addService^%webutils("POST","addvitals","wsIntakeVitals^SYNFVIT")
 IF $T(wsIntakeEncounters^SYNFENC)'="" DO addService^%webutils("POST","addencounter","wsIntakeEncounters^SYNFENC")
 IF $T(wsIntakeConditions^SYNFCON)'="" DO addService^%webutils("POST","addcondition","wsIntakeConditions^SYNFCON")
 IF $T(REGTFHIR^C0FHIR)'="" DO REGTFHIR^C0FHIR
 IF $T(WEB^C0FHIRWS)'="" DO addService^%webutils("GET","fhir","WEB^C0FHIRWS")
 IF $T(wsTIUStats^C0FTIUST)'="" DO addService^%webutils("GET","tiustats","wsTIUStats^C0FTIUST")
 QUIT
 ;
LOADDEF ; Same routes as SYNINIT LOADHAND^SYNINIT (master) when branch has no LOADHAND
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
