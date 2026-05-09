C0FWCTX ; VEHU/Codex - C0FW runtime context ;May 09, 2026
 ;;0.1;C0FHIR PROJECT;;May 09, 2026
 ;
 Q
 ;
DUZ() ; Establish minimal Kernel user context for C0FW update paths
 I $G(DUZ)="" S DUZ=+$G(^TMP("C0FW",$J,"DUZ"))
 I $G(DUZ)="" S DUZ=1
 I $G(DUZ("AG"))="" S DUZ("AG")="V"
 I $G(DUZ(2))="" S DUZ(2)=+$G(^TMP("C0FW",$J,"DUZ",2))
 I $G(DUZ(2))="" S DUZ(2)=500
 Q DUZ
 ;
SYS() ; $$ - stable system id used in reminder UIDs
 N SYS
 S SYS=$G(^TMP("C0FW",$J,"SYS"))
 I SYS'="" Q SYS
 S SYS=$P($G(^XTV(8989.3,1,"XUS")),U,17)
 I SYS'="" Q SYS
 Q "vista"
 ;
