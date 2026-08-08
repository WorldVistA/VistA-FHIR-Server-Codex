C0FWSMOK ; VEHU/Codex - C0FW smoking-status Observation -> V Health Factor ;Jul 31, 2026
 ;;0.1;C0FHIR PROJECT;;Jul 31, 2026
 ;
 ; US Core smoking status (LOINC 72166-2) is not a lab. File as V Health Factor
 ; so GETSMOK^C0FHIRD can re-emit Observation for CMS138 / US Core.
 ;
 Q
 ;
LOAD(ROOT,IEN,RIEN,RETURN) ; File smoking-status Observation as V Health Factor
 N DFN,ENCDATA,FMDT,HFIEN,HFNAME,LOC,MSG,NOTE,PKG,RET,SCT,SOURCE,TYPE,USER,VISIT,ZZERR,ZZERDESC
 S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 I TYPE'="Observation" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"C0FWSMOK only files Observation resources",.RETURN) Q
 I '$$ISSMOK(ROOT,IEN,RIEN) D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"Observation is not LOINC 72166-2 smoking status",.RETURN) Q
 S DFN=+$O(@ROOT@("SPO",IEN,"DFN",""))
 I DFN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"No DFN linked to graph row",.RETURN) Q
 S SCT=$$SCTVAL(ROOT,IEN,RIEN)
 I SCT="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"Missing valueCodeableConcept SNOMED smoking status",.RETURN) Q
 S HFNAME=$$HFNAME(SCT,.HFIEN)
 I HFIEN<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"No VistA Health Factor for smoking SNOMED "_SCT,.RETURN) Q
 S VISIT=$$VISIT(ROOT,IEN,RIEN)
 I VISIT<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"Smoking Observation has no resolved encounter visit",.RETURN) Q
 I $$HASHF^C0FWENC(VISIT,HFIEN) D  Q
 . S MSG="Smoking Health Factor already on visit: "_HFNAME
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"loaded",MSG,.RETURN)
 . S RETURN("domains","Smoking","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,VISIT,HFIEN,HFNAME,SCT,"loaded","already-present")
 S FMDT=$$FMDT^C0FWVIT(ROOT,IEN,RIEN)
 I FMDT<1 S FMDT=+$P($G(^AUPNVSIT(VISIT,0)),"^")
 I FMDT<1 S FMDT=$$NOW^XLFDT
 S LOC=+$P($G(^AUPNVSIT(VISIT,0)),"^",22)
 I LOC<1 D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"Visit has no hospital location",.RETURN) Q
 S USER=$$USER^C0FWENC()
 S NOTE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","note",1,"text"))
 I NOTE="" S NOTE="Quality AI Consult CMS138 smoking status ("_SCT_")"
 K ENCDATA,ZZERR,ZZERDESC
 S ENCDATA("ENCOUNTER",1,"PATIENT")=DFN
 S ENCDATA("ENCOUNTER",1,"ENCOUNTER TYPE")="P"
 S ENCDATA("ENCOUNTER",1,"ENC D/T")=FMDT
 S ENCDATA("ENCOUNTER",1,"HOS LOC")=LOC
 S ENCDATA("ENCOUNTER",1,"SERVICE CATEGORY")=$$SERCAT^C0FWENC(FMDT)
 S ENCDATA("PROVIDER",1,"NAME")=USER
 S ENCDATA("PROVIDER",1,"PRIMARY")=1
 S ENCDATA("HEALTH FACTOR",1,"HEALTH FACTOR")=HFIEN
 S ENCDATA("HEALTH FACTOR",1,"EVENT D/T")=FMDT
 S ENCDATA("HEALTH FACTOR",1,"COMMENT")=$E(NOTE,1,245)
 D DUZ^C0FWCTX(),IO^C0FWCTX()
 I $$RPMS^C0FWENC() D  Q
 . D RPMSHF^C0FWENC(.MSG,DFN,VISIT,FMDT,LOC,USER,.ENCDATA,ROOT,IEN,RIEN)
 . I $G(MSG)'="" D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,MSG,.RETURN) Q
 . I '$$HASHF^C0FWENC(VISIT,HFIEN) D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"RPMS Health Factor not found after filing: "_HFNAME,.RETURN) Q
 . S MSG="Smoking status filed as RPMS V Health Factor: "_HFNAME
 . D SET^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"loaded",MSG,.RETURN)
 . S RETURN("domains","Smoking","visitIen")=VISIT
 . D LOG(ROOT,IEN,RIEN,VISIT,HFIEN,HFNAME,SCT,"loaded","rpms")
 S PKG=$$FIND1^DIC(9.4,,"","PCE")
 I PKG<1 S PKG=$$FIND1^DIC(9.4,,"","?")
 S SOURCE="C0FW WRITEBACK"
 S RET=$$DATA2PCE^PXAI("ENCDATA",PKG,SOURCE,.VISIT,USER,"",.ZZERR,"",.ZZERDESC)
 I '$$HASHF^C0FWENC(VISIT,HFIEN) D  Q
 . S MSG="DATA2PCE did not file smoking Health Factor "_HFNAME
 . I $G(RET)'="" S MSG=MSG_" (RET="_RET_")"
 . D ERR^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,MSG,.RETURN)
 . D LOG(ROOT,IEN,RIEN,VISIT,HFIEN,HFNAME,SCT,"error",$G(RET))
 S MSG="Smoking status filed as V Health Factor: "_HFNAME
 D SET^C0FWSTAT(ROOT,IEN,RIEN,"Smoking",TYPE,"loaded",MSG,.RETURN)
 S RETURN("domains","Smoking","visitIen")=VISIT
 D LOG(ROOT,IEN,RIEN,VISIT,HFIEN,HFNAME,SCT,"loaded",$G(RET))
 Q
 ;
ISSMOK(ROOT,IEN,RIEN) ; $$ - true if Observation is US Core smoking status
 N CAT,CODE,NI,SYS,TXT
 S CODE=$$LOINC(ROOT,IEN,RIEN)
 I CODE="72166-2" Q 1
 S CAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",1,"coding",1,"code"))
 S TXT=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","text"))_" "_$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"display")))
 I CAT="social-history",TXT["SMOKING" Q 1
 I CAT="social-history",TXT["TOBACCO" Q 1
 Q 0
 ;
LOINC(ROOT,IEN,RIEN) ; $$ - first LOINC code on Observation.code
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"system")))
 . I SYS'["LOINC" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",NI,"code"))
 I $G(CODE)="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 Q $G(CODE)
 ;
SCTVAL(ROOT,IEN,RIEN) ; $$ - SNOMED code from valueCodeableConcept
 N CODE,NI,SYS
 S NI=0 F  S NI=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","valueCodeableConcept","coding",NI)) Q:+NI=0  D  Q:$G(CODE)'=""
 . S SYS=$$UP($G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueCodeableConcept","coding",NI,"system")))
 . I SYS'["SNOMED",SYS'["SCT" Q
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueCodeableConcept","coding",NI,"code"))
 I $G(CODE)="" S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","valueCodeableConcept","coding",1,"code"))
 Q $G(CODE)
 ;
HFNAME(SCT,HFIEN) ; $$ - preferred AUTTHF name; HFIEN by ref
 N CAND,FOUND,I,NAME
 S (HFIEN,FOUND)=0,SCT=$G(SCT)
 ; Prefer LCS names used by tobacco reminder writeback / GETSMOK^C0FHIRD.
 I SCT="266919005" S CAND="LCS LIFETIME NON-SMOKER^LIFETIME NON-SMOKER^LIFETIME NON-TOBACCO USER^ONS TOBACCO LIFETIME NON-USER"
 E  I SCT="449868002" S CAND="LCS CURRENT SMOKER^CURRENT SMOKER^ONS TOBACCO USE CURRENT"
 E  I SCT="8517006" S CAND="LCS FORMER SMOKER^PREVIOUS SMOKER^FORMER SMOKER - <100 LIFETIME CIGARETTES"
 E  Q ""
 F I=1:1:$L(CAND,"^") S NAME=$P(CAND,"^",I) D  Q:HFIEN>0
 . S HFIEN=+$O(^AUTTHF("B",NAME,0))
 . I HFIEN>0 S FOUND=NAME
 Q $S(HFIEN>0:FOUND,1:"")
 ;
VISIT(ROOT,IEN,RIEN) ; $$ - visit ien from Observation.encounter
 N REF,VISIT
 S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","encounter","reference"))
 I REF="" S REF=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","context","reference"))
 S VISIT=$$VISITREF^C0FWENC(ROOT,IEN,REF)
 I VISIT<1 S VISIT=$$TXVISIT^C0FWCON(ROOT,IEN,REF)
 Q +VISIT
 ;
LOG(ROOT,IEN,RIEN,VISIT,HFIEN,HFNAME,SCT,STATUS,RAW) ; Persist load details
 S @ROOT@(IEN,"load","Smoking",RIEN,"engine")="C0FW/PCE"
 S @ROOT@(IEN,"load","Smoking",RIEN,"file")=9000010.23
 S @ROOT@(IEN,"load","Smoking",RIEN,"visitIen")=+$G(VISIT)
 S @ROOT@(IEN,"load","Smoking",RIEN,"hfIen")=+$G(HFIEN)
 S @ROOT@(IEN,"load","Smoking",RIEN,"hfName")=$G(HFNAME)
 S @ROOT@(IEN,"load","Smoking",RIEN,"sct")=$G(SCT)
 S @ROOT@(IEN,"load","Smoking",RIEN,"rawStatus")=$G(RAW)
 S @ROOT@(IEN,"load","Smoking",RIEN,"loadStatus")=$G(STATUS)
 Q
 ;
UP(X) ; $$ - uppercase
 Q $TR($G(X),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
