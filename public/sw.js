const CACHE_VERSION='straw-hat-shell-v3';
const SHELL_CACHE=CACHE_VERSION+'-shell';
const STATIC_CACHE=CACHE_VERSION+'-static';
const OFFLINE_URL='/offline.html';
self.addEventListener('install',event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(SHELL_CACHE);
    await cache.addAll([OFFLINE_URL,'/manifest.webmanifest','/icons/straw-hat.svg']);
  })());
});
self.addEventListener('message',event=>{if(event.data?.type==='SKIP_WAITING')self.skipWaiting()});
self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(key=>key.startsWith('straw-hat-')&&!key.startsWith(CACHE_VERSION)).map(key=>caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin)return;
  if(url.pathname.startsWith('/rest/')||url.pathname.startsWith('/auth/')||url.pathname.startsWith('/functions/')||url.pathname.startsWith('/storage/'))return;
  if(request.mode==='navigate'){
    event.respondWith((async()=>{
      try{
        const response=await fetch(request);
        if(response.ok){const cache=await caches.open(SHELL_CACHE);cache.put('/',response.clone());}
        return response;
      }catch{
        const cached=await caches.match('/')||await caches.match(OFFLINE_URL);
        return cached||new Response('You are offline. Reconnect and try again.',{status:503,headers:{'Content-Type':'text/plain'}});
      }
    })());
    return;
  }
  if(/\.(?:js|css|svg|png|jpg|jpeg|webp|avif|woff2?)$/i.test(url.pathname)){
    event.respondWith((async()=>{
      const cache=await caches.open(STATIC_CACHE);
      const network=fetch(request).then(response=>{if(response.ok)cache.put(request,response.clone());return response}).catch(()=>null);
      return await network||await cache.match(request)||new Response('',{status:504});
    })());
  }
});
