import http from "node:http";
import net from "node:net";
import os from "node:os";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {exec} from "node:child_process";

const APP_ID = "1565366157559595099";
const PORT = 47831;
const ROOT = path.dirname(fileURLToPath(import.meta.url));
const STORE = path.join(ROOT, "presets.json");
const PID = process.pid;
let pipe = null, rpcReady = false, lastActivity = null, lastError = "Discord desktop not connected";
let reconnectTimer = null;
const defaults = [
 {id:"streaming-luffy",name:"Streaming Luffy",type:3,details:"STREAMING LUFFY",state:"Exploring the Grand Line",largeImage:"https://straw-hat-studio.vercel.app/og-image.png",largeText:"Straw Hat Studio",buttonLabel:"Visit Straw Hat Studio",buttonUrl:"https://straw-hat-studio.vercel.app"},
 {id:"gear-five",name:"Gear Five",type:3,details:"UNLEASHING GEAR 5",state:"The drums of liberation",largeImage:"",largeText:"Gear Five"},
 {id:"grand-line",name:"Grand Line",type:0,details:"SAILING THE GRAND LINE",state:"Finding the One Piece",largeImage:"",largeText:"Straw Hat Crew"}
];
function readPresets(){try{const v=JSON.parse(fs.readFileSync(STORE,"utf8"));return Array.isArray(v)?v:defaults}catch{return defaults}}
function writePresets(v){fs.writeFileSync(STORE,JSON.stringify(v,null,2),"utf8")}
function frame(op,payload){const body=Buffer.from(JSON.stringify(payload));const head=Buffer.alloc(8);head.writeUInt32LE(body.length,0);head.writeUInt32LE(op,4);return Buffer.concat([head,body])}
function connectDiscord(index=0){
 if(index>9){lastError="Discord desktop IPC was not found. Open the Discord desktop app.";rpcReady=false;return}
 const candidate=net.createConnection("\\\\.\\pipe\\discord-ipc-"+index);
 candidate.once("connect",()=>{pipe=candidate;candidate.write(frame(0,{v:1,client_id:APP_ID}));lastError="Connecting to Discord…"});
 candidate.on("data",buf=>{
  let offset=0;
  while(offset+8<=buf.length){const len=buf.readUInt32LE(offset),op=buf.readUInt32LE(offset+4);if(offset+8+len>buf.length)break;let data={};try{data=JSON.parse(buf.subarray(offset+8,offset+8+len).toString())}catch{}offset+=8+len;if(op===1&&data.cmd==="DISPATCH"&&data.evt==="READY"){rpcReady=true;lastError="Connected to Discord";if(lastActivity)sendActivity(lastActivity)}}
 });
 candidate.on("error",()=>{if(pipe===candidate)pipe=null;rpcReady=false;if(index===9){lastError="Discord desktop not detected";scheduleReconnect()}else connectDiscord(index+1)});
 candidate.on("close",()=>{if(pipe===candidate)pipe=null;rpcReady=false;lastError="Discord connection closed";scheduleReconnect()});
}
function scheduleReconnect(){if(reconnectTimer)return;reconnectTimer=setTimeout(()=>{reconnectTimer=null;connectDiscord(0)},4000)}
function sendCommand(cmd,args){if(!pipe||!rpcReady)throw new Error("Open Discord desktop first, then retry.");pipe.write(frame(1,{cmd,args,nonce:crypto.randomUUID()}))}
import crypto from "node:crypto";
function validateActivity(raw){
 const clean=(v,n)=>String(v||"").trim().slice(0,n);
 const details=clean(raw.details,128)||"STREAMING LUFFY";
 const state=clean(raw.state,128);
 const type=[0,2,3,5].includes(Number(raw.type))?Number(raw.type):3;
 const activity={type,details};
 if(state)activity.state=state;
 activity.timestamps={start:Math.floor(Date.now()/1000)};
 const assets={};
 if(/^https:\/\//i.test(raw.largeImage||"")){assets.large_image=clean(raw.largeImage,500);if(raw.largeText)assets.large_text=clean(raw.largeText,128)}
 if(/^https:\/\//i.test(raw.smallImage||"")){assets.small_image=clean(raw.smallImage,500);if(raw.smallText)assets.small_text=clean(raw.smallText,128)}
 if(Object.keys(assets).length)activity.assets=assets;
 const label=clean(raw.buttonLabel,32),url=clean(raw.buttonUrl,500);
 if(label&&/^https:\/\//i.test(url))activity.buttons=[{label,url}];
 return activity;
}
function sendActivity(activity){lastActivity=activity;sendCommand("SET_ACTIVITY",{pid:PID,activity})}
function json(res,status,data){res.writeHead(status,{"content-type":"application/json; charset=utf-8","cache-control":"no-store","access-control-allow-origin":"http://127.0.0.1:"+PORT,"access-control-allow-methods":"GET,POST,OPTIONS","access-control-allow-headers":"content-type"});res.end(JSON.stringify(data))}
const html=String.raw`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Luffy Status Studio</title><style>
:root{color-scheme:dark;--bg:#080d17;--panel:#111a2b;--line:#263650;--gold:#d9b66c;--muted:#9ba9bc;--text:#f4f1e9}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 75% 0,#26344a 0,transparent 45%),var(--bg);color:var(--text);font:14px Segoe UI,Arial,sans-serif}.wrap{max-width:1050px;margin:auto;padding:32px 20px 60px}.top{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:28px}.brand{font:800 12px Consolas,monospace;letter-spacing:3px;color:var(--gold)}h1{font-size:clamp(30px,6vw,48px);margin:8px 0}p{color:var(--muted);line-height:1.65}.status{border:1px solid var(--line);border-radius:30px;padding:9px 13px;color:var(--muted);font-size:12px}.dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#e0a64f;margin-right:8px}.dot.ok{background:#48d69a}.grid{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(280px,.9fr);gap:18px}.panel{background:linear-gradient(145deg,#141f32,#0d1524);border:1px solid var(--line);border-radius:16px;padding:22px;min-width:0}.eyebrow{font:11px Consolas,monospace;letter-spacing:2px;color:var(--gold)}label{display:block;color:#dce3ed;font-size:12px;margin:16px 0 7px}input,select{width:100%;height:42px;border:1px solid var(--line);border-radius:8px;background:#080f1c;color:var(--text);padding:0 11px;outline:none}input:focus,select:focus{border-color:var(--gold)}.row{display:grid;grid-template-columns:1fr 1fr;gap:12px}.btn{border:1px solid var(--line);border-radius:8px;padding:11px 15px;background:#1a2940;color:var(--text);cursor:pointer}.primary{background:var(--gold);border-color:var(--gold);color:#17130b;font-weight:800}.buttons{display:flex;flex-wrap:wrap;gap:9px;margin-top:18px}.preset{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:12px 0;border-top:1px solid var(--line)}.preset button{margin-left:5px}.note{font-size:12px;color:var(--muted);line-height:1.7;margin-top:16px}.preview{border:1px solid #26334a;background:#101827;border-radius:12px;padding:17px;margin-top:12px}.preview strong{display:block;margin:12px 0 6px}.preview small{color:var(--muted)}@media(max-width:750px){.grid{grid-template-columns:1fr}.top{align-items:flex-start;flex-direction:column}.row{grid-template-columns:1fr}}
</style></head><body><main class="wrap"><div class="top"><div><div class="brand">STRAW HAT STUDIO · DESKTOP COMPANION</div><h1>Luffy Status Studio</h1><p>Build a live Discord Rich Presence and keep your favourite Luffy activity presets.</p></div><div class="status"><i class="dot" id="dot"></i><span id="connection">Checking Discord…</span></div></div><div class="grid"><section class="panel"><div class="eyebrow">PRESENCE BUILDER</div><div class="row"><div><label>Activity type</label><select id="type"><option value="3">Watching</option><option value="0">Playing</option><option value="2">Listening</option><option value="5">Competing</option></select></div><div><label>Preset</label><select id="preset"><option value="">Custom activity</option></select></div></div><label>Details · main line</label><input id="details" maxlength="128" value="STREAMING LUFFY"><label>State · second line</label><input id="state" maxlength="128" value="Exploring the Grand Line"><label>Large image URL (optional)</label><input id="largeImage" placeholder="https://…"><label>Large image hover text</label><input id="largeText" maxlength="128" placeholder="Straw Hat Studio"><div class="row"><div><label>Button label</label><input id="buttonLabel" maxlength="32" value="Visit Straw Hat Studio"></div><div><label>Button URL</label><input id="buttonUrl" value="https://straw-hat-studio.vercel.app"></div></div><div class="buttons"><button class="btn primary" id="apply">Set Discord Presence</button><button class="btn" id="clear">Clear Presence</button><button class="btn" id="save">Save as preset</button></div><div class="preview"><div class="eyebrow">PREVIEW</div><strong id="previewTitle">Watching</strong><span id="previewDetails">STREAMING LUFFY</span><br><small id="previewState">Exploring the Grand Line</small></div><p class="note">This uses Discord's supported Rich Presence RPC. It does not change the separate Custom Status bubble (the text shown beside your username). Discord's RPC activity types do not include a literal “Streaming” type; use Watching or Playing with “STREAMING LUFFY” in Details. The application name is configured in the Discord Developer Portal.</p></section><section class="panel"><div class="eyebrow">YOUR QUICK PRESETS</div><h2 style="font-size:23px">Saved activities</h2><div id="presets"></div><p class="note">Select any preset to load it into the builder, then activate it. Presets are stored locally on this Windows PC. Never share your Discord token or client secret with this app.</p></section></div></main><script>
const $=id=>document.getElementById(id);let presets=[];
const fields=["type","details","state","largeImage","largeText","buttonLabel","buttonUrl"];
function values(){return Object.fromEntries(fields.map(k=>[k,$(k).value]))}
function fill(v){fields.forEach(k=>{if(v[k]!==undefined)$(k).value=v[k]});preview()}
function preview(){$("previewTitle").textContent=({0:"Playing",2:"Listening to",3:"Watching",5:"Competing in"})[$("type").value];$("previewDetails").textContent=$("details").value||"STREAMING LUFFY";$("previewState").textContent=$("state").value}
fields.forEach(k=>$(k).addEventListener("input",preview));
async function api(url,body){const r=await fetch(url,{method:body?"POST":"GET",headers:{"content-type":"application/json"},body:body?JSON.stringify(body):undefined});const d=await r.json();if(!r.ok)throw Error(d.error||"Request failed");return d}
async function refresh(){const d=await api("/api/state");$("connection").textContent=d.status;$("dot").className="dot "+(d.connected?"ok":"");presets=await api("/api/presets").then(x=>x.presets);render()}
function render(){const sel=$("preset");sel.innerHTML='<option value="">Custom activity</option>'+presets.map(p=>'<option value="'+p.id+'">'+escapeHtml(p.name)+'</option>').join("");$("presets").innerHTML=presets.map(p=>'<div class="preset"><div><b>'+escapeHtml(p.name)+'</b><br><small>'+escapeHtml(p.details||"")+'</small></div><div><button class="btn" data-load="'+p.id+'">Load</button><button class="btn" data-del="'+p.id+'">×</button></div></div>').join("")||'<p>No presets saved yet.</p>';document.querySelectorAll("[data-load]").forEach(b=>b.onclick=()=>{const p=presets.find(x=>x.id===b.dataset.load);if(p)fill(p)});document.querySelectorAll("[data-del]").forEach(b=>b.onclick=async()=>{presets=presets.filter(x=>x.id!==b.dataset.del);await api("/api/presets",{presets});render()})}
function escapeHtml(s){return String(s||"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]))}
$("preset").onchange=()=>{const p=presets.find(x=>x.id===$("preset").value);if(p)fill(p)};
$("apply").onclick=async()=>{try{await api("/api/activity",values());$("connection").textContent="Presence updated"}catch(e){alert(e.message)}};
$("clear").onclick=async()=>{try{await api("/api/clear");alert("Discord Rich Presence cleared.")}catch(e){alert(e.message)}};
$("save").onclick=async()=>{const name=prompt("Name this preset");if(!name)return;presets.push({id:crypto.randomUUID(),name:name.slice(0,48),...values()});await api("/api/presets",{presets});render()};
refresh().catch(e=>$("connection").textContent=e.message);setInterval(()=>refresh().catch(()=>{}),6000);
</script></body></html>`;
const server=http.createServer(async(req,res)=>{
 if(req.method==="OPTIONS"){res.writeHead(204);return res.end()}
 const url=new URL(req.url,"http://127.0.0.1:"+PORT);
 if(url.pathname==="/"&&req.method==="GET"){res.writeHead(200,{"content-type":"text/html; charset=utf-8","cache-control":"no-store"});return res.end(html)}
 if(url.pathname==="/api/state"&&req.method==="GET")return json(res,200,{connected:rpcReady,status:lastError});
 if(url.pathname==="/api/presets"&&req.method==="GET")return json(res,200,{presets:readPresets()});
 let body="";req.on("data",chunk=>{body+=chunk;if(body.length>100000){req.destroy()}});req.on("end",()=>{
  let data={};try{data=body?JSON.parse(body):{}}catch{return json(res,400,{error:"Invalid JSON"})}
  try{
   if(url.pathname==="/api/activity"&&req.method==="POST"){const activity=validateActivity(data);sendActivity(activity);return json(res,200,{ok:true})}
   if(url.pathname==="/api/clear"&&req.method==="POST"){sendCommand("SET_ACTIVITY",{pid:PID,activity:null});lastActivity=null;return json(res,200,{ok:true})}
   if(url.pathname==="/api/presets"&&req.method==="POST"){if(!Array.isArray(data.presets)||data.presets.length>50)return json(res,400,{error:"Maximum 50 presets"});writePresets(data.presets.map(p=>({id:String(p.id).slice(0,80),name:String(p.name||"Preset").slice(0,48),type:p.type,details:String(p.details||"").slice(0,128),state:String(p.state||"").slice(0,128),largeImage:String(p.largeImage||"").slice(0,500),largeText:String(p.largeText||"").slice(0,128),buttonLabel:String(p.buttonLabel||"").slice(0,32),buttonUrl:String(p.buttonUrl||"").slice(0,500)})));return json(res,200,{ok:true})}
   return json(res,404,{error:"Not found"});
  }catch(e){return json(res,400,{error:e.message})}
 });
});
server.listen(PORT,"127.0.0.1",()=>{console.log("Luffy Status Studio: http://127.0.0.1:"+PORT);exec('start "" "http://127.0.0.1:'+PORT+'"')});
connectDiscord(0);
process.on("SIGINT",()=>{try{if(pipe&&rpcReady)sendCommand("SET_ACTIVITY",{pid:PID,activity:null})}catch{}server.close(()=>process.exit(0))});
