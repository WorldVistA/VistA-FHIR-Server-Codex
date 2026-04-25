C0TSWS ;GPL-VistA Terminology Server Web Services ; 21 Mar 2016  10:23 PM
 ;;1.0;C0TS VISTA TERMINOLOGY SERVER;;Mar 21, 2016;Build 1
 ;
 ; License Apache 2.0
 ;
 Q
 ;
wsCDSETS(RTN,FILTER) ; returns Codesets from BSTS
 ; returns all codesets and thier subsets (no parameters)
 ; or a single codeset and its subsets ( id= or name= )
 ; format of the return is controlled by format= valid values are:
 ;    format=html (default) a browser page with hyperlinks for the entries
 ;    format=json 
 ;    format=xml
 ;    format=mumps ; a mumps array format
 ;    format=yaml
 ;    format=csv ; suitable for loading into a spreadsheet
 ; 
 I $G(RTN)="" S RTN=$NA(^TMP("C0TSWS",$J))
 K @RTN
 N ID,NAME,FORMAT,ALL,SELECT
 S ID=$G(FILTER("id"))
 S NAME=$G(FILTER("name"))
 S ALL=0
 S SELECT=NAME
 S SELECT=ID ; id takes precidence
 I SELECT="" S ALL=1
 S FORMAT=$G(FILTER("format"))
 I FORMAT="" S FORMAT="html"
 I $$UNKFMT^C0TSWSU(FORMAT) S FORMAT="json"
 ;
 N SETS
 I '$$GETSETS^C0TSWSD("SETS") D  Q
 . S @RTN@(1)="ERROR RETRIEVING CODESETS"
 ;
 I FORMAT="html" D  Q
 . S HTTPRSP("mime")="text/html"
 . N GTOP,GBOT
 . D HTMLTB(.GTOP,.GBOT,"BSTS Codesets")
 . M @RTN=GTOP
 . D THISPG(RTN,"bsts/codeset")
 . N GARY
 . S GARY("WIDTH")="60%"
 . S GARY("TITLE")="BSTS Codesets"
 . S GARY("HEADER",1)="ID"
 . S GARY("HEADER",2)="Code"
 . S GARY("HEADER",3)="Name"
 . S GARY("HEADER",4)="Subset"
 . S GARY("HEADER",5)="Version"
 . S GARY("HEADER",6)="Status"
 . S GARY("HEADER",7)="Quantity"
 . N ZI S ZI=0
 . N II S II=0
 . F  S II=$O(SETS(II)) Q:+II=0  D  ;
 . . S ZI=ZI+1
 . . N ID,URL
 . . S ID=SETS(II,"id")
 . . S URL=SETS(II,"url")
 . . N QTY
 . . S QTY=$$QTYSET^C0TSWSD(ID) ; number of codes in the codeset
 . . I QTY=0 S GARY(ZI,1)=ID
 . . E  S GARY(ZI,1)="<a href="_URL_"&format=html target=_blank>"_ID_"</a>"
 . . S GARY(ZI,2)=SETS(II,"name")
 . . S GARY(ZI,3)=SETS(II,"text")
 . . S GARY(ZI,4)=""
 . . N ZV S ZV=""
 . . I $D(SETS(II,"versions",1)) S ZV=SETS(II,"versions",$O(SETS(II,"versions",""),-1))
 . . S ZV=$P(ZV,"^",1)
 . . S GARY(ZI,5)=$G(ZV)
 . . S GARY(ZI,6)="IHS Original"
 . . S GARY(ZI,7)=QTY
 . . ;N SUBSET,SOK
 . . ;S SOK=$$SUBSET^BSTSAPIA("SUBSET",ID_"^1^1")
 . . I $D(SETS(II,"subset")) D  ; subsets exist
 . . . N JJ S JJ=0
 . . . F  S JJ=$O(SETS(II,"subset",JJ)) Q:+JJ=0  D  ; for each subset
 . . . . S ZI=ZI+1 ; next row
 . . . . N SN,SURL
 . . . . S SN=SETS(II,"subset",JJ,"name")
 . . . . S SURL=SETS(II,"subset",JJ,"url")
 . . . . S GARY(ZI,1)=""
 . . . . S GARY(ZI,2)=""
 . . . . S GARY(ZI,3)=""
 . . . . S GARY(ZI,4)="<a href="_SURL_" target=_blank >"_SN_"</a>"
 . . . . S GARY(ZI,5)=""
 . . . . S GARY(ZI,6)="IHS Original"
 . . . . S GARY(ZI,7)=""
 . D GENHTML^C0TSWSU(RTN,"GARY")
 . S @RTN@($O(@RTN@(""),-1)+1)=GBOT
 . D RMCNT0^C0TSWSU(RTN)
 I FORMAT="json" S HTTPRSP("mime")="application/json" D WSCDSETJ^C0TSWSU(RTN,.SETS) Q
 I FORMAT="xml" S HTTPRSP("mime")="text/xml; charset=utf-8" D WSCDSETX^C0TSWSU(RTN,.SETS) Q
 I FORMAT="csv" S HTTPRSP("mime")="text/csv; charset=utf-8" D WSCDSETC^C0TSWSU(RTN,.SETS) Q
 I FORMAT="mumps" S HTTPRSP("mime")="text/plain" M @RTN=SETS Q
 S @RTN@(1)="{""error"":""Unsupported format""}" S HTTPRSP("mime")="application/json" Q
 ;
wsCDLIST(RTN,FILTER) ; returns Codes from BSTS
 ; returns all codes from a codeset identified by id
 ; format of the return is controlled by format= valid values are:
 ;    format=html (default) a browser page with hyperlinks for the entries
 ;    format=json 
 ;    format=xml
 ;    format=mumps ; a mumps array format
 ;    format=yaml
 ;    format=csv ; suitable for loading into a spreadsheet
 ; 
 I $G(RTN)="" S RTN=$NA(^TMP("C0TSWS",$J))
 K @RTN
 N SETID,NAME,FORMAT,TEXT,IEN,MAX
 S SETID=$G(FILTER("id"))
 S MAX=$G(FILTER("max"))
 I MAX="" S MAX=4000
 S FORMAT=$G(FILTER("format"))
 I FORMAT="" S FORMAT="html"
 I $$UNKFMT^C0TSWSU(FORMAT) S FORMAT="json"
 ;
 N SETS
 I '$$GETSETS^C0TSWSD("SETS") D  Q
 . S @RTN@(1)="ERROR RETRIEVING CODESETS"
 S IEN=$O(SETS("ID",SETID,""))
 S NAME=SETS(IEN,"name")
 S TEXT=SETS(IEN,"text")
 ;
 N LST,CLROOT
 D LISTBUF^C0TSWSD(.LST,SETID) ; get the address of the list array for this codeset
 ;
 I FORMAT="html" D  Q
 . S HTTPRSP("mime")="text/html"
 . N GTOP,GBOT
 . D HTMLTB(.GTOP,.GBOT,"BSTS Codes in "_NAME)
 . M @RTN=GTOP
 . D THISPG(RTN,"bsts/codes?id="_SETID)
 . N GARY
 . S GARY("WIDTH")="60%"
 . S GARY("TITLE")="BSTS Codes in "_SETID_" "_NAME_" "_TEXT
 . S GARY("HEADER",1)="CODE"
 . S GARY("HEADER",2)="TERM"
 . S GARY("HEADER",3)="CONCEPT ID"
 . S GARY("HEADER",4)="CONCEPT"
 . ;S GARY("HEADER",5)="CODE"
 . ;S GARY("HEADER",6)="MAPS TO"
 . ;N NCON S NCON=$NA(^BSTS(9002318.4,"C"))
 . ;N NTERM S NTERM=$NA(^BSTS(9002318.3,"C"))
 . N ZI S ZI=0
 . N II S II=0
 . F  S II=$O(@LST@(II)) Q:(+II=0)!(ZI>MAX)  D  ;
 . . S ZI=ZI+1
 . . ;S ID=SETS(II,"id")
 . . N TERMIEN S TERMIEN=@LST@(II,"termien")
 . . N CDE S CDE=@LST@(II,"code")
 . . S GARY(ZI,1)="<a href=code?ien="_TERMIEN_" target=_blank>"_CDE_"</>"
 . . S GARY(ZI,2)=@LST@(II,"term")
 . . N CONIEN S CONIEN=@LST@(II,"conceptien")
 . . N CNID S CNID=@LST@(II,"conceptid")
 . . S GARY(ZI,3)="<a href=concept?ien="_CONIEN_" target=_blank>"_CNID_"</>"
 . . S GARY(ZI,4)=@LST@(II,"concept")
 . D GENHTML^C0TSWSU(RTN,"GARY")
 . S @RTN@($O(@RTN@(""),-1)+1)=GBOT
 . D RMCNT0^C0TSWSU(RTN)
 S CLROOT("id")=SETID,CLROOT("name")=NAME,CLROOT("ref")=LST,CLROOT("max")=MAX
 I LST="" D  S @RTN@(1)="{""error"":""no terms for this codeset""}" S HTTPRSP("mime")="application/json" Q
 I FORMAT="json" S HTTPRSP("mime")="application/json" D WSCODEJ^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="xml" S HTTPRSP("mime")="text/xml; charset=utf-8" D WSCODLXML^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="csv" S HTTPRSP("mime")="text/csv; charset=utf-8" D WSCODLC^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="mumps" S HTTPRSP("mime")="text/plain" I LST'="" M @RTN=@(LST) Q
 S @RTN@(1)="{""error"":""Unsupported format""}" S HTTPRSP("mime")="application/json" Q
 ;
wsCODE(RTN,FILTER) ; returns Code detail from BSTS TERMINOLOGY file
 ; format of the return is controlled by format= valid values are:
 ;    format=html (default) a browser page with hyperlinks for the entries
 ;    format=json 
 ;    format=xml
 ;    format=mumps ; a mumps array format
 ;    format=yaml
 ;    format=csv ; suitable for loading into a spreadsheet
 ; 
 I $G(RTN)="" S RTN=$NA(^TMP("C0TSWS",$J))
 K @RTN
 N CODE,FILE,FIELD,VALUE,IEN,FORMAT,TERMARY
 S FORMAT=$G(FILTER("format"))
 I FORMAT="" S FORMAT="html"
 I $$UNKFMT^C0TSWSU(FORMAT) S FORMAT="json"
 S CODE=$G(FILTER("id"))
 S IEN=$G(FILTER("ien"))
 ;
 D TERMARY^C0TSFM("TERMARY",CODE,IEN)
 Q:'$D(TERMARY)
 ;ZWR TERMARY
 ;
 I FORMAT="html" D  Q
 . S HTTPRSP("mime")="text/html"
 . N GTOP,GBOT
 . D HTMLTB(.GTOP,.GBOT,"Detail for BSTS Term "_CODE)
 . M @RTN=GTOP
 . D THISPG(RTN,"code?id="_CODE)
 . N GARY
 . S GARY("WIDTH")="60%"
 . S GARY("TITLE")="Detail for BSTS Code "_CODE
 . S GARY("HEADER",1)="FILE"
 . S GARY("HEADER",2)="FIELD"
 . S GARY("HEADER",3)="VALUE"
 . N ZI S ZI=0
 . N II S II=""
 . F  S II=$O(TERMARY(II)) Q:II=""  D  ;
 . . N JJ S JJ=""
 . . F  S JJ=$O(TERMARY(II,JJ)) Q:JJ=""  D  ;
 . . . S ZI=ZI+1
 . . . S GARY(ZI,1)=II
 . . . S GARY(ZI,2)=JJ
 . . . S GARY(ZI,3)=$G(TERMARY(II,JJ))
 . D GENHTML^C0TSWSU(RTN,"GARY")
 . S @RTN@($O(@RTN@(""),-1)+1)=GBOT
 . D RMCNT0^C0TSWSU(RTN)
 I FORMAT="json" S HTTPRSP("mime")="application/json" D WSTEMJ^C0TSWSU(RTN,CODE,"TERMARY") Q
 I FORMAT="xml" S HTTPRSP("mime")="text/xml; charset=utf-8" D WSCODEX^C0TSWSU(RTN,CODE,"TERMARY") Q
 I FORMAT="csv" S HTTPRSP("mime")="text/csv; charset=utf-8" D WSCODCC^C0TSWSU(RTN,CODE,"TERMARY") Q
 I FORMAT="mumps" S HTTPRSP("mime")="text/plain" M @RTN=TERMARY Q
 S @RTN@(1)="{""error"":""Unsupported format""}" S HTTPRSP("mime")="application/json" Q
 ;
wsCON(RTN,FILTER) ; returns Concept detail from BSTS CONCEPT file
 ; format of the return is controlled by format= valid values are:
 ;    format=html (default) a browser page with hyperlinks for the entries
 ;    format=json 
 ;    format=xml
 ;    format=mumps ; a mumps array format
 ;    format=yaml
 ;    format=csv ; suitable for loading into a spreadsheet
 ; 
 I $G(RTN)="" S RTN=$NA(^TMP("C0TSWS",$J))
 K @RTN
 N CONID,FILE,FIELD,VALUE,IEN,FORMAT,CONARY
 S FORMAT=$G(FILTER("format"))
 I FORMAT="" S FORMAT="html"
 I $$UNKFMT^C0TSWSU(FORMAT) S FORMAT="json"
 S CONID=$G(FILTER("id"))
 I CONID="" S CONID=$G(FILTER("conceptid"))
 S IEN=$G(FILTER("ien"))
 ;
 D CONARY^C0TSFM("CONARY",CONID,IEN)
 Q:'$D(CONARY)
 ;ZWR CONARY
 ;
 I FORMAT="html" D  Q
 . S HTTPRSP("mime")="text/html"
 . N GTOP,GBOT
 . D HTMLTB(.GTOP,.GBOT,"Detail for BSTS Concept "_CONID)
 . M @RTN=GTOP
 . D THISPG(RTN,"concept?id="_CONID)
 . N GARY
 . S GARY("WIDTH")="60%"
 . S GARY("TITLE")="Detail for BSTS Concept "_CONID
 . S GARY("HEADER",1)="FILE/SUBFILE"
 . S GARY("HEADER",2)="INDEX"
 . S GARY("HEADER",3)="FIELD"
 . S GARY("HEADER",4)="VALUE"
 . N ZI S ZI=0
 . N II S II=""
 . F  S II=$O(CONARY(II)) Q:II=""  D  ;
 . . N JJ S JJ=""
 . . F  S JJ=$O(CONARY(II,JJ)) Q:JJ=""  D  ;
 . . . I +JJ=0 D  ;
 . . . . S ZI=ZI+1
 . . . . S GARY(ZI,1)=II
 . . . . S GARY(ZI,2)=""
 . . . . S GARY(ZI,3)=JJ
 . . . . S GARY(ZI,4)=$G(CONARY(II,JJ))
 . . . E  D
 . . . . N KK S KK=""
 . . . . F  S KK=$O(CONARY(II,JJ,KK)) Q:KK=""  D  ;
 . . . . . S ZI=ZI+1
 . . . . . S GARY(ZI,1)=II
 . . . . . S GARY(ZI,2)=JJ
 . . . . . N TFLD S TFLD=KK
 . . . . . S GARY(ZI,3)=TFLD
 . . . . . S GARY(ZI,4)=$G(CONARY(II,JJ,KK))
 . D GENHTML^C0TSWSU(RTN,"GARY")
 . S @RTN@($O(@RTN@(""),-1)+1)=GBOT
 . D RMCNT0^C0TSWSU(RTN)
 I FORMAT="json" S HTTPRSP("mime")="application/json" D WSCONJ^C0TSWSU(RTN,CONID,"CONARY") Q
 I FORMAT="xml" S HTTPRSP("mime")="text/xml; charset=utf-8" D WSCONX^C0TSWSU(RTN,CONID,"CONARY") Q
 I FORMAT="csv" S HTTPRSP("mime")="text/csv; charset=utf-8" D WSCONCC^C0TSWSU(RTN,CONID,"CONARY") Q
 I FORMAT="mumps" S HTTPRSP("mime")="text/plain" M @RTN=CONARY Q
 S @RTN@(1)="{""error"":""Unsupported format""}" S HTTPRSP("mime")="application/json" Q
 ;
wsSUBLST(RTN,FILTER) ; returns Codes from BSTS subsets
 ; returns all codes from a subset identified by subset=
 ; optionally include id= for the codeset which is related to the subset. default is 36
 ; format of the return is controlled by format= valid values are:
 ;    format=html (default) a browser page with hyperlinks for the entries
 ;    format=json 
 ;    format=xml
 ;    format=mumps ; a mumps array format
 ;    format=yaml
 ;    format=csv ; suitable for loading into a spreadsheet
 ; 
 I $G(RTN)="" S RTN=$NA(^TMP("C0TSWS",$J))
 K @RTN
 N SUBSET,SETID,NAME,FORMAT,TEXT,IEN,MAX
 S SUBSET=$G(FILTER("subset"))
 S SUBSET=$TR(SUBSET,"_"," ")
 Q:SUBSET=""
 S SETID=$G(FILTER("id"))
 I SETID="" S SETID=36
 S MAX=$G(FILTER("max"))
 I MAX="" S MAX=4000
 S FORMAT=$G(FILTER("format"))
 I FORMAT="" S FORMAT="html"
 I $$UNKFMT^C0TSWSU(FORMAT) S FORMAT="json"
 ;
 N SETS
 I '$$GETSETS^C0TSWSD("SETS") D  Q
 . S @RTN@(1)="ERROR RETRIEVING CODESETS"
 S IEN=$O(SETS("ID",SETID,""))
 S NAME=SETS(IEN,"name")
 S TEXT=SETS(IEN,"text")
 ;
 N SUB,CLROOT
 S SUB=$$SUBBUF^C0TSWSD(SUBSET,SETID) ; get the address of the list array for this codeset
 ;
 I FORMAT="html" D  Q
 . S HTTPRSP("mime")="text/html"
 . N GTOP,GBOT
 . D HTMLTB(.GTOP,.GBOT,"BSTS Codes in "_NAME)
 . M @RTN=GTOP
 . D THISPG(RTN,"bsts/codes?id="_SETID)
 . N GARY
 . S GARY("WIDTH")="60%"
 . S GARY("TITLE")="BSTS Codes in subset "_SUBSET_" of "_SETID_" "_NAME_" "_TEXT
 . S GARY("HEADER",1)="CODE"
 . S GARY("HEADER",2)="TERM"
 . S GARY("HEADER",3)="CONCEPT ID"
 . S GARY("HEADER",4)="CONCEPT"
 . ;S GARY("HEADER",5)="CODE"
 . ;S GARY("HEADER",6)="MAPS TO"
 . ;N NCON S NCON=$NA(^BSTS(9002318.4,"C"))
 . ;N NTERM S NTERM=$NA(^BSTS(9002318.3,"C"))
 . N ZI S ZI=0
 . N II S II=0
 . F  S II=$O(@SUB@(II)) Q:(+II=0)!(ZI>MAX)  D  ;
 . . S ZI=ZI+1
 . . ;S ID=SETS(II,"id")
 . . N CDE S CDE=@SUB@(II,"code")
 . . S GARY(ZI,1)="<a href=code?id="_CDE_" target=_blank>"_CDE_"</>"
 . . S GARY(ZI,2)=@SUB@(II,"term")
 . . N CNID S CNID=@SUB@(II,"conceptid")
 . . S GARY(ZI,3)="<a href=concept?id="_CNID_" target=_blank>"_CNID_"</>"
 . . S GARY(ZI,4)=@SUB@(II,"concept")
 . D GENHTML^C0TSWSU(RTN,"GARY")
 . S @RTN@($O(@RTN@(""),-1)+1)=GBOT
 . D RMCNT0^C0TSWSU(RTN)
 S CLROOT("id")=SETID,CLROOT("name")=SUBSET,CLROOT("ref")=SUB,CLROOT("max")=MAX
 I SUB="" D  S @RTN@(1)="{""error"":""no terms for this subset""}" S HTTPRSP("mime")="application/json" Q
 I FORMAT="json" S HTTPRSP("mime")="application/json" D WSCODEJ^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="xml" S HTTPRSP("mime")="text/xml; charset=utf-8" D WSCODLXML^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="csv" S HTTPRSP("mime")="text/csv; charset=utf-8" D WSCODLC^C0TSWSU(RTN,.CLROOT) Q
 I FORMAT="mumps" S HTTPRSP("mime")="text/plain" I SUB'="" M @RTN=@(SUB) Q
 S @RTN@(1)="{""error"":""Unsupported format""}" S HTTPRSP("mime")="application/json" Q
 ;
THISPG(RTN,GURL) ; generate the top of page links
 N GARY,GTMP1,GTMP2,GTMP3,GTMP4,GTMP5,GTMP6,GTMP7,GURL
 I $G(GURL)="" S GURL="/bsts/codeset"
 S GTMP1=" <a href="""_GURL_"?format=html"" > html</a>"
 S GTMP2=" <a href="""_GURL_"?format=xml"" target=""_blank""> xml</a>"
 S GTMP3=" <a href="""_GURL_"?format=json"" target=""_blank""> json</a>"
 S GTMP4=" <a href="""_GURL_"?format=csv"" target=""_blank""> csv</a>"
 D ADDTO^C0TSWSU(RTN,"<p>this page"_GTMP1_GTMP2_GTMP3_GTMP4_"</p>")
 Q
 ;
HTMLTB(GTOP,GBOT,TITLE) ; sets beginning and ending fixed html
 ;
 ;S GTOP="<!DOCTYPE HTML><html><head></head><body>"
 S GTOP(1)="<!DOCTYPE HTML>"
 S GTOP(2)="<html>"
 S GTOP(3)="<head>"
 S GTOP(4)="<meta charset=""utf-8"">"
 S GTOP(5)="<meta http-equiv=""Content-Type"" content=""text/html; charset=utf-8"" />"
 S GTOP(6)="<title>"_$G(TITLE)_"</title>"
 S GTOP(7)="<link rel=""stylesheet"" type=""text/css"" href=""/resources/css/c0tstyle.css"" />"
 S GTOP(8)="</head>"
 S GTOP(9)="<body>"
 ;
 S GBOT="</body></html>"
 Q
 ;
