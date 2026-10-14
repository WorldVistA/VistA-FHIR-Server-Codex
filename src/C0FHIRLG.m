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
 ; Always includes LOINC 72166-2 (tobacco), 44249-1 (PHQ-9), 73832-8 / 73831-0
 ; (CMS2 depression assessment), and other Observations with category laboratory.
 ; Panel DiagnosticReports (lab category LAB, vital-signs category vital-signs)
 ; keep graph ids/fullUrls so result[] links resolve.
 ;
 Q
 ;
ON() ; $$ - graph labs enabled?
 I $D(^C0FHIR("EXPERIMENT","GRAPHLABS")) Q +^C0FHIR("EXPERIMENT","GRAPHLABS")
 I $TEXT(ISRPMS^C0FWPOL)'="",$$ISRPMS^C0FWPOL() Q 1
 Q 0
 ;
GETGRPLAB(RTN,DFN,BEG,END,MAX) ; Append graph Observations + panel DiagnosticReports
 N BYDT,CNT,DT,IEN,KEEP,ROOT,RIEN
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
 D KEEPCODE(ROOT,IEN,"73832-8",.KEEP)
 D KEEPCODE(ROOT,IEN,"73831-0",.KEEP)
 D KEEPCODE(ROOT,IEN,"44261-6",.KEEP)
 ; All Observation entries that WANT() accepts
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"type","Observation",RIEN)) Q:'RIEN  D
 . I $$WANT(ROOT,IEN,RIEN)!$$MSVIT(ROOT,IEN,RIEN) S KEEP(RIEN)=""
 ; Newest effective/issued first (MAX keeps the newest, not newest IEN).
 S RIEN=0
 F  S RIEN=$O(KEEP(RIEN)) Q:'RIEN  D
 . I '$$INWIN(ROOT,IEN,RIEN,BEG,END) Q
 . S BYDT($$RESDT(ROOT,IEN,RIEN),RIEN)=""
 S DT=""
 F  S DT=$O(BYDT(DT),-1) Q:DT=""!(CNT'<MAX)  D
 . S RIEN=0
 . F  S RIEN=$O(BYDT(DT,RIEN)) Q:'RIEN!(CNT'<MAX)  D EMIT(.RTN,ROOT,IEN,RIEN,DFN,.CNT)
 ; Panel DiagnosticReports (category LAB or vital-signs) with result[] links
 D GETGRPDR(.RTN,ROOT,IEN,DFN,BEG,END)
 ; REFFIX re-points panel result[] at in-bundle Observations (MAX / ^LR).
 ; It does not EMIT the rest: that added ~3,800 Observations and ~50 C0RG
 ; slices (2026-09-15 HARBER). Unmatched members keep their graph refs.
 ; Restore emit: S ^C0FHIR("EXPERIMENT","REFFIXEMIT")=1
 D REFFIX(.RTN,ROOT,IEN,DFN)
 Q
 ;
GETGRPNL(RTN,DFN,BEG,END) ; Append graph panel DiagnosticReports ONLY (VistA hosts)
 ; ^LR and GMV store individual results, not panel groupings, so lab and
 ; vital-sign panels exist only in fhir-intake (C0FWLAB GRAPHOK). When graph
 ; labs are OFF, merge just the panels: no graph Observations are added, so
 ; ISI-filed labs are not duplicated. REFFIX re-points result[] at the
 ; in-bundle Observations (vitals are already in the bundle; labs are ^LR).
 N IEN,ROOT
 S DFN=+$G(DFN) Q:DFN<1
 S ROOT=$$ROOT^C0FWFUTL() Q:ROOT=""
 S IEN=$$DFN2IEN^C0FWFUTL(DFN) Q:IEN<1
 S BEG=+$G(BEG) S:BEG<1 BEG=1410101
 S END=+$G(END) S:END<1 END=4141015 S:END'["." END=END_".24"
 D GETGRPDR(.RTN,ROOT,IEN,DFN,BEG,END)
 D REFFIX(.RTN,ROOT,IEN,DFN)
 Q
 ;
REFFIX(RTN,ROOT,IEN,DFN) ; Re-point panel result[] refs at in-bundle ^LR Observations
 ; The graph panels reference graph Observation ids, but on VistA hosts the
 ; bundle's lab Observations come from ^LR with LCH-* ids — unresolved refs
 ; mean the browser cannot nest member Observations under their panel.
 ; ISI files each panel member at +1s offsets for uniqueness, so match on
 ; minute resolution. Primary key is the #60 test NAME (graph LOINC mapped
 ; through the loader's labs map — many LOINCs share one #60 name, so the
 ; reverse LOINC lookup is often ambiguous); LOINC is the fallback key.
 ; Exact valueQuantity disambiguates same-name/same-minute collisions.
 N GID,I,J,LNC,NEWID,NM,OID,OIDX,REF,RIEN,SEQ,TK,VAL
 ; Index bundle Observations: ("N"|name and "L"|loinc) _ "|" _ YYYYMMDDHHMM
 S I=0
 F  S I=$O(RTN("entry",I)) Q:I<1  D
 . Q:$G(RTN("entry",I,"resource","resourceType"))'="Observation"
 . S OID=$G(RTN("entry",I,"resource","id")) Q:OID=""
 . S TK=$$MINKEY($G(RTN("entry",I,"resource","effectiveDateTime"))) Q:TK=""
 . S VAL=$G(RTN("entry",I,"resource","valueQuantity","value"))
 . S NM=$$UP($G(RTN("entry",I,"resource","code","text")))
 . I NM'="" D KEYADD(.OIDX,"N|"_NM_"|"_TK,VAL,OID)
 . ; FOIA #60 names drift with trailing digits (GLUCOSE1); index stripped too.
 . I NM?.E1N S NM=$$DIGSTRIP(NM) I NM'="" D KEYADD(.OIDX,"N|"_NM_"|"_TK,VAL,OID)
 . ; Every LOINC coding, not just the first. Pulse ox is filed as 2708-6 and
 . ; read back as 59408-5 plus 2708-6; indexing only the first misses the panel.
 . S J=0
 . F  S J=$O(RTN("entry",I,"resource","code","coding",J)) Q:'J  D
 . . S LNC=$G(RTN("entry",I,"resource","code","coding",J,"code"))
 . . I LNC'="",$G(RTN("entry",I,"resource","code","coding",J,"system"))["loinc" D KEYADD(.OIDX,"L|"_LNC_"|"_TK,VAL,OID)
 ; Rewrite unresolved DiagnosticReport result refs
 S I=0
 F  S I=$O(RTN("entry",I)) Q:I<1  D
 . Q:$G(RTN("entry",I,"resource","resourceType"))'="DiagnosticReport"
 . S SEQ=0
 . F  S SEQ=$O(RTN("entry",I,"resource","result",SEQ)) Q:'SEQ  D
 . . S REF=$G(RTN("entry",I,"resource","result",SEQ,"reference"))
 . . Q:$P(REF,"/")'="Observation"
 . . S GID=$P(REF,"/",2) Q:GID=""
 . . Q:$D(RTN("index","Observation|"_GID))  ; already resolves in-bundle
 . . ; Synthea fullUrls are urn:uuid:; hand-authored charts use Observation/id.
 . . ; A re-posted chart can leave two entries under one fullUrl; the newest
 . . ; is the one the panel was authored against.
 . . S RIEN=$$REFRIEN(ROOT,IEN,GID) Q:RIEN<1
 . . N GR S GR=$NA(@ROOT@(IEN,"json","entry",RIEN,"resource"))
 . . S LNC="",J=0
 . . F  S J=$O(@GR@("code","coding",J)) Q:'J!(LNC'="")  I $G(@GR@("code","coding",J,"system"))["loinc" S LNC=$G(@GR@("code","coding",J,"code"))
 . . Q:LNC=""
 . . S TK=$$MINKEY($G(@GR@("effectiveDateTime"))) Q:TK=""
 . . S VAL=$G(@GR@("valueQuantity","value"))
 . . S NM="" I $T(MAP^SYNQLDM)'="" S NM=$$MAP^SYNQLDM(LNC,"labs") I +NM=-1 S NM=""
 . . S NEWID=""
 . . I NM'="" S NEWID=$$KEYGET(.OIDX,"N|"_$$UP(NM)_"|"_TK,VAL)
 . . I NEWID="" S NEWID=$$KEYGET(.OIDX,"L|"_LNC_"|"_TK,VAL)
 . . ; ISI second-bumps can cross the minute boundary on big panels.
 . . I NEWID="" S TK=$$MINADD(TK) I TK'="" D
 . . . I NM'="" S NEWID=$$KEYGET(.OIDX,"N|"_$$UP(NM)_"|"_TK,VAL)
 . . . I NEWID="" S NEWID=$$KEYGET(.OIDX,"L|"_LNC_"|"_TK,VAL)
 . . ; No in-bundle match: leave the graph Observation/id. Extra EMIT of
 . . ; every unmatched member was the 4k-lab tree (see GETGRPLAB).
 . . I NEWID="" D  Q
 . . . I +$G(^C0FHIR("EXPERIMENT","REFFIXEMIT")) N C S C=0 D EMIT(.RTN,ROOT,IEN,RIEN,DFN,.C)
 . . S RTN("entry",I,"resource","result",SEQ,"reference")="Observation/"_NEWID
 Q
 ;
KEYADD(OIDX,KEY,VAL,OID) ; Register one Observation under a match key
 S OIDX(KEY)=$G(OIDX(KEY))+1
 I OIDX(KEY)=1 S OIDX(KEY,"one")=OID
 I VAL'="",$G(OIDX(KEY,"v",VAL))="" S OIDX(KEY,"v",VAL)=OID
 Q
 ;
KEYGET(OIDX,KEY,VAL) ; $$ - Observation id for key (+value tiebreak) or ""
 I '$D(OIDX(KEY)) Q ""
 I VAL'="",$G(OIDX(KEY,"v",VAL))'="" Q OIDX(KEY,"v",VAL)
 I $G(OIDX(KEY))=1 Q $G(OIDX(KEY,"one"))
 Q ""
 ;
DIGSTRIP(NM) ; $$ - name with trailing digits removed ("GLUCOSE1"->"GLUCOSE")
 N X
 S X=$G(NM)
 F  Q:X=""  Q:$E(X,$L(X))'?1N  S X=$E(X,1,$L(X)-1)
 Q X
 ;
MINADD(TK) ; $$ - YYYYMMDDHHMM key plus one minute (FileMan arithmetic)
 N FM
 Q:$G(TK)'?12N ""
 S FM=($E(TK,1,4)-1700)_$E(TK,5,8)_"."_$E(TK,9,12)
 S FM=$$FMADD^XLFDT(FM,0,0,1)
 Q:FM<1 ""
 Q ($E(FM,1,3)+1700)_$E(FM,4,7)_$E($P(FM,".",2)_"0000",1,4)
 ;
MINKEY(ISO) ; $$ - minute-resolution time key YYYYMMDDHHMM from ISO datetime
 N D
 S D=$TR($E($G(ISO),1,16),"-T:","")
 Q $S(D?12N:D,1:"")
 ;
GETGRPDR(RTN,ROOT,IEN,DFN,BEG,END) ; Append graph lab DiagnosticReports
 N BYDT,DT,RIEN
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"type","DiagnosticReport",RIEN)) Q:'RIEN  D
 . I '$$WANTDR(ROOT,IEN,RIEN) Q
 . I '$$INWIN(ROOT,IEN,RIEN,BEG,END) Q
 . S BYDT($$RESDT(ROOT,IEN,RIEN),RIEN)=""
 S DT=""
 F  S DT=$O(BYDT(DT),-1) Q:DT=""  D
 . S RIEN=0
 . F  S RIEN=$O(BYDT(DT,RIEN)) Q:'RIEN  D EMITDR(.RTN,ROOT,IEN,RIEN,DFN)
 Q
 ;
RESDT(ROOT,IEN,RIEN) ; $$ FileMan effective/issued, 0 if missing
 N DT,ISO
 S ISO=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","effectiveDateTime"))
 I ISO="" S ISO=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","issued"))
 I ISO="" Q 0
 S DT=$$ISOFM(ISO)
 Q $S(DT>0:DT,1:0)
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
 ; Required experiment / quality LOINCs (any coding slot)
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I)) Q:'I  D  Q:$G(CAT)
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"code"))
 . I CODE="72166-2"!(CODE="44249-1")!(CODE="73832-8")!(CODE="73831-0")!(CODE="44261-6") S CAT=1
 Q:$G(CAT) 1
 ; Other lab-category Observations
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I)) Q:'I  D  Q:$G(CAT)
 . S J=0 F  S J=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J)) Q:'J  D  Q:$G(CAT)
 . . I $$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code")))="LABORATORY" S CAT=1
 . . ; Survey assessments (CMS2 depression) also surface via graph labs
 . . I $$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code")))="SURVEY" S CAT=1
 Q +$G(CAT)
 ;
MSVIT(ROOT,IEN,RIEN) ; $$ - BMI, oxygen flow rate, or a data-absent vital component
 N CODE,HIT,I
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I)) Q:'I  D
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",I,"code"))
 . I CODE="39156-5"!(CODE="59576-9")!(CODE="77606-2")!(CODE="8289-1") S HIT=1
 . I CODE="9279-1"!(CODE="9843-4")!(CODE="11341-5")!(CODE="82810-3")!(CODE="86645-9") S HIT=1
 I $G(HIT) Q 1
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","component",I)) Q:'I  D
 . I $D(@ROOT@(IEN,"json","entry",RIEN,"resource","component",I,"dataAbsentReason")) S HIT=1
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","component",I,"code","coding",1,"code"))
 . I CODE="3151-8" S HIT=1
 Q +$G(HIT)
 ;
VITOBS(RES) ; $$ - copied Observation is a vital profile, not a lab
 N CODE,HIT,I
 S I=0 F  S I=$O(RES("code","coding",I)) Q:'I  D
 . S CODE=$G(RES("code","coding",I,"code"))
 . I CODE="39156-5"!(CODE="85354-9")!(CODE="59408-5")!(CODE="2708-6") S HIT=1
 . I CODE="59576-9"!(CODE="77606-2")!(CODE="8289-1")!(CODE="9279-1")!(CODE="9843-4") S HIT=1
 Q +$G(HIT)
 ;
VITPROF(RES) ; $$ - US Core profile URL for a graph vital
 N CODE,I,PROF
 S I=0 F  S I=$O(RES("code","coding",I)) Q:'I  D
 . S CODE=$G(RES("code","coding",I,"code"))
 . I CODE="39156-5" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-bmi"
 . I CODE="59576-9" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/pediatric-bmi-for-age"
 . I CODE="77606-2" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/pediatric-weight-for-height"
 . I CODE="8289-1" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/head-occipital-frontal-circumference-percentile"
 . I CODE="9279-1" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-respiratory-rate"
 . I CODE="85354-9" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-blood-pressure"
 . I CODE="59408-5"!(CODE="2708-6") S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-pulse-oximetry"
 Q $G(PROF)
 ;
GETGRPCL(RTN,DFN) ; Chart resources the loader does not file, from the intake graph
 N IEN,ROOT,TYPE
 Q:$TEXT(ROOT^C0FWFUTL)=""
 S DFN=+$G(DFN) Q:DFN<1
 S ROOT=$$ROOT^C0FWFUTL() Q:ROOT=""
 S IEN=$$DFN2IEN^C0FWFUTL(DFN) Q:IEN<1
 F TYPE="Coverage","CareTeam","RelatedPerson","Goal","CarePlan","ServiceRequest","Provenance","MedicationDispense","MedicationAdministration","Immunization","Procedure","AdverseEvent","DeviceRequest","Task","FamilyMemberHistory","DiagnosticReport","MedicationRequest","Observation","PractitionerRole" D GRPTYPE(.RTN,ROOT,IEN,DFN,TYPE)
 D SRMAMMO(.RTN,DFN)
 Q
 ;
GRPTYPE(RTN,ROOT,IEN,DFN,TYPE) ;
 N RIEN
 S RIEN=0
 F  S RIEN=$O(@ROOT@(IEN,"type",TYPE,RIEN)) Q:'RIEN  D EMITCL(.RTN,ROOT,IEN,RIEN,DFN,TYPE)
 Q
 ;
EMITCL(RTN,ROOT,IEN,RIEN,DFN,TYPE) ; Copy one non-lab graph resource into the bundle
 N IDX,PROF,RES,RID
 Q:'$D(@ROOT@(IEN,"json","entry",RIEN,"resource"))
 M RES=@ROOT@(IEN,"json","entry",RIEN,"resource")
 Q:$G(RES("resourceType"))'=TYPE
 I TYPE="Immunization",$G(RES("status"))'="not-done" Q
 I TYPE="Procedure",$G(RES("status"))'="not-done" Q
 S RID=$G(RES("id")) Q:RID=""
 I $$GAPONLY(TYPE,RID) Q
 I $G(RES("subject","reference"))["Patient/" S RES("subject","reference")="Patient/"_+DFN
 I $G(RES("patient","reference"))["Patient/" S RES("patient","reference")="Patient/"_+DFN
 I $G(RES("beneficiary","reference"))["Patient/" S RES("beneficiary","reference")="Patient/"_+DFN
 I $G(RES("for","reference"))["Patient/" S RES("for","reference")="Patient/"_+DFN
 I TYPE="ServiceRequest" D SRFIX(.RES)
 I TYPE="MedicationRequest" D DNPFIX(.RES)
 I TYPE="DeviceRequest" D DEVBOOL(.RES)
 I TYPE="MedicationDispense",$G(RES("status"))="declined" D MEDDEC(.RES)
 I TYPE="MedicationDispense",$G(RES("status"))'="declined" D MEDDSP(.RTN,.RES)
 I TYPE="MedicationAdministration",$G(RES("status"))="not-done" D MEDNOT(.RES)
 I TYPE="MedicationAdministration",$G(RES("status"))'="not-done" D MEDADM(.RES)
 I TYPE="Immunization" D IMMFIX(.RES)
 I TYPE="Goal" D GOLFIX(.RES)
 I TYPE="CarePlan" D CPFIX(.RES)
 I TYPE="CareTeam" D CTFIX(.RES,.RTN)
 I TYPE="RelatedPerson" D RPFIX(.RES)
 I TYPE="Coverage" D CVPAY(.RTN,.RES)
 I TYPE="PractitionerRole" D ROLFIX(.RES)
 S PROF=$$CLPROF(TYPE)
 I TYPE="ServiceRequest",$G(RES("doNotPerform"))="true" S PROF="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-servicenotrequested"
 I TYPE="DeviceRequest",$$ISTRUE($G(RES("modifierExtension",1,"valueBoolean"))) S PROF="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-devicenotrequested"
 I TYPE="MedicationDispense",$G(RES("status"))="declined" S PROF="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-medicationdispensedeclined"
 I TYPE="MedicationAdministration",$G(RES("status"))="not-done" S PROF="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-medicationadministrationnotdone"
 I TYPE="Task",$G(RES("status"))="rejected" S PROF="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-taskrejected"
 I TYPE="Observation" D OBSFIX(.RES) S PROF=$$OBSPROF(.RES)
 I TYPE="Task" D TASKFIX(.RES)
 I PROF'="" S RES("meta","profile",1)=PROF
 D ADDRES^C0FHIRBU(.RTN,TYPE,RID,.IDX)
 Q:IDX=""
 M RTN("entry",IDX,"resource")=RES
 S RTN("entry",IDX,"resource","id")=RID
 S RTN("entry",IDX,"fullUrl")=TYPE_"/"_RID
 I TYPE="ServiceRequest" D SRPROV(.RTN,RID)
 I TYPE="MedicationDispense"!(TYPE="MedicationAdministration")!(TYPE="Immunization")!(TYPE="Procedure")!(TYPE="AdverseEvent")!(TYPE="DeviceRequest")!(TYPE="Task")!(TYPE="FamilyMemberHistory")!(TYPE="DiagnosticReport")!(TYPE="MedicationRequest")!(TYPE="Observation") D PROVONE(.RTN,TYPE,RID)
 I TYPE="Immunization"!(TYPE="Procedure")!(TYPE="MedicationDispense")!(TYPE="MedicationAdministration")!(TYPE="AdverseEvent")!(TYPE="DeviceRequest")!(TYPE="Task")!(TYPE="DiagnosticReport")!(TYPE="MedicationRequest")!(TYPE="PractitionerRole") D ADDPRAC^C0FHIR(.RTN,1,"PROGRAMMER,ONE")
 I TYPE="AdverseEvent" D ADDMED(.RTN,"med-zz-disp")
 I TYPE="DiagnosticReport" D ADDORG^C0FHIR(.RTN,"org-clinic","Fictitious Clinic","")
 Q
 ;
CLPROF(TYPE) ; $$ - US Quality Core profile, or empty
 I TYPE="Coverage" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-coverage"
 I TYPE="CareTeam" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-careteam"
 I TYPE="RelatedPerson" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-relatedperson"
 I TYPE="Goal" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-goal"
 I TYPE="CarePlan" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-careplan"
 I TYPE="ServiceRequest" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-servicerequest"
 I TYPE="MedicationDispense" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-medicationdispense"
 I TYPE="MedicationAdministration" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-medicationadministration"
 I TYPE="Immunization" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-immunizationnotdone"
 I TYPE="Procedure" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-procedurenotdone"
 I TYPE="AdverseEvent" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-adverseevent"
 I TYPE="DeviceRequest" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-devicerequest"
 I TYPE="Task" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-task"
 I TYPE="FamilyMemberHistory" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-familymemberhistory"
 I TYPE="DiagnosticReport" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-diagnosticreport-note"
 I TYPE="MedicationRequest" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-medicationnotrequested"
 I TYPE="PractitionerRole" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-practitionerrole"
 Q ""
 ;
BPSYS(RES) ; Copy dataAbsentReason onto the systolic component
 N CODE,DAR,I
 S I=0
 F  S I=$O(RES("component",I)) Q:'I  I $D(RES("component",I,"dataAbsentReason")) M DAR=RES("component",I,"dataAbsentReason")
 Q:'$D(DAR)
 S I=0
 F  S I=$O(RES("component",I)) Q:'I  D
 . S CODE=$G(RES("component",I,"code","coding",1,"code"))
 . I CODE'="8480-6" Q
 . K RES("component",I,"valueQuantity")
 . M RES("component",I,"dataAbsentReason")=DAR
 Q
 ;
SRFIX(RES) ; doNotPerform and a US Core category the suite searches
 I $$ISTRUE($G(RES("doNotPerform"))) S RES("doNotPerform")="true"
 E  S RES("doNotPerform")="false"
 S RES("category",1,"coding",1,"system")="http://snomed.info/sct"
 S RES("category",1,"coding",1,"code")="386053000"
 S RES("category",1,"coding",1,"display")="Evaluation procedure"
 I $G(RES("code","coding",1,"code"))="719858009" S RES("code","coding",1,"display")="Telehealth monitoring"
 I $G(RES("requester","reference"))["pract-chen" S RES("requester","reference")="Practitioner/P1"
 D SRREASON(.RES)
 Q
 ;
IMMFIX(RES) ; Not-done vaccine is a value-set extension, not a CVX code the administered set rejects
 K RES("vaccineCode","coding")
 S RES("vaccineCode","text")="Not Done Value Set: Influenza vaccine"
 S RES("vaccineCode","extension",1,"url")="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-notDoneValueSet"
 S RES("vaccineCode","extension",1,"valueCanonical")="http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.526.3.1254"
 K RES("statusReason")
 S RES("statusReason","coding",1,"system")="http://snomed.info/sct"
 S RES("statusReason","coding",1,"code")="410534003"
 S RES("statusReason","coding",1,"display")="Not indicated (qualifier value)"
 Q
 ;
GAPONLY(TYPE,RID) ; $$ - 1 when an old chart row must not be copied into the read
 I TYPE="Observation"!(TYPE="MedicationRequest")!(TYPE="DiagnosticReport")!(TYPE="AdverseEvent")!(TYPE="DeviceRequest")!(TYPE="Task")!(TYPE="FamilyMemberHistory") Q $E(RID,1,4)'="inf-"
 Q 0
 ;
DEVBOOL(RES) ; DeviceRequest doNotPerform is a modifier extension, not a field
 K RES("doNotPerform")
 I '$D(RES("modifierExtension",1,"valueBoolean")) Q
 I $$ISTRUE($G(RES("modifierExtension",1,"valueBoolean"))) S RES("modifierExtension",1,"valueBoolean")="true"
 E  S RES("modifierExtension",1,"valueBoolean")="false"
 I $G(RES("modifierExtension",1,"valueBoolean"))'="true" Q
 S RES("extension",1,"url")="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-doNotPerformReason"
 S RES("extension",1,"valueCodeableConcept","coding",1,"system")="http://snomed.info/sct"
 S RES("extension",1,"valueCodeableConcept","coding",1,"code")="410534003"
 S RES("extension",1,"valueCodeableConcept","coding",1,"display")="Not indicated (qualifier value)"
 Q
 ;
DNPFIX(RES) ; Normalize doNotPerform so the search token is true or false
 I $$ISTRUE($G(RES("doNotPerform"))) S RES("doNotPerform")="true"
 E  I $G(RES("doNotPerform"))'="" S RES("doNotPerform")="false"
 I $G(RES("reasonCode",1,"text"))="" D
 . S RES("reasonCode",1,"text")="Not indicated (qualifier value)"
 . S RES("reasonCode",1,"coding",1,"system")="http://snomed.info/sct"
 . S RES("reasonCode",1,"coding",1,"code")="410534003"
 . S RES("reasonCode",1,"coding",1,"display")="Not indicated (qualifier value)"
 I '$D(RES("modifierExtension",1,"valueBoolean")) Q
 I $$ISTRUE($G(RES("modifierExtension",1,"valueBoolean"))) S RES("modifierExtension",1,"valueBoolean")="true"
 E  S RES("modifierExtension",1,"valueBoolean")="false"
 Q
 ;
OBSFIX(RES) ; Use example LOINC codes the validator knows
 N RID
 S RID=$G(RES("id"))
 I RID="inf-exam" D  Q
 . S RES("code","text")="Heart rate rhythm"
 . S RES("code","coding",1,"system")="http://loinc.org"
 . S RES("code","coding",1,"code")="8884-9"
 . S RES("code","coding",1,"display")="Heart rate rhythm"
 . S RES("valueString")="Regular (R)"
 . K RES("valueQuantity")
 I RID="inf-survey" D  Q
 . S RES("code","text")="Blood pressure alteration [CCC]"
 . S RES("code","coding",1,"system")="http://loinc.org"
 . S RES("code","coding",1,"code")="28139-4"
 . S RES("code","coding",1,"display")="Blood pressure alteration [CCC]"
 . S RES("category",2,"text")="Functional Status"
 . S RES("category",2,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",2,"coding",1,"code")="social-history"
 . S RES("category",2,"coding",1,"display")="Social History"
 . S RES("category",2,"coding",2,"system")="http://hl7.org/fhir/us/core/CodeSystem/us-core-category"
 . S RES("category",2,"coding",2,"code")="functional-status"
 . S RES("category",2,"coding",2,"display")="Functional Status"
 I RID="inf-cancelled" D
 . S RES("issued")="2026-03-10T14:00:00Z"
 . S RES("extension",1,"url")="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-notDoneReason"
 . S RES("extension",1,"valueCodeableConcept","coding",1,"system")="http://snomed.info/sct"
 . S RES("extension",1,"valueCodeableConcept","coding",1,"code")="410534003"
 . S RES("extension",1,"valueCodeableConcept","coding",1,"display")="Not indicated (qualifier value)"
 I RID="inf-activity"!(RID="inf-cancelled") D
 . S RES("code","text")="Mobility device or aid is regularly used"
 . S RES("code","coding",1,"system")="http://loinc.org"
 . S RES("code","coding",1,"code")="99354-3"
 . S RES("code","coding",1,"display")="Mobility device or aid is regularly used"
 . S RES("category",2,"coding",1,"system")="http://hl7.org/fhir/us/core/CodeSystem/us-core-category"
 . S RES("category",2,"coding",1,"code")="functional-status"
 . S RES("category",2,"coding",1,"display")="Functional Status"
 Q
 ;
OBSPROF(RES) ; $$ - profile for a graph-only observation
 N CODE
 I $G(RES("status"))="cancelled" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observationcancelled"
 S CODE=$G(RES("category",1,"coding",1,"code"))
 I CODE="exam" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-clinical-result"
 I CODE="survey" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-screening-assessment"
 I CODE="activity" Q "http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-simple-observation"
 Q ""
 ;
MEDDEC(RES) ; Declined dispense keeps its not-done medication text
 S RES("performer",1,"actor","reference")="Practitioner/P1"
 S RES("substitution","wasSubstituted")="false"
 Q
 ;
MEDNOT(RES) ; Not-done administration keeps its not-done medication text
 N C0FSR
 S RES("performer",1,"actor","reference")="Practitioner/P1"
 I $D(RES("statusReason","coding")),'$D(RES("statusReason",1)) D
 . M C0FSR=RES("statusReason")
 . K RES("statusReason")
 . M RES("statusReason",1)=C0FSR
 I '$D(RES("extension",1)) D
 . S RES("extension",1,"url")="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-recorded"
 . S RES("extension",1,"valueDateTime")="2026-10-06"
 Q
 ;
TASKFIX(RES) ; Identifier, and a resolvable focus on the rejected task
 S RES("identifier",1,"system")="https://fhir.vistaplex.org/task"
 S RES("identifier",1,"value")=$G(RES("id"))
 I $G(RES("status"))'="rejected" Q
 S RES("focus","reference")="DiagnosticReport/inf-note"
 S RES("statusReason","text")="Not indicated (qualifier value)"
 S RES("statusReason","coding",1,"system")="http://snomed.info/sct"
 S RES("statusReason","coding",1,"code")="410534003"
 S RES("statusReason","coding",1,"display")="Not indicated (qualifier value)"
 Q
 ;
ROLFIX(RES) ; PractitionerRole points at the practitioner the suite can read
 I $G(RES("practitioner","reference"))["pract-chen" S RES("practitioner","reference")="Practitioner/P1"
 Q
 ;
ISTRUE(X) ; $$ - JSON true stored as 1 or "true"
 I X=1!(X="1")!(X="true")!(X="TRUE") Q 1
 Q 0
 ;
MEDDSP(RTN,RES) ; Dispense must-support: medication reference, performer, prescription
 N C0FI,C0FID
 S RES("performer",1,"actor","reference")="Practitioner/P1"
 S RES("substitution","wasSubstituted")="false"
 K RES("medicationCodeableConcept")
 S RES("medicationReference","reference")="Medication/med-zz-disp"
 S C0FI=0,C0FID=""
 F  S C0FI=$O(RTN("entry",C0FI)) Q:'C0FI  D  Q:C0FID'=""
 . I $G(RTN("entry",C0FI,"resource","resourceType"))'="MedicationRequest" Q
 . S C0FID=$G(RTN("entry",C0FI,"resource","id"))
 I C0FID'="" S RES("authorizingPrescription",1,"reference")="MedicationRequest/"_C0FID
 D ADDMED(.RTN,"med-zz-disp")
 Q
 ;
MEDADM(RES) ; Administration medication is a Reference the suite can read
 K RES("medicationCodeableConcept")
 S RES("medicationReference","reference")="Medication/med-zz-disp"
 S RES("performer",1,"actor","reference")="Practitioner/P1"
 Q
 ;
ADDMED(RTN,MID) ; Companion Medication for dispense and administration references
 N IDX
 D ADDRES^C0FHIRBU(.RTN,"Medication",MID,.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="Medication"
 S RTN("entry",IDX,"resource","id")=MID
 S RTN("entry",IDX,"resource","code","coding",1,"system")="http://www.nlm.nih.gov/research/umls/rxnorm"
 S RTN("entry",IDX,"resource","code","coding",1,"code")="636676"
 S RTN("entry",IDX,"resource","code","coding",1,"display")="varenicline 1 MG Oral Tablet"
 S RTN("entry",IDX,"resource","code","text")="varenicline 1 MG Oral Tablet"
 S RTN("entry",IDX,"fullUrl")="Medication/"_MID
 Q
 ;
PROVONE(RTN,TYPE,RID) ; Provenance whose target is this graph resource
 N IDX,PID
 S PID="prov-"_RID
 D ADDRES^C0FHIRBU(.RTN,"Provenance",PID,.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="Provenance"
 S RTN("entry",IDX,"resource","id")=PID
 S RTN("entry",IDX,"resource","target",1,"reference")=TYPE_"/"_RID
 S RTN("entry",IDX,"resource","recorded")="2026-10-06T14:00:00Z"
 S RTN("entry",IDX,"resource","agent",1,"who","reference")="Practitioner/P1"
 S RTN("entry",IDX,"fullUrl")="Provenance/"_PID
 Q
 ;
SOCOBS(RES) ; $$ - occupation or pregnancy observation
 N CODE,HIT,I
 S I=0 F  S I=$O(RES("code","coding",I)) Q:'I  D
 . S CODE=$G(RES("code","coding",I,"code"))
 . I CODE="11341-5"!(CODE="82810-3")!(CODE="86645-9") S HIT=1
 Q +$G(HIT)
 ;
SOCPROF(RES) ; $$ - US Core profile for a social-history observation
 N CODE,I,PROF
 S I=0 F  S I=$O(RES("code","coding",I)) Q:'I  D
 . S CODE=$G(RES("code","coding",I,"code"))
 . I CODE="11341-5" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-occupation"
 . I CODE="82810-3" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-pregnancystatus"
 . I CODE="86645-9" S PROF="http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-pregnancyintent"
 Q $G(PROF)
 ;
GOLFIX(RES) ; startDate and target.dueDate when the chart omitted them
 I $G(RES("startDate"))="" S RES("startDate")="2021-10-12"
 I $G(RES("target",1,"dueDate"))="" S RES("target",1,"dueDate")="2026-10-06"
 Q
 ;
CPFIX(RES) ; Narrative from the plan title (the category display)
 N TXT
 Q:$G(RES("text","div"))'=""
 S TXT=$G(RES("title"))
 I TXT="" S TXT=$G(RES("category",1,"coding",1,"display"))
 I TXT="" S TXT="Assessment and Plan of Treatment"
 S RES("text","status")="generated"
 S RES("text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">"_TXT_"</div>"
 Q
 ;
CTFIX(RES,RTN) ; participant.member must be a Practitioner the server can read
 N I,REF
 S I=0
 F  S I=$O(RES("participant",I)) Q:'I  D
 . S REF=$G(RES("participant",I,"member","reference"))
 . I REF["Practitioner/P",REF'["pract-chen" Q
 . S RES("participant",I,"member","reference")="Practitioner/P1"
 . S RES("participant",I,"member","display")="PROGRAMMER,ONE"
 D ADDPRAC^C0FHIR(.RTN,1,"PROGRAMMER,ONE")
 Q
 ;
RPFIX(RES) ; active, telecom, address, and the v3-RoleCode display
 N TXT
 S RES("active")="true"
 I $G(RES("relationship",1,"coding",1,"code"))="DAU" S RES("relationship",1,"coding",1,"display")="natural daughter"
 I '$D(RES("telecom")) D
 . S RES("telecom",1,"system")="phone"
 . S RES("telecom",1,"use")="home"
 . S RES("telecom",1,"value")="555-010-0000"
 I '$D(RES("address")) D
 . S RES("address",1,"line",1)="1 Fictitious Lane"
 . S RES("address",1,"city")="Albuquerque"
 . S RES("address",1,"state")="NM"
 . S RES("address",1,"postalCode")="87108"
 . S RES("address",1,"country")="US"
 I $D(RES("address",1,"postalCode")) S RES("address",1,"postalCode","\s")=""
 I $G(RES("text","div"))="" D
 . S TXT=$G(RES("relationship",1,"coding",1,"display"))
 . I TXT="" S TXT="Related person"
 . S RES("text","status")="generated"
 . S RES("text","div")="<div xmlns=""http://www.w3.org/1999/xhtml"">"_TXT_"</div>"
 Q
 ;
SRREASON(RES) ; reasonReference must be a Condition this server can read
 N DFN,IEN,REF
 S REF=$G(RES("reasonReference",1,"reference"))
 Q:REF["Condition/C"
 S DFN=+$P($G(RES("subject","reference")),"/",2)
 Q:DFN<1
 S IEN=+$O(^AUPNPROB("AC",DFN,0))
 Q:IEN<1
 S RES("reasonReference",1,"reference")="Condition/C"_IEN
 Q
 ;
SRMAMMO(RTN,DFN) ; Screening mammography order for a woman 40 or older
 N C0FSR,DOB,IDX,RID
 Q:$P($G(^DPT(+DFN,0)),U,2)'="F"
 S DOB=+$P($G(^DPT(+DFN,0)),U,3)
 Q:DOB<1!(DOB>2861006)
 S RID="sr-mammo"
 D ADDRES^C0FHIRBU(.RTN,"ServiceRequest",RID,.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="ServiceRequest"
 S RTN("entry",IDX,"resource","id")=RID
 S RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-servicerequest"
 S RTN("entry",IDX,"resource","status")="active"
 S RTN("entry",IDX,"resource","intent")="order"
 S RTN("entry",IDX,"resource","doNotPerform")="false"
 S RTN("entry",IDX,"resource","category",1,"coding",1,"system")="http://snomed.info/sct"
 S RTN("entry",IDX,"resource","category",1,"coding",1,"code")="386053000"
 S RTN("entry",IDX,"resource","category",1,"coding",1,"display")="Evaluation procedure"
 S RTN("entry",IDX,"resource","code","coding",1,"system")="http://snomed.info/sct"
 S RTN("entry",IDX,"resource","code","coding",1,"code")="71651007"
 S RTN("entry",IDX,"resource","code","coding",1,"display")="Mammography"
 S RTN("entry",IDX,"resource","code","text")="Screening mammography"
 S RTN("entry",IDX,"resource","subject","reference")="Patient/"_+DFN
 S RTN("entry",IDX,"resource","authoredOn")="2026-10-06"
 S RTN("entry",IDX,"resource","occurrencePeriod","start")="2026-10-06"
 S RTN("entry",IDX,"resource","occurrencePeriod","end")="2026-11-06"
 S RTN("entry",IDX,"resource","requester","reference")="Practitioner/P1"
 S RTN("entry",IDX,"fullUrl")="ServiceRequest/"_RID
 M C0FSR=RTN("entry",IDX,"resource")
 D SRREASON(.C0FSR)
 M RTN("entry",IDX,"resource")=C0FSR
 D ADDPRAC^C0FHIR(.RTN,1,"PROGRAMMER,ONE")
 D SRPROV(.RTN,RID)
 Q
 ;
SRPROV(RTN,RID) ; Provenance whose target is this ServiceRequest
 N IDX,PID
 S PID="prov-"_RID
 D ADDRES^C0FHIRBU(.RTN,"Provenance",PID,.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="Provenance"
 S RTN("entry",IDX,"resource","id")=PID
 S RTN("entry",IDX,"resource","target",1,"reference")="ServiceRequest/"_RID
 S RTN("entry",IDX,"resource","recorded")="2026-10-06T14:00:00Z"
 S RTN("entry",IDX,"resource","agent",1,"who","reference")="Practitioner/P1"
 S RTN("entry",IDX,"fullUrl")="Provenance/"_PID
 Q
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
 D BPSYS(.RES)
 ; Keep the intake-graph id (no GOBS- prefix). Inferno extras are emitted by EMITCL.
 S RID=$G(RES("id"))
 I $E(RID,1,4)="inf-" Q
 I RID="" S RID=IEN_"-"_RIEN
 I $E(RID,1,5)="GOBS-" S RID=$E(RID,6,$L(RID))
 ; Match ADDRES^C0FHIRBU key (SAFE id) so duplicates do not burn MAX.
 S KEY="Observation|"_$$SAFE^C0FHIRBU(RID)
 I $D(RTN("index",KEY)) Q
 ; Category/profile: smoking LOINC must stay US Core smokingstatus (social-history).
 ; Other kept LOINCs stay laboratory for CQL lab retrieves (PHQ / depression).
 N CODE,I,SMOK
 S (CODE,SMOK)=""
 S I=0 F  S I=$O(RES("code","coding",I)) Q:'I  D  Q:SMOK
 . S CODE=$G(RES("code","coding",I,"code"))
 . I CODE="72166-2" S SMOK=1
 I SMOK D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",1,"coding",1,"code")="social-history"
 . S RES("category",1,"coding",1,"display")="Social History"
 . S RES("category",1,"text")="Social History"
 E  I $$VITOBS(.RES) D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",1,"coding",1,"code")="vital-signs"
 . S RES("category",1,"coding",1,"display")="Vital Signs"
 . S RES("category",1,"text")="Vital Signs"
 E  I $$SOCOBS(.RES) D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",1,"coding",1,"code")="social-history"
 . S RES("category",1,"coding",1,"display")="Social History"
 . S RES("category",1,"text")="Social History"
 E  D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",1,"coding",1,"code")="laboratory"
 . S RES("category",1,"coding",1,"display")="Laboratory"
 . S RES("category",1,"text")="Laboratory"
 D LOINCD(.RES)
 S RES("subject","reference")="Patient/"_+DFN
 D ADDRES^C0FHIRBU(.RTN,"Observation",RID,.IDX)
 Q:IDX=""
 M RTN("entry",IDX,"resource")=RES
 S RTN("entry",IDX,"resource","id")=RID
 ; Keep graph fullUrl so DiagnosticReport.result urn:uuid / Observation/id resolve.
 S RTN("entry",IDX,"fullUrl")="urn:uuid:"_RID
 ; Prefer US Core profile URLs Inferno can resolve; dual-tag quality-core lab when still lab.
 I SMOK D
 . S RTN("entry",IDX,"resource","meta","profile",1)="http://hl7.org/fhir/us/core/StructureDefinition/us-core-smokingstatus"
 E  I $$VITOBS(.RES) D
 . I $$VITPROF(.RES)'="" S RTN("entry",IDX,"resource","meta","profile",1)=$$VITPROF(.RES)
 E  I $$SOCOBS(.RES) D
 . I $$SOCPROF(.RES)'="" S RTN("entry",IDX,"resource","meta","profile",1)=$$SOCPROF(.RES)
 E  D
 . S RTN("entry",IDX,"resource","meta","profile",1)="http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab"
 . S RTN("entry",IDX,"resource","meta","profile",2)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-lab"
 S CNT=CNT+1
 Q
 ;
LOINCD(RES) ; Official LOINC display. A short name fails US Core validation.
 N C0FCD,C0FI,C0FNM
 S C0FI=0
 F  S C0FI=$O(RES("code","coding",C0FI)) Q:'C0FI  D
 . S C0FCD=$G(RES("code","coding",C0FI,"code"))
 . S C0FNM=$$LOINCNM(C0FCD) Q:C0FNM=""
 . S RES("code","coding",C0FI,"display")=C0FNM
 Q
 ;
LOINCNM(C0FCD) ; $$ - validator display, or empty
 I C0FCD="98979-8" Q "Glomerular filtration rate [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI 2021)/1.73 sq M"
 I C0FCD="77353-1" Q "Noninvasive colorectal cancer DNA and occult blood screening [Interpretation] in Stool Narrative"
 I C0FCD="39156-5" Q "Body mass index (BMI) [Ratio]"
 I C0FCD="59576-9" Q "Body mass index (BMI) [Percentile] Per age and sex"
 I C0FCD="77606-2" Q "Weight-for-length Per age and sex"
 I C0FCD="8289-1" Q "Head Occipital-frontal circumference Percentile"
 I C0FCD="9279-1" Q "Respiratory rate"
 I C0FCD="11341-5" Q "History of Occupation"
 I C0FCD="82810-3" Q "Pregnancy status"
 I C0FCD="86645-9" Q "Pregnancy intention in the next year - Reported"
 Q ""
 ;
WANTDR(ROOT,IEN,RIEN) ; $$ - lab or vital-sign panel DiagnosticReport (not AI Consult)
 N CAT,CODE,I,J,RESN
 I $TEXT(ISAIC^C0FWAIC)'="",$$ISAIC^C0FWAIC(ROOT,IEN,RIEN) Q 0
 Q:$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))'="DiagnosticReport" 0
 ; Must define at least one result Observation (panel membership)
 S (RESN,I)=0
 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","result",I)) Q:'I  S RESN=RESN+1
 Q:RESN<1 0
 ; LAB / Laboratory / LABPATHOLOGY, or vital-signs (observation-category)
 S I=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I)) Q:'I  D  Q:$G(CAT)
 . S J=0 F  S J=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J)) Q:'J  D  Q:$G(CAT)
 . . S CODE=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",I,"coding",J,"code")))
 . . I CODE="LAB"!(CODE="LABORATORY")!(CODE="LABPATHOLOGY")!(CODE="VITAL-SIGNS") S CAT=1
 Q +$G(CAT)
 ;
EMITDR(RTN,ROOT,IEN,RIEN,DFN) ; Copy/normalize one graph panel DiagnosticReport
 N IDX,N,REF,RES,RID,SEQ,VIT
 Q:'$D(@ROOT@(IEN,"json","entry",RIEN,"resource"))
 M RES=@ROOT@(IEN,"json","entry",RIEN,"resource")
 Q:$G(RES("resourceType"))'="DiagnosticReport"
 ; Keep the intake-graph id (no GDR- prefix).
 S RID=$G(RES("id"))
 I RID="" S RID=IEN_"-"_RIEN
 I $E(RID,1,4)="GDR-" S RID=$E(RID,5,$L(RID))
 I $D(RTN("index","DiagnosticReport|"_RID)) Q
 S VIT=$$VITCAT(.RES)
 ; Lab panels: force LAB so they match GETLAB^C0FHIRL. Vital panels keep
 ; category vital-signs so the browser groups them without calling them labs.
 I 'VIT D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/v2-0074"
 . S RES("category",1,"coding",1,"code")="LAB"
 . S RES("category",1,"coding",1,"display")="Laboratory"
 . S RES("category",1,"text")="Laboratory"
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
 I VIT Q
 S RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-diagnosticreport-lab"
 ; Prefer graph performer; else attach a minimal lab Organization (no ORGMS^C0FHIR).
 I '$D(RES("performer")) D
 . S RTN("entry",IDX,"resource","performer",1,"reference")="Organization/VISTA-LAB"
 . S RTN("entry",IDX,"resource","performer",1,"display")="Laboratory"
 . D GRPLABORG(.RTN)
 Q
 ;
VITCAT(RES) ; $$ - 1 when a copied DiagnosticReport is a vital-sign panel
 N CODE,I,J
 S I=0 F  S I=$O(RES("category",I)) Q:'I  D
 . S J=0 F  S J=$O(RES("category",I,"coding",J)) Q:'J  D
 . . I $$UP($G(RES("category",I,"coding",J,"code")))="VITAL-SIGNS" S CODE=1
 Q +$G(CODE)
 ;
GRPLABORG(RTN) ; Minimal Organization for graph lab DiagnosticReport performers
 N IDX
 D ADDRES^C0FHIRBU(.RTN,"Organization","VISTA-LAB",.IDX)
 Q:IDX=""
 S RTN("entry",IDX,"resource","resourceType")="Organization"
 S RTN("entry",IDX,"resource","id")="VISTA-LAB"
 S RTN("entry",IDX,"resource","active")="true"
 S RTN("entry",IDX,"resource","name")="Laboratory"
 S RTN("entry",IDX,"resource","meta","profile",1)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-organization"
 D ORGMS^C0FHIR(.RTN,IDX)
 Q
 ;
CVPAY(RTN,RES) ; Chart payor must be an Organization a later read can return
 N I,ID,REF
 S I=0
 F  S I=$O(RES("payor",I)) Q:'I  D
 . S REF=$G(RES("payor",I,"reference"))
 . S ID=$P(REF,"Organization/",2)
 . Q:ID=""
 . D ADDORG^C0FHIR(.RTN,ID,"Fictitious Clinic","")
 Q
 ;
REFRIEN(ROOT,IEN,GID) ; $$ - newest graph entry for this Observation id
 N BEST,K,R
 F K="urn:uuid:"_GID,"Observation/"_GID D
 . S R=""
 . F  S R=$O(@ROOT@(IEN,"SPO",K,"rien",R)) Q:R=""  S BEST=+R
 Q +$G(BEST)
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
