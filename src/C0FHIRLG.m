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
 ; Panel DiagnosticReports keep graph ids/fullUrls so result[] links resolve.
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
 . I $$WANT(ROOT,IEN,RIEN) S KEEP(RIEN)=""
 ; Newest effective/issued first (MAX keeps the newest, not newest IEN).
 S RIEN=0
 F  S RIEN=$O(KEEP(RIEN)) Q:'RIEN  D
 . I '$$INWIN(ROOT,IEN,RIEN,BEG,END) Q
 . S BYDT($$RESDT(ROOT,IEN,RIEN),RIEN)=""
 S DT=""
 F  S DT=$O(BYDT(DT),-1) Q:DT=""!(CNT'<MAX)  D
 . S RIEN=0
 . F  S RIEN=$O(BYDT(DT,RIEN)) Q:'RIEN!(CNT'<MAX)  D EMIT(.RTN,ROOT,IEN,RIEN,DFN,.CNT)
 ; Lab panel DiagnosticReports (category LAB) with result[] links
 D GETGRPDR(.RTN,ROOT,IEN,DFN,BEG,END)
 ; REFFIX re-points panel result[] at in-bundle Observations (MAX / ^LR).
 ; It does not EMIT the rest: that added ~3,800 Observations and ~50 C0RG
 ; slices (2026-09-15 HARBER). Unmatched members keep their graph refs.
 ; Restore emit: S ^C0FHIR("EXPERIMENT","REFFIXEMIT")=1
 D REFFIX(.RTN,ROOT,IEN,DFN)
 Q
 ;
GETGRPNL(RTN,DFN,BEG,END) ; Append graph panel DiagnosticReports ONLY (VistA hosts)
 ; ^LR stores individual results, not panel groupings, so lab panels exist
 ; only in fhir-intake (C0FWLAB GRAPHOK). When graph labs are OFF (labs-of-
 ; record are ^LR), merge just the panels: no graph Observations are added,
 ; so ISI-filed labs are not duplicated. result[] references keep their graph
 ; Observation ids and may not resolve inside the returned bundle.
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
 . S LNC="",J=0
 . F  S J=$O(RTN("entry",I,"resource","code","coding",J)) Q:'J!(LNC'="")  I $G(RTN("entry",I,"resource","code","coding",J,"system"))["loinc" S LNC=$G(RTN("entry",I,"resource","code","coding",J,"code"))
 . I LNC'="" D KEYADD(.OIDX,"L|"_LNC_"|"_TK,VAL,OID)
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
 . . S RIEN=+$O(@ROOT@(IEN,"SPO","urn:uuid:"_GID,"rien","")) Q:RIEN<1
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
 E  D
 . S RES("category",1,"coding",1,"system")="http://terminology.hl7.org/CodeSystem/observation-category"
 . S RES("category",1,"coding",1,"code")="laboratory"
 . S RES("category",1,"coding",1,"display")="Laboratory"
 . S RES("category",1,"text")="Laboratory"
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
 E  D
 . S RTN("entry",IDX,"resource","meta","profile",1)="http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab"
 . S RTN("entry",IDX,"resource","meta","profile",2)="http://fhir.org/guides/onc/us-quality-core/StructureDefinition/us-quality-core-observation-lab"
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
