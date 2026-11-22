import{supabase}from'./supabase.js';

const PROFILE_BANNER_BUCKET='profile-banners';
const SIGNED_URL_TTL_SECONDS=60*60*24*7;

export async function resolveProfileBannerUrl(value){
 if(!value||!supabase)return '';
 let path=String(value).trim();
 if(/^https?:\/\//i.test(path)){
  try{
   const url=new URL(path);
   const markers=[
    '/storage/v1/object/public/'+PROFILE_BANNER_BUCKET+'/',
    '/storage/v1/object/sign/'+PROFILE_BANNER_BUCKET+'/'
   ];
   const marker=markers.find(item=>url.pathname.includes(item));
   if(!marker)return path;
   path=decodeURIComponent(url.pathname.slice(url.pathname.indexOf(marker)+marker.length));
  }catch{return path}
 }
 if(!path||path.startsWith('/')||path.includes('..'))return '';
 const{data,error}=await supabase.storage.from(PROFILE_BANNER_BUCKET).createSignedUrl(path,SIGNED_URL_TTL_SECONDS);
 if(error){console.warn('Profile banner URL could not be created:',error.message);return ''}
 return data?.signedUrl||'';
}
