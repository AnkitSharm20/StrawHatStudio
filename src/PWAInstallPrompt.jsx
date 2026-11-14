import React,{useEffect,useState} from 'react';
import {Download,X,Smartphone} from 'lucide-react';

export default function PWAInstallPrompt(){
 const [installEvent,setInstallEvent]=useState(null),[visible,setVisible]=useState(false),[busy,setBusy]=useState(false);
 useEffect(()=>{
  const onPrompt=event=>{event.preventDefault();setInstallEvent(event);setVisible(true)};
  const onInstalled=()=>{setVisible(false);setInstallEvent(null)};
  window.addEventListener('beforeinstallprompt',onPrompt);
  window.addEventListener('appinstalled',onInstalled);
  return()=>{window.removeEventListener('beforeinstallprompt',onPrompt);window.removeEventListener('appinstalled',onInstalled)};
 },[]);
 const install=async()=>{
  if(!installEvent||busy)return;
  setBusy(true);
  try{await installEvent.prompt();await installEvent.userChoice;setInstallEvent(null);setVisible(false)}
  catch(error){console.warn('PWA installation prompt failed:',error)}
  finally{setBusy(false)}
 };
 if(!visible||!installEvent)return null;
 return <aside className="pwa-install-prompt" aria-label="Install Straw Hat Studio"><span className="pwa-install-icon"><Smartphone size={19}/></span><span className="pwa-install-copy"><b>Take your crew with you</b><small>Install Straw Hat Studio on your device.</small></span><button type="button" className="primary" onClick={install} disabled={busy}><Download size={15}/>{busy?'Opening…':'Install'}</button><button type="button" className="pwa-install-dismiss" onClick={()=>setVisible(false)} aria-label="Dismiss install prompt"><X size={17}/></button></aside>;
}
