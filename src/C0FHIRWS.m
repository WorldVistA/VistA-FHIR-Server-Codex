C0FHIRWS ; VAMC/JS - FHIR web service entry point ; 11-MAR-2026
 ;;1.3;C0FHIR PROJECT;;Mar 11, 2026;Build 4
 ;
 Q
 ;
WEB(RTN,FILTER) ; Entry point for web service calls
 ; RTN:    Output array (passed by reference)
 ; FILTER: Input/Output array (passed by reference)
 ;
 N DFN,EDT,ENCPTR,NAME,SDT,VIEW
 K RTN
 S FILTER("type")="application/json" ; default mime type
 ;
 S DFN=$G(FILTER("dfn"))
 S NAME=$G(FILTER("name"))
 S ENCPTR=$G(FILTER("encounter"))
 S SDT=$G(FILTER("sdt"))
 S EDT=$G(FILTER("edt"))
 S VIEW=$$UPCASE^C0FHIR($G(FILTER("view")))
 I EDT="" S EDT=$$NOW^XLFDT
 ;
 ; Mode 1: Search by Name (HTML)
 I DFN="",NAME'="" D  Q
 . S FILTER("type")="text/html"
 . D SEARCH(.RTN,NAME)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 2: No DFN supplied -> HTML patient index
 I DFN="" D  Q
 . S FILTER("type")="text/html"
 . D FHIRIDX^C0FHIR(.RTN)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 3: Interactive browser (HTML) for one patient
 I VIEW="BROWSER" D  Q
 . S FILTER("type")="text/html"
 . D BROWSER(.RTN,DFN)
 . S HTTPRSP("mime")="text/html"
 ;
 ; Mode 4: Core FHIR aggregator (JSON)
 D GENFULL^C0FHIRGF(.RTN,DFN,ENCPTR,SDT,EDT)
 Q
 ;
BROWSER(RTN,DFN) ; Interactive FHIR browser (TJSON: /filesystem/tjson.js + tjson_bg.* + tjson_bg.wasm.b64 in M user www)
 N D
 S D=+$G(DFN)
 K RTN
 D ADDLN(.RTN,"<!DOCTYPE html>")
 D ADDLN(.RTN,"<html>")
 D ADDLN(.RTN,"<head>")
 D ADDLN(.RTN,"<meta charset='utf-8'>")
 D ADDLN(.RTN,"<meta name='viewport' content='width=device-width, initial-scale=1'>")
 D ADDLN(.RTN,"<title>C0FHIR Browser</title>")
 D ADDLN(.RTN,"<style>")
 D ADDLN(.RTN,"body{margin:0;font-family:Arial,sans-serif;background:#0b1220;color:#e2e8f0;}")
 D ADDLN(.RTN,".top{padding:12px 16px;border-bottom:1px solid #334155;background:#111827;}")
 D ADDLN(.RTN,".top a{color:#93c5fd;text-decoration:none;margin-right:10px;}")
 D ADDLN(.RTN,".sub{font-size:12px;color:#94a3b8;margin-top:4px;}")
 D ADDLN(.RTN,".wrap{display:flex;height:calc(100vh - 64px);min-height:0;box-sizing:border-box;}")
 D ADDLN(.RTN,".left{width:360px;flex:0 0 360px;min-width:0;border-right:1px solid #334155;display:flex;flex-direction:column;min-height:0;}")
 D ADDLN(.RTN,".right{flex:1;min-width:0;min-height:0;display:flex;flex-direction:column;}")
 D ADDLN(.RTN,".bar{padding:10px;border-bottom:1px solid #334155;}")
 D ADDLN(.RTN,"input,select{width:100%;padding:8px;border:1px solid #334155;border-radius:6px;background:#0f172a;color:#e2e8f0;}")
 D ADDLN(.RTN,".list{overflow:auto;flex:1;min-height:0;-webkit-overflow-scrolling:touch;}")
 D ADDLN(.RTN,".item{padding:10px;border-bottom:1px solid #1f2937;cursor:pointer;}")
 D ADDLN(.RTN,".item.parent{border-left:3px solid #1d4ed8;}")
 D ADDLN(.RTN,".item.child{padding-left:28px;background:#0f172a;}")
 D ADDLN(.RTN,".item:hover{background:#111827;}")
 D ADDLN(.RTN,".item.active{background:#172554;}")
 D ADDLN(.RTN,".rt{font-size:11px;color:#93c5fd;text-transform:uppercase;}")
 D ADDLN(.RTN,".item.child .rt{font-size:10px;color:#60a5fa;}")
 D ADDLN(.RTN,".nm{font-weight:600;margin-top:2px;}")
 D ADDLN(.RTN,".id{font-size:12px;color:#94a3b8;}")
 D ADDLN(.RTN,"pre{margin:0;padding:12px;overflow:auto;white-space:pre-wrap;word-break:break-word;flex:1;min-height:0;-webkit-overflow-scrolling:touch;}")
 D ADDLN(.RTN,".bar-meta{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;}")
 D ADDLN(.RTN,".fmtbtns{display:flex;gap:6px;flex-shrink:0;}")
 D ADDLN(.RTN,".fmtbtn{padding:6px 12px;border:1px solid #334155;border-radius:6px;background:#0f172a;color:#e2e8f0;cursor:pointer;font-size:12px;}")
 D ADDLN(.RTN,".fmtbtn.active{background:#1d4ed8;border-color:#2563eb;color:#fff;}")
 D ADDLN(.RTN,"@media (max-width:960px){")
 D ADDLN(.RTN,"html{overflow-y:scroll;-webkit-overflow-scrolling:touch;}")
 D ADDLN(.RTN,".wrap{flex-direction:column;height:auto;min-height:calc(100vh - 64px);min-height:calc(100dvh - 64px);}")
 D ADDLN(.RTN,".left{width:100%;flex:0 0 auto;max-height:clamp(140px,32vmax,300px);min-height:120px;border-right:none;border-bottom:1px solid #334155;}")
 D ADDLN(.RTN,".right{flex:0 0 auto;min-height:0;}")
 D ADDLN(.RTN,".list{overscroll-behavior:contain;touch-action:pan-y;}")
 D ADDLN(.RTN,"pre{flex:none;min-height:35vh;min-height:min(40dvh,280px);max-height:none;overflow-x:auto;overflow-y:visible;}")
 D ADDLN(.RTN,".fmtbtn{padding:8px 14px;min-height:44px;font-size:14px;}")
 D ADDLN(.RTN,".top{padding:10px 12px;padding-left:max(12px,env(safe-area-inset-left));padding-right:max(12px,env(safe-area-inset-right));}")
 D ADDLN(.RTN,"body{padding-bottom:env(safe-area-inset-bottom);}")
 D ADDLN(.RTN,"}")
 D ADDLN(.RTN,"</style>")
 D ADDLN(.RTN,"</head>")
 D ADDLN(.RTN,"<body>")
 D ADDLN(.RTN,"<div class='top'><strong>C0FHIR Browser</strong>")
 D ADDLN(.RTN,"<div class='sub'><a href='/fhir'>index</a><a href='/fhir?dfn="_D_"'>raw fhir</a><a href='/vpr?dfn="_D_"'>vpr</a> DFN "_D_"</div></div>")
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
 D ADDLN(.RTN,"const TJSON_PKG=location.origin+'/filesystem/tjson.js?v=044';")
 D ADDLN(.RTN,"const st={all:[],rows:[],tree:[],visible:[],pick:null,q:'',type:'all',fmt:'tjson'};")
 D ADDLN(.RTN,"try{const x=sessionStorage.getItem('c0fhirBrowserFmt');if(x==='json'||x==='tjson')st.fmt=x;}catch(e){}")
 D ADDLN(.RTN,"let tjsonMod=null;")
 D ADDLN(.RTN,"async function ensureTjson(){if(tjsonMod)return tjsonMod;tjsonMod=await import(TJSON_PKG);return tjsonMod;}")
 D ADDLN(.RTN,"const el=id=>document.getElementById(id);")
 D ADDLN(.RTN,"const esc=s=>String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');")
 D ADDLN(.RTN,"const rtype=e=>((e||{}).resource||{}).resourceType||'Unknown';")
 D ADDLN(.RTN,"const rid=e=>((e||{}).resource||{}).id||'';")
 D ADDLN(.RTN,"const ref=e=>((e||{}).fullUrl)||'';")
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
 D ADDLN(.RTN," el('meta').textContent=st.visible.length+' visible resources in '+st.tree.length+' top-level rows ('+st.all.length+' total)';")
 D ADDLN(.RTN," if(!st.pick){el('detail').textContent='Select a resource';return;}")
 D ADDLN(.RTN," const obj=(st.pick||{}).resource||{};")
 D ADDLN(.RTN," if(st.fmt==='json'){el('detail').textContent=JSON.stringify(obj,null,2);return;}")
 D ADDLN(.RTN," el('detail').textContent='Loading TJSON…';")
 D ADDLN(.RTN," try{")
 D ADDLN(.RTN,"  const m=await ensureTjson();")
 D ADDLN(.RTN,"  const js=JSON.stringify(obj);")
 D ADDLN(.RTN,"  el('detail').textContent=(typeof m.fromJson==='function'?m.fromJson(js,{}):m.stringify(js,{}));")
 D ADDLN(.RTN," }catch(err){el('detail').textContent='TJSON failed (sync vendor/tjson including tjson_bg.wasm.b64 into M user www; hard-refresh; redeploy): '+String(err);}")
 D ADDLN(.RTN,"}")
 D ADDLN(.RTN,"function draw(){drawList();updateFmtButtons();drawDetailAsync();}")
 D ADDLN(.RTN,"async function boot(){")
 D ADDLN(.RTN," const [r]=await Promise.all([fetch('/fhir?dfn='+dfn),ensureTjson().catch(()=>null)]);")
 D ADDLN(.RTN," if(!r.ok) throw new Error('HTTP '+r.status+' loading /fhir?dfn='+dfn);")
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
