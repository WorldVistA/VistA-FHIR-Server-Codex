C0FGRPDR ; probe graph DiagnosticReports ;Aug 03, 2026
 Q
 ;
EN(DFN) ;
 N CAT,CODE,I,IEN,N,RESN,RIEN,ROOT,RID
 S DFN=+$G(DFN) S:DFN<1 DFN=8
 S ROOT=$$ROOT^C0FWFUTL()
 S IEN=$$DFN2IEN^C0FWFUTL(DFN)
 W "ROOT=",ROOT," IEN=",IEN,!
 S (RIEN,N)=0
 F  S RIEN=$O(@ROOT@(IEN,"type","DiagnosticReport",RIEN)) Q:'RIEN!(N>12)  D
 . S N=N+1
 . S RID=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","id"))
 . S CODE=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","code","coding",1,"code"))
 . S CAT=$G(@ROOT@(IEN,"json","entry",RIEN,"resource","category",1,"coding",1,"code"))
 . S RESN=0 F  S I=$O(@ROOT@(IEN,"json","entry",RIEN,"resource","result",I)) Q:'I  S RESN=RESN+1
 . W "RIEN=",RIEN," id=",RID," cat=",CAT," code=",CODE," results=",RESN,!
 S (RIEN,N)=0
 F  S RIEN=$O(@ROOT@(IEN,"type","DiagnosticReport",RIEN)) Q:'RIEN  S N=N+1
 W "total DiagnosticReport=",N,!
 Q
 ;