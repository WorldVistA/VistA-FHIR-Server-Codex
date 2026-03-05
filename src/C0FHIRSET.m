C0FHIRSET ; VAMC/JS - FHIR suite environment setup
 ;;0.1;VISTA FHIR SERVER;**0**;Mar 03, 2026
 ;
 QUIT  ; No default action
 ;
EN ; Main entry point
 WRITE !!,"--- C0FHIR Environment Setup ---",!
 DO RPC
 DO OPT
 WRITE !!,"Setup complete. RPC and context option are configured.",!
 QUIT
 ;
RPC ; Register/update RPC in File #8994
 NEW DESC,ERR,FDA,IEN,NAME,RPCIEN
 SET NAME="C0FHIR GET FULL BUNDLE"
 WRITE !,"Registering/updating RPC: "_NAME_"..."
SET RPCIEN=+$$FIND1^DIC(8994,"","X",NAME)
 SET IEN=$SELECT(RPCIEN>0:RPCIEN_",",1:"+1,")
 SET FDA(8994,IEN,.01)=NAME
 SET FDA(8994,IEN,.02)="GENFULL"
 SET FDA(8994,IEN,.03)="C0FHIRGF"
 SET FDA(8994,IEN,.04)=2
 SET FDA(8994,IEN,.07)=1
 DO UPDATE^DIE("","FDA","IEN","ERR")
 SET RPCIEN=$SELECT(+$GET(IEN(1))>0:+$GET(IEN(1)),1:RPCIEN)
 IF RPCIEN<1 WRITE " Failed." QUIT
 ;
 ; Add usage guide to RPC Description (#10)
 KILL DESC
 SET DESC(1)="USAGE GUIDE for C0FHIR GET FULL BUNDLE"
 SET DESC(2)="------------------------------------"
 SET DESC(3)="INPUTS:"
 SET DESC(4)="  1. DFN (Req): Internal Patient IEN from File #2."
 SET DESC(5)="  2. ENCPTR (Opt): Internal Encounter IEN from file #9000010."
 SET DESC(6)="  3. SDT (Opt): Start date (FileMan or %DT expression)."
 SET DESC(7)="  4. EDT (Opt): End date (FileMan or %DT expression)."
 SET DESC(8)="  5. MAX (Opt): Max resources to include."
 SET DESC(9)="  6. MODE (Opt): ENCOUNTER or DATERANGE."
 SET DESC(10)="  7. DOMAINS (Opt): Comma-separated domain list."
 SET DESC(11)="     Supported: encounter,condition,vitals,allergy,medication,"
 SET DESC(12)="     immunization,labs (""all"" for default behavior)."
 SET DESC(13)=""
 SET DESC(14)="OUTPUT:"
 SET DESC(15)="  Returns one FHIR R4 Bundle (type=collection) as a JSON array."
 SET DESC(16)="  Includes Patient and selected clinical domains in scope."
 DO WP^DIE(8994,RPCIEN_",",10,"","DESC","ERR")
 ;
 ; Re-sync parameters
KILL ^XWB(8994,RPCIEN,2)
 DO PARAM(RPCIEN,1,"DFN",1)
 DO PARAM(RPCIEN,2,"ENCPTR",0)
 DO PARAM(RPCIEN,3,"SDT",0)
 DO PARAM(RPCIEN,4,"EDT",0)
 DO PARAM(RPCIEN,5,"MAX",0)
 DO PARAM(RPCIEN,6,"MODE",0)
 DO PARAM(RPCIEN,7,"DOMAINS",0)
 WRITE " Success."
 QUIT
 ;
PARAM(RPCIEN,SEQ,PNAME,REQ) ; Add RPC parameter row
 NEW ERR,PFDA
 SET PFDA(8994.02,"+1,"_RPCIEN_",",.01)=PNAME
 SET PFDA(8994.02,"+1,"_RPCIEN_",",.02)=SEQ
 SET PFDA(8994.02,"+1,"_RPCIEN_",",.03)=1
 SET PFDA(8994.02,"+1,"_RPCIEN_",",.04)=REQ
 DO UPDATE^DIE("","PFDA","","ERR")
 QUIT
 ;
OPT ; Create/update context option (#19)
 NEW ERR,FDA,IEN,NAME,OPTIEN,RPCIEN
 SET NAME="C0FHIR CONTEXT"
 WRITE !,"Updating context option: "_NAME_"..."
 SET OPTIEN=+$ORDER(^DIC(19,"B",NAME,0))
 SET IEN=$SELECT(OPTIEN>0:OPTIEN_",",1:"+1,")
 SET FDA(19,IEN,.01)=NAME
 SET FDA(19,IEN,.04)="B"
 SET FDA(19,IEN,1)="Enables C0FHIR dashboard bundle extraction."
 DO UPDATE^DIE("","FDA","IEN","ERR")
 SET OPTIEN=$SELECT(+$GET(IEN(1))>0:+$GET(IEN(1)),1:OPTIEN)
 IF OPTIEN<1 WRITE " Failed." QUIT
 ;
 ; Attach RPC to option
SET RPCIEN=+$$FIND1^DIC(8994,"","X","C0FHIR GET FULL BUNDLE")
 IF RPCIEN<1 WRITE " RPC missing." QUIT
 IF '$DATA(^DIC(19,OPTIEN,10,"B",RPCIEN)) DO
 . KILL FDA,ERR
 . SET FDA(19.05,"+1,"_OPTIEN_",",.01)=RPCIEN
 . DO UPDATE^DIE("","FDA","","ERR")
 WRITE " Success."
 QUIT
 ;
