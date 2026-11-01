C0FWCTX ; VEHU/Codex - C0FW runtime context ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
DUZ() ; Establish minimal Kernel user context for C0FW update paths
 I +$G(DUZ)<1 S DUZ=+$G(^TMP("C0FW",$J,"DUZ"))
 I +$G(DUZ)<1 S DUZ=1
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I +$G(DUZ(2))<1 S DUZ(2)=+$G(^TMP("C0FW",$J,"DUZ",2))
 I +$G(DUZ(2))<1 S DUZ(2)=$$DIV()
 I +$G(DT)<1 S DT=$$DT^XLFDT
 Q DUZ
 ;
DIV() ; $$ - institution for web-job filing (lab accession areas key on DUZ(2))
 ; Kernel semantics first: the filing user's division. 500 is the VEHU demo
 ; site; FOIA also has an institution 500, but its Lab config (C0FZLACC)
 ; hangs on institution 1, the division of USER,ONE. A fixed 500 there left
 ; every lab order "NOT ACCESSIONED" with no ^LR data (iris2, 2026-11-01).
 N DIV S DIV=+$P($G(^VA(200,+$G(DUZ),2,1,0)),"^")
 I DIV>0 Q DIV
 I $D(^DIC(4,500,0)) Q 500
 S DIV=+$O(^DIC(4,0))
 Q $S(DIV>0:DIV,1:500)
 ;
IO() ; Establish minimal IO variables used by filing APIs in web jobs
 ; Web jobs have no Kernel home device: ^%ZISC sets IO(0)=$P (the client
 ; socket) when IO(0) is undefined, after which VistA echo output (e.g. the
 ; DIC patient display from EN^LRDPA) lands ahead of the HTTP headers.
 ; Home IO/IO(0) on the current device, which %webrsp sets to /dev/null.
 I $G(IO(0))="" S IO(0)=$IO
 I $G(IO)="" S IO=$IO
 I $G(IOST)="" S IOST="C-VT100"
 I +$G(IOM)<1 S IOM=80
 I +$G(IOSL)<1 S IOSL=24
 Q
 ;
SYS() ; $$ - stable system id used in reminder UIDs
 N SYS
 S SYS=$G(^TMP("C0FW",$J,"SYS"))
 I SYS'="" Q SYS
 S SYS=$P($G(^XTV(8989.3,1,"XUS")),U,17)
 I SYS'="" Q SYS
 Q "vista"
 ;
