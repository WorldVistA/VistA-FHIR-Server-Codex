C0FWIDX ; VEHU/Codex - C0FW FHIR graph indexing ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
INDEX(IEN,ROOT) ; Index parsed FHIR JSON in graph row IEN
 N JROOT,JINDEX,WI,TYPE,BUND
 I $G(ROOT)="" S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 I $G(ROOT)="" Q
 I $G(IEN)="" Q
 S JROOT=$NA(@ROOT@(IEN,"json","entry"))
 Q:'$D(@JROOT)
 S JINDEX=$NA(@ROOT@(IEN))
 D CLEAR(JINDEX)
 S WI=0
 F  S WI=$O(@JROOT@(WI)) Q:+WI=0  D
 . S TYPE=$G(@JROOT@(WI,"resource","resourceType"))
 . Q:TYPE=""
 . S @JINDEX@("type",TYPE,WI)=""
 . D TRIPLES(JINDEX,$NA(@JROOT@(WI)),WI,TYPE)
 S BUND=$$BUNDLE(JINDEX)
 S WI=0
 F  S WI=$O(@JROOT@(WI)) Q:+WI=0  D
 . S @JINDEX@(WI,"bundle")=BUND
 . D SETIDX(JINDEX,WI,"bundle",BUND)
 Q
 ;
TRIPLES(INDEX,ARY,WI,TYPE) ; Build graph triples for one FHIR entry
 N PURL,ENC,PAT,SDATE,HL7DATE,CLASS
 S TYPE=$G(TYPE)
 S PURL=$G(@ARY@("fullUrl"))
 I PURL="" S PURL=TYPE_"/"_$G(@ARY@("resource","id"))
 I $E(PURL,$L(PURL))="/" S PURL=PURL_WI
 I TYPE="Patient" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 I TYPE="Encounter" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 . S SDATE=$G(@ARY@("resource","period","start")) Q:SDATE=""
 . S HL7DATE=$$FHIRTHL7^C0FWFUTL(SDATE)
 . D SETIDX(INDEX,PURL,"dateTime",SDATE)
 . D SETIDX(INDEX,PURL,"hl7dateTime",HL7DATE)
 . S CLASS=$G(@ARY@("resource","class","code")) Q:CLASS=""
 . D SETIDX(INDEX,PURL,"class",CLASS)
 I TYPE="Condition" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 . S ENC=$G(@ARY@("resource","context","reference"))
 . I ENC="" S ENC=$G(@ARY@("resource","encounter","reference"))
 . I ENC'="" D SETIDX(INDEX,PURL,"encounterReference",ENC)
 . S PAT=$G(@ARY@("resource","subject","reference"))
 . I PAT'="" D SETIDX(INDEX,PURL,"patientReference",PAT)
 . D ADDCODES(INDEX,PURL,ARY)
 I TYPE="Observation" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 . S ENC=$G(@ARY@("resource","context","reference"))
 . I ENC="" S ENC=$G(@ARY@("resource","encounter","reference"))
 . I ENC'="" D SETIDX(INDEX,PURL,"encounterReference",ENC)
 . S PAT=$G(@ARY@("resource","subject","reference"))
 . I PAT'="" D SETIDX(INDEX,PURL,"patientReference",PAT)
 . D ADDCODES(INDEX,PURL,ARY)
 I TYPE="Medication" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 I TYPE="medicationReference" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 . S ENC=$G(@ARY@("resource","context","reference"))
 . I ENC="" S ENC=$G(@ARY@("resource","encounter","reference")) Q:ENC=""
 . D SETIDX(INDEX,PURL,"encounterReference",ENC)
 . S PAT=$G(@ARY@("resource","subject","reference")) Q:PAT=""
 . D SETIDX(INDEX,PURL,"patientReference",PAT)
 I TYPE="Immunization" D  Q
 . D SETIDX(INDEX,PURL,"type",TYPE)
 . D SETIDX(INDEX,PURL,"rien",WI)
 . S ENC=$G(@ARY@("resource","encounter","reference")) Q:ENC=""
 . D SETIDX(INDEX,PURL,"encounterReference",ENC)
 . S PAT=$G(@ARY@("resource","patient","reference")) Q:PAT=""
 . D SETIDX(INDEX,PURL,"patientReference",PAT)
 D SETIDX(INDEX,PURL,"type",TYPE)
 D SETIDX(INDEX,PURL,"rien",WI)
 S ENC=$G(@ARY@("resource","context","reference"))
 I ENC="" S ENC=$G(@ARY@("resource","encounter","reference"))
 I ENC'="" D SETIDX(INDEX,PURL,"encounterReference",ENC)
 S PAT=$G(@ARY@("resource","subject","reference"))
 I PAT="" S PAT=$G(@ARY@("resource","patient","reference"))
 I PAT'="" D SETIDX(INDEX,PURL,"patientReference",PAT)
 D ADDCODES(INDEX,PURL,ARY)
 Q
 ;
ADDCODES(INDEX,PURL,ARY) ; Index CodeableConcept codes for SPARQL FILTER CONTAINS
 N I,J,C,D
 S I=0 F  S I=$O(@ARY@("resource","code","coding",I)) Q:+I=0  D
 . S C=$G(@ARY@("resource","code","coding",I,"code")) Q:C=""
 . D SETIDX(INDEX,PURL,"code",C)
 . S D=$G(@ARY@("resource","code","coding",I,"display"))
 . I D'="" D SETIDX(INDEX,PURL,"display",D)
 I $G(@ARY@("resource","code","text"))'="" D SETIDX(INDEX,PURL,"display",$G(@ARY@("resource","code","text")))
 S I=0 F  S I=$O(@ARY@("resource","category",I)) Q:+I=0  D
 . S J=0 F  S J=$O(@ARY@("resource","category",I,"coding",J)) Q:+J=0  D
 . . S C=$G(@ARY@("resource","category",I,"coding",J,"code")) Q:C=""
 . . D SETIDX(INDEX,PURL,"category",C)
 S I=0 F  S I=$O(@ARY@("resource","component",I)) Q:+I=0  D
 . S J=0 F  S J=$O(@ARY@("resource","component",I,"code","coding",J)) Q:+J=0  D
 . . S C=$G(@ARY@("resource","component",I,"code","coding",J,"code")) Q:C=""
 . . D SETIDX(INDEX,PURL,"code",C)
 Q
 ;
SETIDX(GN,SUB,PRED,OBJ) ; Set graph indexes on supplied graph node
 D SETIDXGN^C0FWFUTL($G(GN),$G(SUB),$G(PRED),$G(OBJ))
 Q
 ;
BUNDLE(ARY) ; $$ - bundle date range from graph indexes
 N LOW,HIGH
 S LOW=$O(@ARY@("POS","dateTime",""))
 Q:LOW="" ""
 S HIGH=$O(@ARY@("POS","dateTime",""),-1)
 S LOW=$P(LOW,"T",1)
 S HIGH=$P(HIGH,"T",1)
 Q LOW_":"_HIGH
 ;
CLEAR(GN) ; Clear graph indexes
 K @GN@("SPO")
 K @GN@("POS")
 K @GN@("PSO")
 K @GN@("OPS")
 Q
 ;
GETENT(ARY,IEN,RIEN) ; Return one graph entry
 N ROOT
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 Q:'$D(@ROOT@(IEN,"json","entry",RIEN))
 M @ARY@("entry",RIEN)=@ROOT@(IEN,"json","entry",RIEN)
 Q
 ;
LOADSTAT(ARY,IEN,RIEN) ; Return load section for graph row
 N ROOT,ZI
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 Q:'$D(@ROOT@(IEN))
 I $G(RIEN)="" D  Q
 . K @ARY
 . M @ARY@(IEN)=@ROOT@(IEN,"load")
 S ZI=""
 F  S ZI=$O(@ROOT@(IEN,"load",ZI)) Q:ZI=""  Q:$D(@ROOT@(IEN,"load",ZI,RIEN))
 K @ARY
 I ZI'="" M @ARY@(IEN,RIEN)=@ROOT@(IEN,"load",ZI,RIEN)
 Q
 ;
TXLOAD(RETURN,IEN,FIRST,LAST) ; Add transaction load nodes to response
 N ROOT,RIEN,DOMAIN,TYPE
 S ROOT=$$ROOT^C0FWGRT("fhir-intake")
 Q:ROOT=""
 S RETURN("transaction","firstEntry")=+$G(FIRST)
 S RETURN("transaction","lastEntry")=+$G(LAST)
 S RETURN("transaction","entryCount")=$S(+$G(LAST)'<+$G(FIRST):+$G(LAST)-+$G(FIRST)+1,1:0)
 S RIEN=+$G(FIRST)-1
 F  S RIEN=$O(@ROOT@(IEN,"json","entry",RIEN)) Q:+RIEN=0!(RIEN>LAST)  D
 . S TYPE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","resourceType"))
 . S RETURN("transaction","entries",RIEN,"resourceType")=TYPE
 . S DOMAIN=""
 . F  S DOMAIN=$O(@ROOT@(IEN,"load",DOMAIN)) Q:DOMAIN=""  D
 . . Q:'$D(@ROOT@(IEN,"load",DOMAIN,RIEN))
 . . M RETURN("transactionLoad",RIEN,DOMAIN)=@ROOT@(IEN,"load",DOMAIN,RIEN)
 Q
 ;
