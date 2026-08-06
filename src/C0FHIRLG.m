C0FHIRLG ; Codex - RPMS labs from fhir-intake graph ;Aug 03, 2026
 ;;0.1;C0FHIR PROJECT;;Aug 03, 2026
 ;
 ; Lab-package substitute for RPMS: read Observations + panel DiagnosticReports
 ; from the permanent fhir-intake graph (indexes from C0FWIDX / C0FWFUTL).
 ;
 ; Default ON when $$ISRPMS^C0FWPOL(). Override:
 ;   S ^C0FHIR("EXPERIMENT","GRAPHLABS")=1  ; force on (VistA hosts)
 ;   S ^C0FHIR("EXPERIMENT","GRAPHLABS")=0  ; force off
 ;
 ; Uses:
 ;   @ROOT@(IEN,"type","Observation",RIEN)
 ;   @ROOT@(IEN,"type","DiagnosticReport",RIEN)
 ;   @ROOT@(IEN,"POS","code",LOINC,purl) / SPO(purl,"rien",RIEN)
 ; Always includes LOINC 72166-2 (tobacco) and 44249-1 (PHQ-9) when present,
 ; and other Observations with category laboratory. Panel DiagnosticReports
 ; keep graph ids/fullUrls so result[] links resolve in the FHIR browser.
 ;
 Q
 ;
ON() ; $$ - graph labs enabled?
 I $D(^C0FHIR("EXPERIMENT","GRAPHLABS")) Q +^C0FHIR("EXPERIMENT","GRAPHLABS")
 I $TEXT(ISRPMS^C0FWPOL)'="",$$ISRPMS^C0FWPOL() Q 1
 Q 0
 ;
GETGRPLAB(RTN,DFN,BEG,END,MAX) ; Append graph Observations + panel DiagnosticReports
 N CNT,IEN,KEEP,ROOT,RIEN
 Q:'$$ON()
 S DFN=+$G(DFN) Q:DFN<1
 S ROOT=$$ROOT^C0FWFUTL() Q:ROOT=""
 S IEN=$$DFN2IEN^C0FWFUTL(DFN) Q:IEN<1
 S BEG=+$G(BEG) S:BEG<1 BEG=1410101
 S END=+$G(END) S:END<1 END=4141015 S:END'["." END=END_".24"
 S MAX=+$G(MAX) S:MAX<1 MAX=200
 ; MAX is labs-to-add (same as GETLAB^C0FHIRL), not total Observations in the
 ; bundle. Seeding from OBCNT let vitals fill rehmp CHUNKSIZE (50) and starve labs.
 S CNT=0
 K KEEP
 ; Required LOINCs via code index
 D KEEPCODE(ROOT,IEN,"72166-2",.KEEP)
 D KEEPCODE(ROOT,IEN,"44249-1",.KEEP)
 ; All Observation entries that WANT() accepts
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"type","Observation",RIEN)) Q:'RIEN  D
 . I $$WANT(ROOT,IEN,RIEN) S KEEP(RIEN)=""
 ; Newest intake entries first so Quality AI / writeback labs win MAX slots.
 S RIEN=" "
 F  S RIEN=$O(KEEP(RIEN),-1) Q:'RIEN!(CNT'<MAX)  D
 . I '$$INWIN(ROOT,IEN,RIEN,BEG,END) Q
 . D EMIT(.RTN,ROOT,IEN,RIEN,DFN,.CNT)
 ; Lab panel DiagnosticReports (category LAB) with result[] links
 D GETGRPDR(.RTN,ROOT,IEN,DFN,BEG,END)
 Q
 ;
GETGRPDR(RTN,ROOT,IEN,DFN,BEG,END) ; Append graph lab DiagnosticReports
 N RIEN
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"type","DiagnosticReport",RIEN)) Q:'RIEN  D
 . I '$$WANTDR(ROOT,IEN,RIEN) Q
 . I '$$INWIN(ROOT,IEN,RIEN,BEG,END) Q
 . D EMITDR(.RTN,ROOT,IEN,RIEN,DFN)
 Q
 ;
KEEPCODE(ROOT,IEN,CODE,KEEP) ; Mark entry IENs that have POS code index
 N PURL,RIEN
 S PURL=""
 F  S PURL=$O(@ROOT@(IEN,"POS","code",CODE,PURL)) Q:PURL=""  D
 . S RIEN=+$O(@ROOT@(IEN,"SPO",PURL,"rien",""))
 . I RIEN>0 S KEEP(RIEN)=""
 Q
 ;
WANT(ROOT,IEN,RIEN) ; $$ - include this Observation from graph
 N CAT,CODE,I,J
 ; Required experiment LOINCs (any coding slot)
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I)) Q:'I  D  Q:$G(CAT)
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"code"))
 . I CODE="72166-2"!(CODE="44249-1") S CAT=1
 Q:$G(CAT) 1
 ; Other lab-category Observations
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I)) Q:'I  D  Q:$G(CAT)
 . S J=0 F  S J=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J)) Q:'J  D  Q:$G(CAT)
 . . I $$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code")))="LABORATORY" S CAT=1
 Q +$G(CAT)
 ;
INWIN(ROOT,IEN,RIEN,BEG,END) ; $$ - effective time in window (FM)
 N DT,ISO
 S ISO=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","effectiveDateTime"))
 I ISO="" S ISO=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","issued"))
 I ISO="" Q 1
 S DT=$$ISOFM(ISO)
 I DT<1 Q 1
 I DT<BEG Q 0
 I DT>END Q 0
 Q 1
 ;
EMIT(RTN,ROOT,IEN,RIEN,DFN,CNT) ; Copy/normalize one graph Observation into bundle
 N IDX,KEY,RID,RES
 Q:'$D(@ROOT@(IEN,"json","entry",RIEN,"resource"))
 M RES=@ROOT@(IEN,"json","entry",RIEN,"resource")
 Q:$G(RES("resourceType"))'="Observation"
 ; Keep the intake-graph id (no GOBS- prefix).
 S RID=$G(RES("id"))
 I RID="" S RID=IEN_"-"_RIEN
 I $E(RID,1,5)="GOBS-" S RID=$E(RID,6,$L(RID))
 ; Match ADDRES^C0FHIRBU key (SAFE id) so duplicates do not burn MAX.
 S KEY="Observation|"_$$SAFE^C0FHIRBU(RID)
 I $D(RTN("index",KEY)) Q
 ; Force laboratory category so CQL lab retrieves see tobacco/PHQ LOINCs.
 S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 S RES("category",1,"coding",1,"code")="laboratory"
 S RES("category",1,"coding",1,"display")="Laboratory"
 S RES("category",1,"text")="Laboratory"
 S RES("subject","reference")="Patient/"_+DFN
 D ADDRES^C0FHIRBU(.RTN,"Observation",RID,.IDX)
 Q:IDX=""
 M RTN("entry",IDX,"resource")=RES
 S RTN("entry",IDX,"resource","id")=RID
 ; Keep graph fullUrl so DiagnosticReport.result urn:uuid / Observation/id resolve.
 S RTN("entry",IDX,"fullUrl")="urn:uuid:"_RID
 S RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-lab"
 S CNT=CNT+1
 Q
 ;
WANTDR(ROOT,IEN,RIEN) ; $$ - lab panel DiagnosticReport (not AI Consult)
 N CAT,CODE,I,J,RESN
 I $TEXT(ISAIC^C0FWAIC)'="",$$ISAIC^C0FWAIC(ROOT,IEN,RIEN) Q 0
 Q:$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="DiagnosticReport" 0
 ; Must define at least one result Observation (panel membership)
 S (RESN,I)=0
 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","result",I)) Q:'I  S RESN=RESN+1
 Q:RESN<1 0
 ; Prefer category LAB / Laboratory; also accept LABPATHOLOGY
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I)) Q:'I  D  Q:$G(CAT)
 . S J=0 F  S J=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J)) Q:'J  D  Q:$G(CAT)
 . . S CODE=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code")))
 . . I CODE="LAB"!(CODE="LABORATORY")!(CODE="LABPATHOLOGY") S CAT=1
 Q +$G(CAT)
 ;
EMITDR(RTN,ROOT,IEN,RIEN,DFN) ; Copy/normalize one graph lab DiagnosticReport
 N IDX,N,REF,RES,RID,SEQ
 Q:'$D(@ROOT@(IEN,"json","entry",RIEN,"resource"))
 M RES=@ROOT@(IEN,"json","entry",RIEN,"resource")
 Q:$G(RES("resourceType"))'="DiagnosticReport"
 ; Keep the intake-graph id (no GDR- prefix).
 S RID=$G(RES("id"))
 I RID="" S RID=IEN_"-"_RIEN
 I $E(RID,1,4)="GDR-" S RID=$E(RID,5,$L(RID))
 I $D(RTN("index","DiagnosticReport|"_RID)) Q
 ; Force LAB category to match GETLAB^C0FHIRL panel reports
 S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0074"
 S RES("category",1,"coding",1,"code")="LAB"
 S RES("category",1,"coding",1,"display")="Laboratory"
 S RES("category",1,"text")="Laboratory"
 S RES("subject","reference")="Patient/"_+DFN
 ; Normalize result refs to Observation/{graph-id}
 S SEQ=0 F  S SEQ=$O(RES("result",SEQ)) Q:'SEQ  D
 . S REF=$G(RES("result",SEQ,"reference"))
 . S RES("result",SEQ,"reference")=$$MAPOREF(REF)
 D ADDRES^C0FHIRBU(.RTN,"DiagnosticReport",RID,.IDX)
 Q:IDX=""
 M RTN("entry",IDX,"resource")=RES
 S RTN("entry",IDX,"resource","id")=RID
 S RTN("entry",IDX,"fullUrl")="urn:uuid:"_RID
 S RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-diagnosticreport-lab"
 ; Prefer graph performer; else attach a minimal lab Organization (no ORGMS^C0FHIR).
 I '$D(RES("performer")) D
 . S RTN("entry",IDX,"resource","performer",1,"reference")="Organization/VISTA-LAB"
 . S RTN("entry",IDX,"resource","performer",1,"display")="Laboratory"
 . D GRPLABORG(.RTN)
 Q
 ;
GRPLABORG(RTN) ; Minimal Organization for graph lab DiagnosticReport performers
 N IDX
 D ADDRES^C0FHIRBU(.RTN,"Organization","VISTA-LAB",.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="Organization"
 S RTN("entry",IDX,"resource","id")="VISTA-LAB"
 S RTN("entry",IDX,"resource","active")="true"
 S RTN("entry",IDX,"resource","name")="Laboratory"
 Q
 ;
MAPOREF(REF) ; $$ - urn:uuid:x or Observation/x -> Observation/x (strip GOBS-)
 N ID,P
 S REF=$G(REF) Q:REF="" REF
 I $E(REF,1,9)="urn:uuid:" S ID=$E(REF,10,$L(REF)) D  Q "Observation/"_ID
 . I $E(ID,1,5)="GOBS-" S ID=$E(ID,6,$L(ID))
 S P=$F(REF,"Observation/") Q:'P REF
 S ID=$E(REF,P,$L(REF)) Q:ID="" REF
 I $E(ID,1,5)="GOBS-" S ID=$E(ID,6,$L(ID))
 Q "Observation/"_ID
 ;
ISOFM(ISO) ; $$ - FHIR/ISO datetime to FileMan (best effort)
 N H,X
 S X=$G(ISO) Q:X="" 0
 I X?7N.1".".6N Q +X
 S H=$$FHIRISO2HL7^C0FWFUTL(ISO)
 I H="" Q 0
 I $TEXT(HL7TFM^XLFDT)="" Q 0
 Q +$$HL7TFM^XLFDT(H)
 ;
UP(X) ;
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
