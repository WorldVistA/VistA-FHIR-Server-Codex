C0TSWSU ; GPL - Utilities for C0TS; 7/4/15 6:03pm
 ;;1.0;C0TS VISTA TERMINOLOGY SERVER;;Mar 21, 2016;Build 1
 ;
 Q
 ;
STARTTM(ARY) ; timestamp the start time
 S @ARY@("startTimeFM")=$$TIMEI
 S @ARY@("startTime")=$$TIMEE(@ARY@("startTimeFM"))
 Q
 ;
ENDTM(ARY) ; timestamp the start time
 S @ARY@("endTimeFM")=$$TIMEI
 S @ARY@("endTime")=$$TIMEE(@ARY@("endTimeFM"))
 S @ARY@("elapsedTime")=$$ELAPSED(@ARY@("endTimeFM"),@ARY@("startTimeFM")) ;
 ; in seconds
 Q
 ;
ELAPSED(END,START) ; elapsed time in seconds. end and start are FM format
 Q $$FMDIFF^XLFDT(END,START,2)
TIMEI() ; internal time
 Q $$NOW^XLFDT
 ;
TIMEE(FMTIME) ; external time
 Q $$FMTE^XLFDT(FMTIME)
 ;
ADDAT(OUTARY,INARY,TAG) ; both passed by name..
 ;  INARY("ATTR")="XX" is converted to OUTARY("TAG@ATTR")="XX"
 ;   to make better xml - only works with simple arrays
 I '$D(TAG) S TAG="item"
 N ZI S ZI=""
 F  S ZI=$O(@INARY@(ZI)) Q:ZI=""  D  ;
 . S @OUTARY@(TAG_"@"_ZI)=@INARY@(ZI)
 Q
 ;
TESTADD ; test of ADDAT routine
 N GN S GN=$NA(^XTMP("EHEXPAT",1))
 N GPL
 D ADDAT("GPL",GN,"patient")
 ZWR GPL
 Q
 ;
GENHTML2(HOUT,HARY) ; generate an HTML table from array HARY
 ; HOUT AND HARY are passed by name
 ;
 ;  HARY("TITLE")="Problem List"
 ;  HARY("HEADER",1)="column 1 header"
 ;  HARY("HEADER",2)="col 2 header"
 ;  HARY(1,1)="row 1 col1 value"
 ;  HARY(1,2)="row 1 col2 value"
 ;  HARY(1,2,"ID")="the ID of the element" 
 ;  etc...
 ;
 N C0I,C0J
 D ADDTO(HOUT,"<div align=""center"">")
 ;I $D(@HARY@("TITLE")) D  ;
 ;. N X
 ;. S X="<title>"_@HARY@("TITLE")_"</title>"
 ;. D ADDTO(HOUT,X)
 D ADDTO(HOUT,"<text>")
 D ADDTO(HOUT,"<table border=""1"" style=""width:80%"">")
 I $D(@HARY@("TITLE")) D  ;
 . N X
 . S X="<caption><b>"_@HARY@("TITLE")_"</b></caption>"
 . D ADDTO(HOUT,X)
 I $D(@HARY@("HEADER")) D  ;
 . D ADDTO(HOUT,"<thead>")
 . D ADDTO(HOUT,"<tr>")
 . S C0I=0
 . F  S C0I=$O(@HARY@("HEADER",C0I)) Q:+C0I=0  D  ;
 . . D ADDTO(HOUT,"<th>"_@HARY@("HEADER",C0I)_"</th>")
 . D ADDTO(HOUT,"</tr>")
 . D ADDTO(HOUT,"</thead>")
 D ADDTO(HOUT,"<tbody>")
 I $D(@HARY@(1)) D  ;
 . S C0I=0 S C0J=0
 . F  S C0I=$O(@HARY@(C0I)) Q:+C0I=0  D  ;
 . . D ADDTO(HOUT,"<tr>")
 . . F  S C0J=$O(@HARY@(C0I,C0J)) Q:+C0J=0  D  ;
 . . . N UID S UID=$G(@HARY@(C0I,C0J,"ID"))
 . . . I UID'="" D ADDTO(HOUT,"<td style=""padding:5px;"" ID="""_UID_""">"_@HARY@(C0I,C0J)_"</td>")
 . . . E  D ADDTO(HOUT,"<td style=""padding:5px;"">"_@HARY@(C0I,C0J)_"</td>")
 . . D ADDTO(HOUT,"</tr>")
 D ADDTO(HOUT,"</tbody>")
 D ADDTO(HOUT,"</table>")
 D ADDTO(HOUT,"</text>")
 D ADDTO(HOUT,"</div>")
 Q
 ;
GENHTML(HOUT,HARY) ; generate an HTML table from array HARY
 ; HOUT AND HARY are passed by name
 ;
 ;  HARY("TITLE")="Problem List"
 ;  HARY("HEADER",1)="column 1 header"
 ;  HARY("HEADER",2)="col 2 header"
 ;  HARY(1,1)="row 1 col1 value"
 ;  HARY(1,2)="row 1 col2 value"
 ;  HARY(1,2,"ID")="the ID of the element" 
 ;  etc...
 ;
 N DIVCLASS,TBLCLASS
 S DIVCLASS=$G(@HARY@("DIVCLASS"))
 S TBLCLASS=$G(@HARY@("TABLECLASS"))
 I DIVCLASS="" S DIVCLASS="tables"
 I TBLCLASS="" S TBLCLASS="patient"
 N C0I,C0J
 D ADDTO(HOUT,"<div class=""tables"">")
 ;I $D(@HARY@("TITLE")) D  ;
 ;. N X
 ;. S X="<title>"_@HARY@("TITLE")_"</title>"
 ;. D ADDTO(HOUT,X)
 ;D ADDTO(HOUT,"<text>")
 N ZWIDTH S ZWIDTH=$G(@HARY@("WIDTH"))
 I ZWIDTH="" S ZWIDTH="80%"
 D ADDTO(HOUT,"<table class=""summary"" style=""width:"_ZWIDTH_""">")
 I $D(@HARY@("TITLE")) D  ;
 . N X
 . S X="<caption>"_@HARY@("TITLE")_"</caption>"
 . D ADDTO(HOUT,X)
 I $D(@HARY@("HEADER")) D  ;
 . D ADDTO(HOUT,"<thead>")
 . D ADDTO(HOUT,"<tr>")
 . N NUMCOL S NUMCOL=$O(@HARY@("HEADER",""),-1)
 . S C0I=0
 . F  S C0I=$O(@HARY@("HEADER",C0I)) Q:+C0I=0  D  ;
 . . ;N TH S TH="<th colspan="""_NUMCOL_""">"_@HARY@("HEADER",C0I)_"</th>"
 . . N TH S TH="<th>"_@HARY@("HEADER",C0I)_"</th>"
 . . D ADDTO(HOUT,TH)
 . D ADDTO(HOUT,"</tr>")
 . D ADDTO(HOUT,"</thead>")
 D ADDTO(HOUT,"<tbody>")
 I $D(@HARY@(1)) D  ;
 . S C0I=0 S C0J=0
 . F  S C0I=$O(@HARY@(C0I)) Q:+C0I=0  D  ;
 . . D ADDTO(HOUT,"<tr>")
 . . F  S C0J=$O(@HARY@(C0I,C0J)) Q:+C0J=0  D  ;
 . . . N UID S UID=$G(@HARY@(C0I,C0J,"ID"))
 . . . I UID'="" D ADDTO(HOUT,"<td ID="""_UID_""">"_@HARY@(C0I,C0J)_"</td>")
 . . . E  D ADDTO(HOUT,"<td>"_@HARY@(C0I,C0J)_"</td>")
 . . D ADDTO(HOUT,"</tr>")
 D ADDTO(HOUT,"</tbody>")
 D ADDTO(HOUT,"</table>")
 ;D ADDTO(HOUT,"</text>")
 D ADDTO(HOUT,"</div>")
 Q
 ;
GENVHTML(HOUT,HARY) ; generate a vertical HTML table from array HARY
 ; headers are in the first row
 ; HOUT AND HARY are passed by name
 ;
 ; format of the table:
 ;  HARY("TITLE")="Problem List"
 ;  HARY("HEADER",1)="row 1 column 1 header"
 ;  HARY("HEADER",2)="row 2 col 2 header"
 ;  HARY(1,1)="row 1 col2 value"
 ;  HARY(2,1)="row 2 col2 value"
 ;  etc...
 ;
 N DIVCLASS,TBLCLASS
 S DIVCLASS=$G(@HARY@("DIVCLASS"))
 S TBLCLASS=$G(@HARY@("TABLECLASS"))
 I DIVCLASS="" S DIVCLASS="tables"
 I TBLCLASS="" S TBLCLASS="patient"
 N C0I,C0J
 D ADDTO(HOUT,"<div class=""tables"">")
 ;D ADDTO(HOUT,"<div align=""center"">")
 N ZWIDTH S ZWIDTH=$G(@HARY@("WIDTH"))
 I ZWIDTH="" S ZWIDTH="80%"
 D ADDTO(HOUT,"<table class=""summary"" style=""width:"_ZWIDTH_""">")
 ;D ADDTO(HOUT,"<text>")
 ;D ADDTO(HOUT,"<table border=""1"" style=""width:40%"">")
 I $D(@HARY@("TITLE")) D  ;
 . N X
 . S X="<caption><b>"_@HARY@("TITLE")_"</b></caption>"
 . D ADDTO(HOUT,X)
 I $D(@HARY@("HEADER")) D  ;
 . D ADDTO(HOUT,"<thead>")
 . D ADDTO(HOUT,"<tr>")
 . N NUMCOL S NUMCOL=$O(@HARY@("HEADER",""),-1)
 . S C0I=0
 . F  S C0I=$O(@HARY@("HEADER",C0I)) Q:+C0I=0  D  ;
 . . D ADDTO(HOUT,"<th style=""padding:5px;"">"_@HARY@("HEADER",C0I)_"</th>")
 . . D ADDTO(HOUT,"<td style=""padding:5px;"">"_@HARY@(C0I,1)_"</td>")
 . D ADDTO(HOUT,"</tr>")
 D ADDTO(HOUT,"</table>")
 D ADDTO(HOUT,"</text>")
 D ADDTO(HOUT,"</div>")
 Q
 ;
TSTYLE1 ; table style template
 ;;<style>
 ;;table, th, td
 ;;{
 ;;border-collapse:collapse;
 ;;border:1px solid black;
 ;;}
 ;;th, td
 ;;{
 ;;padding:5px;
 ;;}
 ;;</style>
 Q
 ;
TESTHTML ;
 N HTML
 S HTML("TITLE")="Problem List"
 S HTML("HEADER",1)="column 1 header"
 S HTML("HEADER",2)="col 2 header"
 S HTML(1,1)="row 1 col1 value"
 S HTML(1,2)="row 1 col2 value"
 N GHTML
 D GENHTML("GHTML","HTML")
 ZWR GHTML
 Q
 ;
ADDTO(DEST,WHAT) ; adds string WHAT to list DEST 
 ; DEST is passed by name
 N GN
 S GN=$O(@DEST@("AAAAAA"),-1)+1
 S @DEST@(GN)=WHAT
 S @DEST@(0)=GN ; count
 Q
 ;
ADDARY(DEST,WHAT) ; adds array WHAT to list DEST 
 ; DEST and WHAT are passed by name
 N GN
 S GN=$O(@DEST@("AAAAAA"),-1)+1
 N ZZI S ZZI=0
 F  S ZZI=$O(@WHAT@(ZZI)) Q:'ZZI  D  ;
 . S @DEST@(GN)=$G(@WHAT@(ZZI))
 . S @DEST@(0)=GN ; count
 . S GN=GN+1
 Q
 ;
ORGOID() ; extrinsic which returns the Organization OID
 Q "2.16.840.1.113883.5.83" ; WORLDVISTA HL7 OID - 
 ; REPLACE WITH OID LOOKUP FROM INSTITUTION FILE
 ;
tree(where,prefix,docid,zout) ; show a tree starting at a node in MXML. 
 ; node is passed by name
 ; 
 i $g(prefix)="" s prefix="|--" ; starting prefix
 i '$d(KBAIJOB) s KBAIJOB=$J
 n node s node=$na(^TMP("MXMLDOM",KBAIJOB,docid,where))
 n txt s txt=$$CLEAN($$ALLTXT(node))
 w:'$G(DIQUIET) !,prefix_@node_" "_txt
 d oneout(zout,prefix_@node_" "_txt)
 n zi s zi=""
 f  s zi=$o(@node@("A",zi)) q:zi=""  d  ;
 . w:'$G(DIQUIET) !,prefix_"  : "_zi_"^"_$g(@node@("A",zi))
 . d oneout(zout,prefix_"  : "_zi_"^"_$g(@node@("A",zi)))
 f  s zi=$o(@node@("C",zi)) q:zi=""  d  ;
 . d tree(zi,"|  "_prefix,docid,zout)
 q
 ;
oneout(zbuf,ztxt) ; adds a line to zbuf
 n zi s zi=$o(@zbuf@(""),-1)+1
 s @zbuf@(zi)=ztxt
 q
 ;
ALLTXT(where) ; extrinsic which returns all text lines from the node .. concatinated 
 ; together
 n zti s zti=""
 n ztr s ztr=""
 f  s zti=$o(@where@("T",zti)) q:zti=""  d  ;
 . s ztr=ztr_$g(@where@("T",zti))
 q ztr
 ;
CLEAN(STR) ; extrinsic function; returns string - gpl borrowed from the CCR package
 ;; Removes all non printable characters from a string.
 ;; STR by Value
 N TR,I
 F I=0:1:31 S TR=$G(TR)_$C(I)
 S TR=TR_$C(127)
 N ZR S ZR=$TR(STR,TR)
 S ZR=$$LDBLNKS(ZR) ; get rid of leading blanks
 QUIT ZR
 ;
LDBLNKS(st) ; extrinsic which removes leading blanks from a string
 n pos f pos=1:1:$l(st)  q:$e(st,pos)'=" "
 q $e(st,pos,$l(st))
 ;
show(what,docid,zout) ;
 I '$D(C0XJOB) S C0XJOB=$J
 d tree(what,,docid,zout)
 q
 ; 
listm(out,in) ; out is passed by name in is passed by reference
 n i s i=$q(@in@(""))
 f  s i=$q(@i) q:i=""  d oneout(out,i_"="_@i)
 q
 ;
peel(out,in) ; compress a complex global into something simpler
 n i s i=$q(@in@(""))
 f  s i=$q(@i) q:i=""  d  ;
 . n j,k,l,m,n,m1
 . s (l,m)=""
 . s n=$$shrink($qs(i,$ql(i)))
 . s k=$qs(i,0)_"("""
 . f j=1:1:$ql(i)-1  d  ;
 . . i +$qs(i,j)>0 d  ;
 . . . i m'="" q
 . . . s m=$qs(i,j)
 . . . s m1=j
 . . . i j>1 s l=$qs(i,j-1)
 . . . e  s l=$qs(i,j)
 . . . i l["substanceAdministration" s l=$p(l,"substanceAdministration",2)
 . . s k=k_$qs(i,j)_""","""
 . . w:$g(DEBUG) !,j," ",k
 . s k=k_$qs(i,$ql(i))_""")"
 . w:$g(DEBUG) !,k,"=",@k
 . i l'="" d  q  ;
 . . d:$g(@out@(l,m,n))'=""
 . . . ;n jj,n2
 . . . ;f jj=2:1  w !,jj s n2=$qs(i,$ql(i)-1)_"["_jj_"]"_n q:$g(@out@(l,m,n2))=""  w !,n2
 . . . ;s n=n2
 . . . ;s n=$$shrink($qs(i,$ql(i)-1))_"_"_n
 . . . s n=$$mkxpath(i,m1)
 . . . b:$g(@out@(l,m,n))'=""
 . . s @out@(l,m,n)=@k
 . i @k'="" d  ;
 . . i $ql(i)>1 d  q  ;
 . . . s l=$$shrink($qs(i,$ql(i)-1))
 . . . d:$g(@out@(l,n))'=""
 . . . . ;n jj,n2
 . . . . ;f jj=2:1  s n2=$qs(i,$ql(i)-1)_"["_jj_"]"_"_"_n q:$g(@out@(l,n2))=""
 . . . . ;s n=n2
 . . . . ;b:$g(@out@(l,n))'=""
 . . . . s n=$$shrink($qs(i,$ql(i)-1))_"_"_n
 . . . s @out@(l,n)=@k
 . . s @out@(n)=@k
 q
 ;
shrink(x) ; reduce strings 
 n y,z
 s y=x
 s z="substanceAdministration"
 i x[z s y=$p(x,z,2)
 q y
 ;
mkxpath(zq,zm) ; extrinsic which returns the xpath derived from the $query value 
 ;passed by value. zm is the index to begin with
 ;
 n zr s zr=""
 n zi s zi=""
 f zi=1:1:$ql(zq) s zr=zr_"/"_$qs(zq,zi)
 q zr
 ;
ARY2XML(OUTXML,INARY,STK,CHILD) ; convert an array to xml
 I '$D(@OUTXML@(1)) S @OUTXML@(1)="<?xml version=""1.0"" encoding=""utf-8"" ?>"
 N II S II=""
 N DATTR S DATTR="" ; deffered attributes
 F  S II=$O(@INARY@(II),-1) Q:II=""  D  ;
 . N ATTR,TAG
 . S ATTR="" S TAG=""
 . I II["@" D  ;
 . . I TAG="" S TAG=$P(II,"@",1) S ATTR=$P(II,"@",2)_"="""_@INARY@(II)_""""
 . . W:$G(DEBUG) !,"TAG="_TAG_" ATTR="_ATTR
 . . ;I $O(@INARY@(II))["@" D  ;
 . . ;F  S II=$O(@INARY@(II),-1) Q:II=""  Q:$O(@INARY@(II),-1)'[(TAG_"@")  D  ;
 . . F  S II=$O(@INARY@(II),-1) Q:II=""  Q:II'[(TAG_"@")  D  ;
 . . . S ATTR=ATTR_" "_$P(II,"@",2)_"="""_@INARY@(II)_""""
 . . . W:$G(DEBUG) !,"ATTR= ",ATTR
 . . . W:$G(DEBUG) !,"II= ",II
 . . S II=$O(@INARY@(II)) ; reset to previous
 . . N ENDING S ENDING="/"
 . . I II["@" D  ;
 . . . I $O(@INARY@(II),-1)=TAG S DATTR=" "_ATTR Q  ; deffered attributes
 . . . I $D(@INARY@(TAG)) S ENDING=""
 . . . D ONEOUT(OUTXML,"<"_TAG_" "_ATTR_ENDING_">")
 . . . I ENDING="" D PUSH("STK","</"_TAG_">")
 . I II'["@" D  ;
 . . I +II=0 D  ;
 . . . D ONEOUT(OUTXML,"<"_II_DATTR_">")
 . . . S DATTR="" ; reinitialize after use
 . . . D PUSH("STK","</"_II_">")
 . I $D(@INARY@(II)) D ARY2XML(OUTXML,$NA(@INARY@(II)))
 I $D(STK) F  D ONEOUT(OUTXML,$$POP("STK")) Q:'$D(STK)
 Q
 ;
ONEOUT(ZBUF,ZTXT) ; ADDS A LINE TO ZBUF
 N ZI S ZI=$O(@ZBUF@(""),-1)+1
 S @ZBUF@(ZI)=ZTXT
 Q
 ;
PUSH(BUF,STR) ;
 D ONEOUT(BUF,STR)
 Q
 ;
POP(BUF) ; extrinsic returns the last element and then deletes it
 N NM,TX
 S NM=$O(@BUF@(""),-1)
 Q:NM="" NM
 S TX=@BUF@(NM)
 K @BUF@(NM)
 Q TX
 ;
RMCNT0(RTN) ; remove ADDTO line count @RTN@(0) so HTTP writer does not emit it as data
 I $D(@RTN@(0)) K @RTN@(0)
 Q
 ;
ESCBS() Q $C(92)_$C(92) ; JSON \\
ESCQ() Q $C(92)_$C(34) ; JSON \"
 ;
JESC(S) ; JSON string escape; pass by value
 N R,I,C
 S S=$G(S),R=""
 F I=1:1:$L(S) S C=$E(S,I) D
 . I C=$C(92) S R=R_$$ESCBS^C0TSWSU Q
 . I C=$C(34) S R=R_$$ESCQ^C0TSWSU Q
 . I C=$C(10) S R=R_$C(92)_"n" Q
 . I C=$C(13) S R=R_$C(92)_"r" Q
 . I C=$C(9) S R=R_$C(92)_"t" Q
 . S R=R_C
 Q R
 ;
JSTR(S) Q $C(34)_$$JESC^C0TSWSU($G(S))_$C(34)
 ;
XESC(S) ; minimal XML text body escape
 N R
 S R=$G(S)
 S R=$$REP^C0TSWSU(R,"&","&amp;")
 S R=$$REP^C0TSWSU(R,"<","&lt;")
 S R=$$REP^C0TSWSU(R,">","&gt;")
 Q R
 ;
REP(S,A,B) ; replace all A in S with B
 N R,P
 S S=$G(S),R="",P=1
 F  S P=$F(S,A,P) Q:'P  S R=R_$E(S,1,P-$L(A)-1)_B,S=$E(S,P,999999),P=1
 S R=R_S
 Q R
 ;
CSVF(S) ; CSV field (quoting)
 N Q S Q=$C(34)
 S S=$$REP^C0TSWSU($G(S),Q,Q_Q) Q Q_S_Q
 ;
SET1L(RTN,LINE) ; one output line, no @RTN@(0) line-count
 N ZI
 S ZI=$O(@RTN@("AAAAA"),-1)+1
 S @RTN@(ZI)=$G(LINE)
 Q
 ;
WSCDSETJ(RTN,SETS) ; JSON — codeset list; SETS passed by .SETS
 N II,S,COM,FRAG
 S S="{""resourceType"":""BstsCodesetList"",""codesets"":[",COM=""
 F II=0:0 S II=$O(SETS(II)) Q:+II=0  D
 . S FRAG=$$G1SETJ^C0TSWSU(.SETS,II)
 . S S=S_COM_FRAG,COM=","
 S S=S_"]}"
 D SET1L^C0TSWSU(RTN,S)
 Q
 ;
G1SETJ(SETS,II) ; one codeset as JSON object
 N ID,QTY,ZV,JJ,SB,SC,FRG
 S ID=SETS(II,"id")
 S QTY=$$QTYSET^C0TSWSD(ID)
 S ZV="" I $D(SETS(II,"versions",1)) S ZV=SETS(II,"versions",$O(SETS(II,"versions",""),-1))
 S ZV=$P(ZV,"^",1)
 S SB="[",SC="" I $D(SETS(II,"subset")) D
 . F JJ=0:0 S JJ=$O(SETS(II,"subset",JJ)) Q:+JJ=0  D
 . . S FRG=SETS(II,"subset",JJ,"name")
 . . S SB=SB_SC_"{""name"":"_$$JSTR^C0TSWSU(FRG)_",""url"":"_$$JSTR^C0TSWSU(SETS(II,"subset",JJ,"url"))_"}",SC=","
 S SB=SB_"]"
 Q "{"_"""id"":"_$$JSTR^C0TSWSU(ID)_",""name"":"_$$JSTR^C0TSWSU(SETS(II,"name"))_",""text"":"_$$JSTR^C0TSWSU(SETS(II,"text"))_",""codelist"":"_$$JSTR^C0TSWSU(SETS(II,"url"))_",""version"":"_$$JSTR^C0TSWSU(ZV)_",""status"":"_$$JSTR^C0TSWSU("IHS Original")_",""quantity"":"_QTY_",""subsets"":"_SB_"}"
 ;
WSCDSETX(RTN,SETS) ; simple XML
 D SET1L^C0TSWSU(RTN,"<?xml version=""1.0"" encoding=""utf-8""?>")
 D SET1L^C0TSWSU(RTN,"<codesets>")
 N II,ID,QTY,ZV,JJ
 F II=0:0 S II=$O(SETS(II)) Q:+II=0  D
 . S ID=SETS(II,"id"),QTY=$$QTYSET^C0TSWSD(ID)
 . S ZV="" I $D(SETS(II,"versions",1)) S ZV=SETS(II,"versions",$O(SETS(II,"versions",""),-1))
 . S ZV=$P(ZV,"^",1)
 . D SET1L^C0TSWSU(RTN,"<codeset id="_$$JSTR^C0TSWSU(ID)_">")
 . D SET1L^C0TSWSU(RTN,"<name>"_$$XESC^C0TSWSU(SETS(II,"name"))_"</name>")
 . D SET1L^C0TSWSU(RTN,"<text>"_$$XESC^C0TSWSU(SETS(II,"text"))_"</text>")
 . D SET1L^C0TSWSU(RTN,"<codelist>"_$$XESC^C0TSWSU(SETS(II,"url"))_"</codelist>")
 . D SET1L^C0TSWSU(RTN,"<version>"_$$XESC^C0TSWSU(ZV)_"</version>")
 . D SET1L^C0TSWSU(RTN,"<quantity>"_QTY_"</quantity>")
 . I $D(SETS(II,"subset")) D
 . . D SET1L^C0TSWSU(RTN,"<subsets>")
 . . F JJ=0:0 S JJ=$O(SETS(II,"subset",JJ)) Q:+JJ=0  D
 . . . D SET1L^C0TSWSU(RTN,"<subset name="_$$JSTR^C0TSWSU(SETS(II,"subset",JJ,"name"))_" url="_$$JSTR^C0TSWSU(SETS(II,"subset",JJ,"url"))_" />")
 . . D SET1L^C0TSWSU(RTN,"</subsets>")
 . D SET1L^C0TSWSU(RTN,"</codeset>")
 D SET1L^C0TSWSU(RTN,"</codesets>")
 Q
 ;
WSCDSETC(RTN,SETS) ; CSV: one line per main row, subset lines follow with leading comma groups
 D SET1L^C0TSWSU(RTN,"id,name,text,subset,version,status,quantity")
 N II,JJ,ZV,ID,QTY
 F II=0:0 S II=$O(SETS(II)) Q:+II=0  D
 . S ID=SETS(II,"id")
 . S QTY=$$QTYSET^C0TSWSD(ID)
 . S ZV="" I $D(SETS(II,"versions",1)) S ZV=SETS(II,"versions",$O(SETS(II,"versions",""),-1))
 . S ZV=$P(ZV,"^",1)
 . D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU(ID)_","_$$CSVF^C0TSWSU(SETS(II,"name"))_","_$$CSVF^C0TSWSU(SETS(II,"text"))_","_$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU(ZV)_","_$$CSVF^C0TSWSU("IHS Original")_","_QTY)
 . I $D(SETS(II,"subset")) D
 . . F JJ=0:0 S JJ=$O(SETS(II,"subset",JJ)) Q:+JJ=0  D
 . . . D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU(SETS(II,"subset",JJ,"name"))_","_$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU("IHS Original")_","_$$CSVF^C0TSWSU(""))
 Q
 ;
WSCODEJ(RTN,ROOT) ; codelist or subset list JSON; ROOT("ref")=global (multi-line, GT.M string cap safe)
 N II,COM,MAX,CNT,R,ROW,HEAD
 S R=$G(ROOT("ref")) I R="" Q
 S MAX=+$G(ROOT("max")) I MAX'>0 S MAX=4000
 S CNT=0
 S HEAD="{""resourceType"":""BstsCodeList"",""id"":"_$$JSTR^C0TSWSU($G(ROOT("id")))_",""name"":"_$$JSTR^C0TSWSU($G(ROOT("name")))_",""rows"":["
 D SET1L^C0TSWSU(RTN,HEAD)
 S COM="" F II=0:0 S II=$O(@R@(II)) Q:+II=0  D
 . I (CNT+1)>MAX Q
 . S ROW=COM_"{""code"":"_$$JSTR^C0TSWSU($G(@R@(II,"code")))_",""term"":"_$$JSTR^C0TSWSU($G(@R@(II,"term")))_",""conceptId"":"_$$JSTR^C0TSWSU($G(@R@(II,"conceptid")))_",""concept"":"_$$JSTR^C0TSWSU($G(@R@(II,"concept")))_"}",COM=",",CNT=CNT+1
 . D SET1L^C0TSWSU(RTN,ROW)
 D SET1L^C0TSWSU(RTN,"]}")
 Q
 ;
WSTEMJ(RTN,CODE,TERMARY) ; code detail to JSON
 N S,II,JJ,COM
 S S="{""resourceType"":""BstsCodeDetail"",""code"":"_$$JSTR^C0TSWSU($G(CODE))_",""rows"":[",COM=""
 S II="" F  S II=$O(TERMARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(TERMARY(II,JJ)) Q:JJ=""  D
 . . S S=S_COM_"{""file"":"_$$JSTR^C0TSWSU(II)_",""field"":"_$$JSTR^C0TSWSU(JJ)_",""value"":"_$$JSTR^C0TSWSU($G(TERMARY(II,JJ)))_"}",COM=","
 S S=S_"]}"
 D SET1L^C0TSWSU(RTN,S)
 Q
 ;
WSCONJ(RTN,CONID,CONARY) ; concept to JSON
 N S,II,JJ,KK,COM
 S S="{""resourceType"":""BstsConceptDetail"",""conceptId"":"_$$JSTR^C0TSWSU($G(CONID))_",""rows"":[",COM=""
 S II="" F  S II=$O(CONARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(CONARY(II,JJ)) Q:JJ=""  D
 . . I +JJ=0 S S=S_COM_"{""file"":"_$$JSTR^C0TSWSU(II)_",""index"":null,""field"":"_$$JSTR^C0TSWSU(JJ)_",""value"":"_$$JSTR^C0TSWSU($G(CONARY(II,JJ)))_"}",COM="," Q
 . . S KK="" F  S KK=$O(CONARY(II,JJ,KK)) Q:KK=""  D
 . . . S S=S_COM_"{""file"":"_$$JSTR^C0TSWSU(II)_",""index"":"_$$JSTR^C0TSWSU(JJ)_",""field"":"_$$JSTR^C0TSWSU(KK)_",""value"":"_$$JSTR^C0TSWSU($G(CONARY(II,JJ,KK)))_"}",COM=","
 S S=S_"]}"
 D SET1L^C0TSWSU(RTN,S)
 Q
 ;
WSCODEX(RTN,CODE,TERMARY) ; code detail to XML
 D SET1L^C0TSWSU(RTN,"<?xml version=""1.0"" encoding=""utf-8""?>")
 D SET1L^C0TSWSU(RTN,"<BstsCodeDetail code="_$$JSTR^C0TSWSU($G(CODE))_">")
 N II,JJ
 S II="" F  S II=$O(TERMARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(TERMARY(II,JJ)) Q:JJ=""  D
 . . D SET1L^C0TSWSU(RTN,"<row file="_$$JSTR^C0TSWSU(II)_" field="_$$JSTR^C0TSWSU(JJ)_">"_$$XESC^C0TSWSU($G(TERMARY(II,JJ)))_"</row>")
 D SET1L^C0TSWSU(RTN,"</BstsCodeDetail>")
 Q
 ;
WSCONX(RTN,CONID,CONARY) ; concept to XML
 D SET1L^C0TSWSU(RTN,"<?xml version=""1.0"" encoding=""utf-8""?>")
 D SET1L^C0TSWSU(RTN,"<BstsConceptDetail conceptId="_$$JSTR^C0TSWSU($G(CONID))_">")
 N II,JJ,KK
 S II="" F  S II=$O(CONARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(CONARY(II,JJ)) Q:JJ=""  D
 . . I +JJ=0 D SET1L^C0TSWSU(RTN,"<row file="_$$JSTR^C0TSWSU(II)_" field="_$$JSTR^C0TSWSU(JJ)_">"_$$XESC^C0TSWSU($G(CONARY(II,JJ)))_"</row>") Q
 . . S KK="" F  S KK=$O(CONARY(II,JJ,KK)) Q:KK=""  D
 . . . D SET1L^C0TSWSU(RTN,"<row file="_$$JSTR^C0TSWSU(II)_" index="_$$JSTR^C0TSWSU(JJ)_" field="_$$JSTR^C0TSWSU(KK)_">"_$$XESC^C0TSWSU($G(CONARY(II,JJ,KK)))_"</row>")
 D SET1L^C0TSWSU(RTN,"</BstsConceptDetail>")
 Q
 ;
WSCODLXML(RTN,ROOT) ; codelist/subset to simple XML; ROOT("ref")=global name
 N II,MAX,CNT,R
 S R=$G(ROOT("ref")) I R="" Q
 S MAX=+$G(ROOT("max")) I MAX'>0 S MAX=4000
 S CNT=0
 D SET1L^C0TSWSU(RTN,"<?xml version=""1.0"" encoding=""utf-8""?>")
 D SET1L^C0TSWSU(RTN,"<BstsCodeList id="_$$JSTR^C0TSWSU($G(ROOT("id")))_" name="_$$JSTR^C0TSWSU($G(ROOT("name")))_">")
 F II=0:0 S II=$O(@R@(II)) Q:+II=0  D
 . I (CNT+1)>MAX Q
 . D SET1L^C0TSWSU(RTN,"<row><code>"_$$XESC^C0TSWSU($G(@R@(II,"code")))_"</code><term>"_$$XESC^C0TSWSU($G(@R@(II,"term")))_"</term><conceptId>"_$$XESC^C0TSWSU($G(@R@(II,"conceptid")))_"</conceptId><concept>"_$$XESC^C0TSWSU($G(@R@(II,"concept")))_"</concept></row>")
 . S CNT=CNT+1
 D SET1L^C0TSWSU(RTN,"</BstsCodeList>")
 Q
 ;
WSCODLC(RTN,ROOT) ; codelist/subset to CSV; ROOT("ref")=global name string
 D SET1L^C0TSWSU(RTN,"code,term,conceptId,concept")
 N II,MAX,CNT,R
 S R=$G(ROOT("ref")) I R="" Q
 S MAX=+$G(ROOT("max")) I MAX'>0 S MAX=4000
 S CNT=0
 F II=0:0 S II=$O(@R@(II)) Q:+II=0  D
 . I (CNT+1)>MAX Q
 . D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU($G(@R@(II,"code")))_","_$$CSVF^C0TSWSU($G(@R@(II,"term")))_","_$$CSVF^C0TSWSU($G(@R@(II,"conceptid")))_","_$$CSVF^C0TSWSU($G(@R@(II,"concept"))))
 . S CNT=CNT+1
 Q
 ;
WSCODCC(RTN,CODE,TERMARY) ; code detail to CSV
 D SET1L^C0TSWSU(RTN,"file,field,value")
 N II,JJ
 S II="" F  S II=$O(TERMARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(TERMARY(II,JJ)) Q:JJ=""  D
 . . D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU(II)_","_$$CSVF^C0TSWSU(JJ)_","_$$CSVF^C0TSWSU($G(TERMARY(II,JJ))))
 Q
 ;
WSCONCC(RTN,CONID,CONARY) ; concept to CSV
 D SET1L^C0TSWSU(RTN,"fileOrSubfile,index,field,value")
 N II,JJ,KK
 S II="" F  S II=$O(CONARY(II)) Q:II=""  D
 . S JJ="" F  S JJ=$O(CONARY(II,JJ)) Q:JJ=""  D
 . . I +JJ=0 D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU(II)_","_$$CSVF^C0TSWSU("")_","_$$CSVF^C0TSWSU(JJ)_","_$$CSVF^C0TSWSU($G(CONARY(II,JJ)))) Q
 . . S KK="" F  S KK=$O(CONARY(II,JJ,KK)) Q:KK=""  D
 . . . D SET1L^C0TSWSU(RTN,$$CSVF^C0TSWSU(II)_","_$$CSVF^C0TSWSU(JJ)_","_$$CSVF^C0TSWSU(KK)_","_$$CSVF^C0TSWSU($G(CONARY(II,JJ,KK))))
 Q
 ;
UNKFMT(FMT) ; 1 = unsupported alternate format
 I FMT'="html",FMT'="json",FMT'="xml",FMT'="csv",FMT'="mumps" Q 1
 Q 0
 ;
