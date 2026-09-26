C0FRABOOT ; Codex - Bootstrap minimal RA mammo site for RPMS demos ;Aug 02, 2026
 ;;0.1;C0FHIR PROJECT;;Aug 02, 2026
 ;
 ; Ensures mammo procedure type, hospital location, imaging location (#79.1),
 ; and division link exist so ORDER^RAMAG02 / C0FWSR can file ServiceRequests.
 ;
 Q
 ;
EN() ; $$ - MAGLOC^SCIEN^msg  (>0 MAGLOC on success)
 N LI,MAGLOC,MSG,P,SCIEN,U
 S U="^",MSG=""
 ; Mammo procedures must use imaging type 9 (MAMMOGRAPHY)
 F P=435,436 I $D(^RAMIS(71,P,0)) S:$P(^(0),U,12)'=9 $P(^(0),U,12)=9
 ; Seed imaging stop code used by #79.1 FileMan screen (optional)
 I '$D(^RAMIS(71.5,"B",73)) D
 . S ^RAMIS(71.5,73,0)=73
 . S ^RAMIS(71.5,"B",73,73)=""
 . S:$G(^RAMIS(71.5,0))="" ^RAMIS(71.5,0)="IMAGING STOP CODES^71.5IP^^"
 . S $P(^RAMIS(71.5,0),U,3)=73,$P(^(0),U,4)=+$P(^(0),U,4)+1
 ; Hospital location (#44)
 S SCIEN=+$O(^SC("B","MAMMOGRAPHY",0))
 I SCIEN<1 D
 . S SCIEN=+$O(^SC(" "),-1)+1
 . I SCIEN<1 S SCIEN=100
 . S ^SC(SCIEN,0)="MAMMOGRAPHY^MAMMO^C^7819^^^73^0^^^^^^^1^^N^^Y^^0^1"
 . S ^SC("B","MAMMOGRAPHY",SCIEN)=""
 . S ^SC("C","MAMMO",SCIEN)=""
 ; Imaging location (#79.1) type 9
 S MAGLOC=$$FINDML()
 I MAGLOC<1 D
 . S MAGLOC=+$O(^RA(79.1," "),-1)+1
 . I MAGLOC<1 S MAGLOC=1
 . S ^RA(79.1,MAGLOC,0)=SCIEN_"^^^^^9"
 . S ^RA(79.1,MAGLOC,"DIV")=7819
 . S ^RA(79.1,"B",SCIEN,MAGLOC)=""
 . S ^RA(79.1,"BIMG",9,MAGLOC)=""
 . S:$G(^RA(79.1,0))="" ^RA(79.1,0)="IMAGING LOCATIONS^79.1IP^^"
 . S $P(^RA(79.1,0),U,3)=MAGLOC,$P(^(0),U,4)=+$P(^(0),U,4)+1
 . S LI=+$O(^RA(79,7819,"L"," "),-1)+1
 . I LI<1 S LI=1
 . S ^RA(79,7819,"L",0)="^79.02PA^"_LI_"^"_LI
 . S ^RA(79,7819,"L",LI,0)=MAGLOC
 . S ^RA(79,7819,"L","B",MAGLOC,LI)=""
 . S ^RA(79,"AL",MAGLOC,7819)=""
 I +$P($G(^RA(79.1,MAGLOC,0)),U)<1 Q "-1^imaging location missing hospital location"
 I +$P($G(^RA(79.1,MAGLOC,0)),U,6)'=9 Q "-1^imaging location type is not MAMMOGRAPHY"
 I +$G(^RA(79.1,MAGLOC,"DIV"))<1 S ^RA(79.1,MAGLOC,"DIV")=7819
 S MSG="MAGLOC="_MAGLOC_" SCIEN="_SCIEN
 Q MAGLOC_U_SCIEN_U_MSG
 ;
FINDML() ; $$ - existing type-9 imaging location IEN
 N I,Y
 S Y=0,I=0
 F  S I=$O(^RA(79.1,I)) Q:'I  D  Q:Y
 . I +$P($G(^RA(79.1,I,0)),U,6)=9 S Y=I
 Q +Y
 ;
SPIKE(DFN) ; $$ - place one mammo order; returns RAOIFN or -1^msg
 N HIST,MAGLOC,PROV,RACAT,RADTE,RAMAG,RAMISC,RAOIFN,RAPROC,RAREASON,REQLOC,RET,SCIEN,U,X
 S U="^",DFN=+$G(DFN) I DFN<1 S DFN=4
 I +$G(DUZ)<1 D DUZ^XUP(1)
 I $G(DUZ("AG"))="" S DUZ("AG")="I"
 S RET=$$EN()
 I +RET<1 Q RET
 S MAGLOC=+RET,SCIEN=+$P(RET,U,2)
 S RET=$$REGPT(DFN) I +RET<1 Q RET
 S RAPROC=+$O(^RAMIS(71,"B","MAMMOGRAM BILAT",0))
 I RAPROC<1 S RAPROC=+$O(^RAMIS(71,"B","MAMMOGRAM UNILAT",0))
 I RAPROC<1 Q "-1^no mammo procedure in #71"
 S REQLOC=SCIEN,PROV=+DUZ,RAREASON="Screening mammography",HIST="C0FRABOOT spike"
 S X="ORDER^RAMAG02" I $T(@X)="" Q "-1^RAMAG02 missing"
 S RADTE=$$NOW^XLFDT,RACAT="O"
 K RAMISC,RAMAG
 S RAMISC("ACLHIST",1)=HIST,RAMISC("PREGNANT")="N"
 S RAOIFN=$$ORDER^RAMAG02(.RAMAG,DFN,MAGLOC,RAPROC,RADTE,RACAT,REQLOC,PROV,RAREASON,.RAMISC)
 Q RAOIFN
 ;
REGPT(DFN) ; $$ - ensure patient exists in RAD/NUC MED PATIENT (#70)
 N RC,TXT
 S DFN=+DFN
 Q:DFN<1 "-1^bad DFN"
 Q:$D(^RADPT(DFN)) DFN
 S RC=$$RAPTREG^RAMAGU04(DFN,"O")
 I +RC>0 Q +RC
 ; FileMan path failed on some RPMS builds; seed a minimal #70 row.
 S ^RADPT(DFN,0)=DFN_"^^^O^^"_+DUZ
 S ^RADPT("B",DFN,DFN)=""
 S:$G(^RADPT(0))="" ^RADPT(0)="RAD/NUC MED PATIENT^70IP^^"
 S $P(^RADPT(0),U,3)=DFN,$P(^(0),U,4)=+$P(^(0),U,4)+1
 Q:$D(^RADPT(DFN)) DFN
 S TXT=$G(RC) I TXT="" S TXT="unable to register radiology patient"
 Q "-1^"_TXT
 ;
