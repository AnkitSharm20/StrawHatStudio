import React,{useEffect,useRef,useState} from 'react';
import {Download,X,Smartphone,RefreshCw} from 'lucide-react';

export default function PWAInstallPrompt(){
 const [installEvent,setInstallEvent]=useState(null),[visible,setVisible]=useState(false),[busy,setBusy]=useState(false);
 const [registration,setRegistration]=useState(null),[updateAvailable,setUpdateAvailable]=useState(false),[refreshing,setRefreshing]=useState(false);
 const refreshRequested=useRef(false);
 useEffect(()=>{
  const onPrompt=event=>{event.preventDefault();setInstallEvent(event);setVisible(true)};
  const onInstalled=()=>{setVisible(false);setInstallEvent(null)};
  window.addEventListener('beforeinstallprompt',onPrompt);
  window.addEventListener('appinstalled',onInstalled);
  return()=>{window.removeEventListener('beforeinstallprompt',onPrompt);window.removeEventListener('appinstalled',onInstalled)};
 },[]);
 useEffect(()=>{
  if(!('serviceWorker' in navigator))return;
  let active=true,reg=null,installing=null;
  const onControllerChange=()=>{if(refreshRequested.current)window.location.reload()};
  const onUpdateReady=()=>{if(active&&reg?.waiting&&navigator.serviceWorker.controller)setUpdateAvailable(true)};
  navigator.serviceWorker.addEventListener('controllerchange',onControllerChange);
  navigator.serviceWorker.ready.then(async value=>{
   if(!active)return;
   reg=value;setRegistration(value);onUpdateReady();
   value.addEventListener('updatefound',()=>{
    installing=value.installing;
    installing?.addEventListener('statechange',()=>{
     if(active&&installing?.state==='installed'&&navigator.serviceWorker.controller)setUpdateAvailable(true);
    });
   });
   value.update().catch(()=>{});
  }).catch(()=>{});
  return()=>{active=false;navigator.serviceWorker.removeEventListener('controllerchange',onControllerChange);reg?.removeEventListener('updatefound',onUpdateReady)};
 },[]);
 const install=async()=>{
  if(!installEvent||busy)return;
  setBusy(true);
  try{await installEvent.prompt();await installEvent.userChoice;setInstallEvent(null);setVisible(false)}
  catch(error){console.warn('PWA installation prompt failed:',error)}
  finally{setBusy(false)}
 };
 const refresh=()=>{
  if(!registration?.waiting||refreshing)return;
  refreshRequested.current=true;setRefreshing(true);
  registration.waiting.postMessage({type:'SKIP_WAITING'});
 };
 return <>
  {visible&&installEvent&&<aside className="pwa-install-prompt" aria-label="Install Straw Hat Studio"><span className="pwa-install-icon"><Smartphone size={19}/></span><span className="pwa-install-copy"><b>Take your crew with you</b><small>Install Straw Hat Studio on your device.</small></span><button type="button" className="primary" onClick={install} disabled={busy}><Download size={15}/>{busy?'Opening…':'Install'}</button><button type="button" className="pwa-install-dismiss" onClick={()=>setVisible(false)} aria-label="Dismiss install prompt"><X size={17}/></button></aside>}
  {updateAvailable&&<aside className="pwa-update-prompt" role="status" aria-live="polite"><span className="pwa-install-icon"><RefreshCw size={18}/></span><span className="pwa-install-copy"><b>A fresh version is ready</b><small>Refresh when you're ready. Your current work stays open until then.</small></span><button type="button" className="primary" onClick={refresh} disabled={refreshing}>{refreshing?'Updating…':'Refresh'}</button></aside>}
 </>;
}
