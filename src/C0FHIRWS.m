C0FHIRWS ; VAMC/JS - FHIR web service entry point ; 11-MAR-2026
 ;;1.3;C0FHIR PROJECT;;Mar 11, 2026;Build 4
 ;
 Q
 ;
WEB(RTN,FILTER) ; Entry point for web service calls
 ; RTN:    Output array (passed by reference)
 ; FILTER: Input/Output array (passed by reference)
 ;
 N DFN,IEN,NAME,VIEW
 K RTN
 S FILTER("type")="application/json" ; default mime type
 ;
 S DFN=$G(FILTER("dfn"))
 S IEN=+$G(FILTER("ien"))
 S NAME=$G(FILTER("name"))
 S VIEW=$$UPCASE^C0FHIR($G(FILTER("view")))
 ;
 ; Mode 1: Search by Name (HTML)
 I DFN="",NAME'="" D  Q
 . S FILTER("type")="text/html"
 . D SEARCH(.RTN,NAME)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 2: Interactive browser (HTML) for one patient or stored source bundle
 I VIEW="BROWSER",(DFN'=""!(IEN>0)) D  Q
 . S FILTER("type")="text/html"
 . D BROWSER(.RTN,.FILTER)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 3: No identifiers supplied -> HTML patient index
 I DFN="",IEN<1 D  Q
 . S FILTER("type")="text/html"
 . D FHIRIDX^C0FHIR(.RTN)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 4: Core FHIR aggregator (JSON)
 D GETFHIR^C0FHIR(.RTN,.FILTER)
 Q
 ;
BROWSER(RTN,FILTER) ; Interactive FHIR browser for live /fhir or stored /showfhir bundles
 N ALTLBL,ALTRAW,BADGE,D,IEN,LOADURL,RAWLBL,RAWURL,SRC,SRCNOTE,THEME,TOPLINKS
 S D=+$G(FILTER("dfn"))
 S IEN=+$G(FILTER("ien"))
 S SRC=$$UPCASE^C0FHIR($G(FILTER("source")))
 I SRC="SYNTHEA" S SRC="SHOWFHIR"
 I SRC="" S SRC=$S(IEN>0:"SHOWFHIR",1:"FHIR")
 I SRC="SHOWFHIR" D
 . S THEME="theme-light"
 . S BADGE="Synthea source"
 . S SRCNOTE="Stored Synthea FHIR via /showfhir"
 . S LOADURL=$S(IEN>0:"/showfhir?ien="_IEN,D>0:"/showfhir?dfn="_D,1:"/showfhir")
 . S RAWLBL="raw synthea"
 . S RAWURL=LOADURL
 . S ALTRAW=$S(D>0:"/fhir?dfn="_D,1:"")
 . S ALTLBL=$S(ALTRAW'="":"generated fhir",1:"")
 E  D
 . S THEME="theme-dark"
 . S BADGE="VistA source"
 . S SRCNOTE="VistA-generated FHIR via /fhir"
 . S LOADURL="/fhir?dfn="_D
 . S RAWLBL="raw fhir"
 . S RAWURL=LOADURL
 . S ALTRAW=""
 . S ALTLBL=""
 K RTN
 D ADDLN(.RTN,"<!DOCTYPE html>")
 D ADDLN(.RTN,"<html>")
 D ADDLN(.RTN,"<head>")
 D ADDLN(.RTN,"<meta charset='utf-8'>")
 D ADDLN(.RTN,"<meta name='viewport' content='width=device-width, initial-scale=1'>")
 D ADDLN(.RTN,"<title>C0FHIR Browser</title>")
 D ADDLN(.RTN,"<style>")
 D ADDLN(.RTN,"body.theme-dark{color-scheme:dark;--bg:#0b1220;--fg:#e2e8f0;--top-bg:#111827;--top-border:#334155;--link:#93c5fd;--muted:#94a3b8;}")
 D ADDLN(.RTN,"body.theme-dark{--panel:#0f172a;--divider:#334155;--item-border:#1f2937;--item-hover:#111827;--item-active:#172554;}")
 D ADDLN(.RTN,"body.theme-dark{--accent:#1d4ed8;--accent-2:#60a5fa;--btn-border:#334155;--btn-bg:#0f172a;}")
 D ADDLN(.RTN,"body.theme-dark{--btn-active:#1d4ed8;--btn-active-border:#2563eb;--btn-active-fg:#ffffff;--badge-bg:#1e3a8a;--badge-fg:#dbeafe;}")
 D ADDLN(.RTN,"body.theme-light{color-scheme:light;--bg:#f8fafc;--fg:#0f172a;--top-bg:#e2e8f0;--top-border:#cbd5e1;--link:#1d4ed8;--muted:#475569;}")
 D ADDLN(.RTN,"body.theme-light{--panel:#ffffff;--divider:#cbd5e1;--item-border:#e2e8f0;--item-hover:#eff6ff;--item-active:#dbeafe;}")
 D ADDLN(.RTN,"body.theme-light{--accent:#0284c7;--accent-2:#0369a1;--btn-border:#94a3b8;--btn-bg:#ffffff;}")
 D ADDLN(.RTN,"body.theme-light{--btn-active:#0f766e;--btn-active-border:#0d9488;--btn-active-fg:#ffffff;--badge-bg:#dbeafe;--badge-fg:#0c4a6e;}")
 D ADDLN(.RTN,"body{margin:0;font-family:Arial,sans-serif;background:var(--bg);color:var(--fg);}")
 D ADDLN(.RTN,".top{padding:12px 16px;border-bottom:1px solid var(--top-border);background:var(--top-bg);}")
 D ADDLN(.RTN,".topline{display:flex;align-items:center;gap:10px;flex-wrap:wrap;}")
 D ADDLN(.RTN,".badge{font-size:11px;text-transform:uppercase;letter-spacing:.04em;padding:4px 8px;border-radius:999px;background:var(--badge-bg);color:var(--badge-fg);}")
 D ADDLN(.RTN,".top a{color:var(--link);text-decoration:none;margin-right:10px;}")
 D ADDLN(.RTN,".sub{font-size:12px;color:var(--muted);margin-top:4px;}")
 D ADDLN(.RTN,".srcnote{color:var(--muted);}")
 D ADDLN(.RTN,".wrap{display:flex;height:calc(100vh - 64px);min-height:0;box-sizing:border-box;}")
 D ADDLN(.RTN,".left{width:360px;flex:0 0 360px;min-width:0;border-right:1px solid var(--divider);display:flex;flex-direction:column;min-height:0;}")
 D ADDLN(.RTN,".right{flex:1;min-width:0;min-height:0;display:flex;flex-direction:column;}")
 D ADDLN(.RTN,".bar{padding:10px;border-bottom:1px solid var(--divider);}")
 D ADDLN(.RTN,"input,select{width:100%;padding:8px;border:1px solid var(--btn-border);border-radius:6px;background:var(--panel);color:var(--fg);}")
 D ADDLN(.RTN,"input::placeholder{color:var(--muted);}")
 D ADDLN(.RTN,".list{overflow:auto;flex:1;min-height:0;-webkit-overflow-scrolling:touch;}")
 D ADDLN(.RTN,".item{padding:10px;border-bottom:1px solid var(--item-border);cursor:pointer;}")
 D ADDLN(.RTN,".item.parent{border-left:3px solid var(--accent);}")
 D ADDLN(.RTN,".item.child{padding-left:28px;background:var(--panel);}")
 D ADDLN(.RTN,".item:hover{background:var(--item-hover);}")
 D ADDLN(.RTN,".item.active{background:var(--item-active);}")
 D ADDLN(.RTN,".rt{font-size:11px;color:var(--link);text-transform:uppercase;}")
 D ADDLN(.RTN,".item.child .rt{font-size:10px;color:var(--accent-2);}")
 D ADDLN(.RTN,".nm{font-weight:600;margin-top:2px;}")
 D ADDLN(.RTN,".id{font-size:12px;color:var(--muted);}")
 D ADDLN(.RTN,"pre{margin:0;padding:12px;overflow:auto;white-space:pre-wrap;word-break:break-word;flex:1;min-height:0;-webkit-overflow-scrolling:touch;background:var(--panel);}")
 D ADDLN(.RTN,".bar-meta{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;}")
 D ADDLN(.RTN,".fmtbtns{display:flex;gap:6px;flex-shrink:0;}")
 D ADDLN(.RTN,".fmtbtn{padding:6px 12px;border:1px solid var(--btn-border);border-radius:6px;background:var(--btn-bg);color:var(--fg);cursor:pointer;font-size:12px;}")
 D ADDLN(.RTN,".fmtbtn.active{background:var(--btn-active);border-color:var(--btn-active-border);color:var(--btn-active-fg);}")
 D ADDLN(.RTN,"@media (max-width:960px){")
 D ADDLN(.RTN,"html{overflow-y:scroll;-webkit-overflow-scrolling:touch;}")
 D ADDLN(.RTN,".wrap{flex-direction:column;height:auto;min-height:calc(100vh - 64px);min-height:calc(100dvh - 64px);}")
 D ADDLN(.RTN,".left{width:100%;flex:0 0 auto;max-height:clamp(140px,32vmax,300px);min-height:120px;border-right:none;border-bottom:1px solid var(--divider);}")
 D ADDLN(.RTN,".right{flex:0 0 auto;min-height:0;}")
 D ADDLN(.RTN,".list{overscroll-behavior:contain;touch-action:pan-y;}")
 D ADDLN(.RTN,"pre{flex:none;min-height:35vh;min-height:min(40dvh,280px);max-height:none;overflow-x:auto;overflow-y:visible;}")
 D ADDLN(.RTN,".fmtbtn{padding:8px 14px;min-height:44px;font-size:14px;}")
 D ADDLN(.RTN,".top{padding:10px 12px;padding-left:max(12px,env(safe-area-inset-left));padding-right:max(12px,env(safe-area-inset-right));}")
 D ADDLN(.RTN,"body{padding-bottom:env(safe-area-inset-bottom);}")
 D ADDLN(.RTN,"}")
 D ADDLN(.RTN,"</style>")
 D ADDLN(.RTN,"</head>")
 D ADDLN(.RTN,"<body class='"_THEME_"'>")
 D ADDLN(.RTN,"<div class='top'><div class='topline'><strong>C0FHIR Browser</strong><span class='badge'>"_BADGE_"</span></div>")
 S TOPLINKS="<div class='sub'><a href='/fhir'>index</a><a href="""_RAWURL_""">"_RAWLBL_"</a>"
 I ALTRAW'="" S TOPLINKS=TOPLINKS_"<a href="""_ALTRAW_""">"_ALTLBL_"</a>"
 I D>0 S TOPLINKS=TOPLINKS_"<a href=""/vpr?dfn="_D_""">vpr</a>"
 S TOPLINKS=TOPLINKS_"<span class='srcnote'>"_SRCNOTE_"</span>"
 I D>0 S TOPLINKS=TOPLINKS_" | DFN "_D
 I SRC="SHOWFHIR",IEN>0 S TOPLINKS=TOPLINKS_" | IEN "_IEN
 S TOPLINKS=TOPLINKS_"</div></div>"
 D ADDLN(.RTN,TOPLINKS)
 D ADDLN(.RTN,"<div class='wrap'>")
 D ADDLN(.RTN,"<section class='left'>")
 D ADDLN(.RTN,"<div class='bar'><input id='q' placeholder='Search text'></div>")
 D ADDLN(.RTN,"<div class='bar'><select id='type'><option value='all'>All resource types</option></select></div>")
 D ADDLN(.RTN,"<div id='list' class='list'></div>")
 D ADDLN(.RTN,"</section>")
 D ADDLN(.RTN,"<section class='right'>")
 D ADDLN(.RTN,"<div class='bar bar-meta'><span id='meta'>Loading...</span><div class='fmtbtns'><button type='button' class='fmtbtn' id='btnTjson'>TJSON</button><button type='button' class='fmtbtn' id='btnJson'>JSON</button></div></div>")
 D ADDLN(.RTN,"<pre id='detail'>Select a resource</pre>")
 D ADDLN(.RTN,"</section>")
 D ADDLN(.RTN,"</div>")
 D ADDLN(.RTN,"<script>")
 D ADDLN(.RTN,"const dfn="_D_";")
 D ADDLN(.RTN,"const graphIen="_IEN_";")
 D ADDLN(.RTN,"const sourceMode='"_$S(SRC="SHOWFHIR":"showfhir",1:"fhir")_"';")
 D ADDLN(.RTN,"const sourceLabel=sourceMode==='showfhir'?'Stored Synthea FHIR':'VistA-generated FHIR';")
 D ADDLN(.RTN,"const bundleUrl='"_LOADURL_"';")
 D ADDLN(.RTN,"const TJSON_PKG=location.origin+'/filesystem/tjson.js?v=0.6.0';")
 D ADDLN(.RTN,"const st={all:[],rows:[],tree:[],visible:[],pick:null,q:'',type:'all',fmt:'tjson'};")
 D ADDLN(.RTN,"try{const x=sessionStorage.getItem('c0fhirBrowserFmt');if(x==='json'||x==='tjson')st.fmt=x;}catch(e){}")
 D ADDLN(.RTN,"let tjsonMod=null;")
 D ADDLN(.RTN,"async function ensureTjson(){if(tjsonMod)return tjsonMod;tjsonMod=await import(TJSON_PKG);return tjsonMod;}")
 D ADDLN(.RTN,"const el=id=>document.getElementById(id);")
 D ADDLN(.RTN,"const esc=s=>String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');")
 D ADDLN(.RTN,"const rtype=e=>((e||{}).resource||{}).resourceType||'Unknown';")
 D ADDLN(.RTN,"const rid=e=>((e||{}).resource||{}).id||'';")
 D ADDLN(.RTN,"const ref=e=>((e||{}).fullUrl)||'';")
 D ADDLN(.RTN,"function isPlainTextMime(ct){const s=String(ct||'').toLowerCase();")
 D ADDLN(.RTN," return s.indexOf('text/plain')===0||s.indexOf('plain/text')===0;}")
 D ADDLN(.RTN,"function decodeBase64Utf8(b64){")
 D ADDLN(.RTN," try{")
 D ADDLN(.RTN,"  const bin=atob(String(b64||'').replace(/\s+/g,''));")
 D ADDLN(.RTN,"  if(typeof TextDecoder!=='function') return bin;")
 D ADDLN(.RTN,"  const bytes=new Uint8Array(bin.length);")
 D ADDLN(.RTN,"  for(let i=0;i<bin.length;i++) bytes[i]=bin.charCodeAt(i);")
 D ADDLN(.RTN,"  return new TextDecoder('utf-8').decode(bytes);")
 D ADDLN(.RTN," }catch(err){return null;}")
 D ADDLN(.RTN,"}")
 D ADDLN(.RTN,"function prepareForTjson(obj){")
 D ADDLN(.RTN," const r=obj||{};")
 D ADDLN(.RTN," if(r.resourceType!=='DocumentReference'||!Array.isArray(r.content)) return r;")
 D ADDLN(.RTN," const out=JSON.parse(JSON.stringify(r));")
 D ADDLN(.RTN," let changed=false;")
 D ADDLN(.RTN," out.content.forEach(x=>{")
 D ADDLN(.RTN,"  const a=(x||{}).attachment||null;let txt;")
 D ADDLN(.RTN,"  if(!a||!isPlainTextMime(a.contentType)||!a.data) return;")
 D ADDLN(.RTN,"  txt=decodeBase64Utf8(a.data);")
 D ADDLN(.RTN,"  if(txt===null) return;")
 D ADDLN(.RTN,"  a.data=txt;")
 D ADDLN(.RTN,"  changed=true;")
 D ADDLN(.RTN," });")
 D ADDLN(.RTN," return changed?out:r;}")
 D ADDLN(.RTN,"function titleOf(e){const r=(e||{}).resource||{};")
 D ADDLN(.RTN," if(r.code&&r.code.text) return r.code.text;")
 D ADDLN(.RTN," if(r.name&&r.name[0]&&r.name[0].text) return r.name[0].text;")
 D ADDLN(.RTN," if(r.description) return r.description;")
 D ADDLN(.RTN," return rtype(e)+' '+rid(e);}")
 D ADDLN(.RTN,"function reportKids(e,byRef){const r=(e||{}).resource||{};")
 D ADDLN(.RTN," if(rtype(e)!=='DiagnosticReport'||!Array.isArray(r.result)) return [];")
 D ADDLN(.RTN," const out=[],seen=new Set();")
 D ADDLN(.RTN," r.result.forEach(x=>{const u=(x&&x.reference)||'';if(!u||seen.has(u)) return;seen.add(u);if(byRef.has(u)) out.push(byRef.get(u));});")
 D ADDLN(.RTN," return out;}")
 D ADDLN(.RTN,"function refillTypes(){const s=el('type');")
 D ADDLN(.RTN," const set=new Set(st.all.map(rtype));")
 D ADDLN(.RTN," s.innerHTML=""<option value='all'>All resource types</option>"";")
 D ADDLN(.RTN," Array.from(set).sort().forEach(t=>{const o=document.createElement('option');o.value=t;o.textContent=t;s.appendChild(o);});")
 D ADDLN(.RTN," s.value=st.type;}")
 D ADDLN(.RTN,"function buildTree(){const byRef=new Map();")
 D ADDLN(.RTN," st.all.forEach(e=>{const u=ref(e);if(u) byRef.set(u,e);});")
 D ADDLN(.RTN," const childSet=new Set();")
 D ADDLN(.RTN," st.rows.forEach(e=>{if(rtype(e)!=='DiagnosticReport') return;reportKids(e,byRef).forEach(c=>childSet.add(c));});")
 D ADDLN(.RTN," st.tree=[];st.visible=[];")
 D ADDLN(.RTN," st.rows.forEach(e=>{if(childSet.has(e)) return;")
 D ADDLN(.RTN," if(rtype(e)==='DiagnosticReport'){const kids=reportKids(e,byRef);st.tree.push({entry:e,children:kids});st.visible.push(e);kids.forEach(c=>st.visible.push(c));return;}")
 D ADDLN(.RTN," st.tree.push({entry:e,children:[]});st.visible.push(e);});}")
 D ADDLN(.RTN,"function apply(){const q=st.q.toLowerCase();")
 D ADDLN(.RTN," st.rows=st.all.filter(e=>{const t=rtype(e);")
 D ADDLN(.RTN," if(st.type!=='all'&&t!==st.type) return false;")
 D ADDLN(.RTN," if(!q) return true;")
 D ADDLN(.RTN," return JSON.stringify((e||{}).resource||{}).toLowerCase().indexOf(q)>-1;});")
 D ADDLN(.RTN," buildTree();")
 D ADDLN(.RTN," if(!st.visible.length){st.pick=null;return;}")
 D ADDLN(.RTN," if(st.pick&&st.visible.indexOf(st.pick)>-1) return;")
 D ADDLN(.RTN," st.pick=st.visible[0];}")
 D ADDLN(.RTN,"function itemHtml(e,i,isChild){const a=(st.pick===e)?' active':'';")
 D ADDLN(.RTN," const cls=isChild?' child':' parent';")
 D ADDLN(.RTN," const tag=isChild?rtype(e)+' in report':rtype(e);")
 D ADDLN(.RTN," return ""<div class='item""+cls+a+""' data-i='""+i+""'><div class='rt'>""+esc(tag)+""</div><div class='nm'>""+esc(titleOf(e))+""</div><div class='id'>id: ""+esc(rid(e))+""</div></div>"";}")
 D ADDLN(.RTN,"function drawList(){const n=el('list');let h='';")
 D ADDLN(.RTN," const flat=[];")
 D ADDLN(.RTN," st.tree.forEach(nod=>{h+=itemHtml(nod.entry,flat.length,0);flat.push(nod.entry);")
 D ADDLN(.RTN," nod.children.forEach(ch=>{h+=itemHtml(ch,flat.length,1);flat.push(ch);});});")
 D ADDLN(.RTN," if(!h) h=""<div class='item'>No resources match.</div>"";")
 D ADDLN(.RTN," n.innerHTML=h;")
 D ADDLN(.RTN," n.querySelectorAll('.item[data-i]').forEach(x=>x.onclick=()=>{st.pick=flat[+x.dataset.i];draw();});}")
 D ADDLN(.RTN,"function updateFmtButtons(){")
 D ADDLN(.RTN," el('btnTjson').classList.toggle('active',st.fmt==='tjson');")
 D ADDLN(.RTN," el('btnJson').classList.toggle('active',st.fmt==='json');}")
 D ADDLN(.RTN,"function setFmt(f){")
 D ADDLN(.RTN," st.fmt=f;")
 D ADDLN(.RTN," try{sessionStorage.setItem('c0fhirBrowserFmt',f);}catch(e){}")
 D ADDLN(.RTN," updateFmtButtons();draw();}")
 D ADDLN(.RTN,"async function drawDetailAsync(){")
 D ADDLN(.RTN," el('meta').textContent=sourceLabel+': '+st.visible.length+' visible resources in '+st.tree.length+' top-level rows ('+st.all.length+' total)';")
 D ADDLN(.RTN," if(!st.pick){el('detail').textContent='Select a resource';return;}")
 D ADDLN(.RTN," const obj=(st.pick||{}).resource||{};")
 D ADDLN(.RTN," if(st.fmt==='json'){el('detail').textContent=JSON.stringify(obj,null,2);return;}")
 D ADDLN(.RTN," el('detail').textContent='Loading TJSON...';")
 D ADDLN(.RTN," try{")
 D ADDLN(.RTN,"  const m=await ensureTjson();")
 D ADDLN(.RTN,"  const tobj=prepareForTjson(obj);")
 D ADDLN(.RTN,"  const js=JSON.stringify(tobj);")
 D ADDLN(.RTN,"  el('detail').textContent=(typeof m.fromJson==='function'?m.fromJson(js,{}):m.stringify(js,{}));")
 D ADDLN(.RTN," }catch(err){el('detail').textContent='TJSON failed (sync vendor/tjson including tjson_bg.wasm.b64 into M user www; hard-refresh; redeploy): '+String(err);}")
 D ADDLN(.RTN,"}")
 D ADDLN(.RTN,"function draw(){drawList();updateFmtButtons();drawDetailAsync();}")
 D ADDLN(.RTN,"async function boot(){")
 D ADDLN(.RTN," const [r]=await Promise.all([fetch(bundleUrl),ensureTjson().catch(()=>null)]);")
 D ADDLN(.RTN," if(!r.ok) throw new Error('HTTP '+r.status+' loading '+bundleUrl);")
 D ADDLN(.RTN," const j=await r.json();")
 D ADDLN(.RTN," st.all=(j&&Array.isArray(j.entry))?j.entry:[];")
 D ADDLN(.RTN," refillTypes();")
 D ADDLN(.RTN," apply();")
 D ADDLN(.RTN," draw();}")
 D ADDLN(.RTN,"el('q').addEventListener('input',e=>{st.q=e.target.value||'';apply();draw();});")
 D ADDLN(.RTN,"el('type').addEventListener('change',e=>{st.type=e.target.value||'all';apply();draw();});")
 D ADDLN(.RTN,"el('btnTjson').addEventListener('click',()=>setFmt('tjson'));")
 D ADDLN(.RTN,"el('btnJson').addEventListener('click',()=>setFmt('json'));")
 D ADDLN(.RTN,"boot().catch(e=>{el('meta').textContent='Load failed';el('detail').textContent=String(e);});")
 D ADDLN(.RTN,"</script>")
 D ADDLN(.RTN,"</body>")
 D ADDLN(.RTN,"</html>")
 Q
 ;
SEARCH(RTN,VAL) ; Simple patient name search page
 N CNT,DFN,LINE,NAME,SSN,X0
 K RTN
 S RTN(1)="<!DOCTYPE HTML>"
 S RTN(2)="<html><head><title>Patient Search</title></head><body>"
 S RTN(3)="<h1>Patient Results for: "_$$HTMLESC($G(VAL))_"</h1>"
 S RTN(4)="<table border=""1"" cellpadding=""4"" cellspacing=""0"">"
 S RTN(5)="<tr><th>Name</th><th>DFN</th><th>SSN</th><th>FHIR</th><th>VPR</th></tr>"
 S (CNT,LINE)=5
 S NAME=""
 F  S NAME=$O(^DPT("B",NAME)) Q:NAME=""  D
 . I $$UPCASE^C0FHIR(NAME)'[$$UPCASE^C0FHIR($G(VAL)) Q
 . S DFN=0
 . F  S DFN=$O(^DPT("B",NAME,DFN)) Q:+DFN<1  D
 . . S X0=$G(^DPT(DFN,0))
 . . S SSN=$P(X0,"^",9)
 . . S LINE=LINE+1
 . . S RTN(LINE)="<tr><td>"_$$HTMLESC(NAME)_"</td><td>"_DFN_"</td><td>"_SSN_"</td><td><a href=""/fhir?dfn="_DFN_""">fhir</a></td><td><a href=""/vpr?dfn="_DFN_""">vpr</a></td></tr>"
 . . S CNT=CNT+1
 I CNT=0 S LINE=LINE+1,RTN(LINE)="<tr><td colspan=""5"">No matching patients found.</td></tr>"
 S LINE=LINE+1,RTN(LINE)="</table>"
 S LINE=LINE+1,RTN(LINE)="</body></html>"
 Q
 ;
HTMLESC(X) ; Escape basic HTML special chars
 N C,I,Y
 S Y=""
 F I=1:1:$L($G(X)) D
 . S C=$E(X,I)
 . I C="&" S Y=Y_"&amp;" Q
 . I C="<" S Y=Y_"&lt;" Q
 . I C=">" S Y=Y_"&gt;" Q
 . I C="""" S Y=Y_"&quot;" Q
 . I C="'" S Y=Y_"&#39;" Q
 . S Y=Y_C
 Q Y
 ;
ADDLN(RTN,TXT) ; Append one line to output array
 N IDX
 S IDX=$O(RTN(""),-1)+1
 S RTN(IDX)=$G(TXT)
 Q
 ;
