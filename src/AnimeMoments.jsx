import React,{useCallback,useEffect,useState} from 'react';
import {Link} from 'react-router-dom';
import {Heart,Plus,RefreshCw,Upload,Video,Image as ImageIcon,Clock,ArrowLeft,Compass} from 'lucide-react';
import {supabase} from './lib/supabase.js';

const MAX_FILE_SIZE=20*1024*1024;
const MIME_EXTENSIONS={'image/jpeg':'jpg','image/png':'png','image/webp':'webp','image/gif':'gif','video/mp4':'mp4','video/webm':'webm'};
const formatDate=value=>{const date=new Date(value);return Number.isNaN(date.getTime())?'Recently':new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric'}).format(date)};

export default function AnimeMoments({user}){
 const [moments,setMoments]=useState([]),[pending,setPending]=useState([]),[loading,setLoading]=useState(true),[error,setError]=useState(''),[uploading,setUploading]=useState(false),[caption,setCaption]=useState(''),[selectedFile,setSelectedFile]=useState(null),[liked,setLiked]=useState({}),[busyLike,setBusyLike]=useState({}),[moderating,setModerating]=useState({});
 const isAdmin=user?.app_metadata?.role==='admin';
 const load=useCallback(async()=>{
  if(!supabase){setError('The community service is not configured.');setLoading(false);return}
  setLoading(true);setError('');
  const {data,error:feedError}=await supabase.from('anime_moments').select('id,creator_id,caption,media_path,media_type,created_at,published_at').eq('status','published').order('published_at',{ascending:false}).limit(30);
  if(feedError){setError('Anime Moments could not load. Please try again.');setMoments([]);setLoading(false);return}
  const rows=data||[],ids=rows.map(row=>row.id),creatorIds=[...new Set(rows.map(row=>row.creator_id))];
  const [profilesResult,reactionsResult,myReactionsResult,pendingResult]=await Promise.all([
   creatorIds.length?supabase.from('profiles').select('id,username,avatar_url').in('id',creatorIds):Promise.resolve({data:[]}),
   ids.length?supabase.from('anime_moment_reactions').select('moment_id').in('moment_id',ids):Promise.resolve({data:[]}),
   user?.id&&ids.length?supabase.from('anime_moment_reactions').select('moment_id').eq('user_id',user.id).in('moment_id',ids):Promise.resolve({data:[]}),
   user?.id?(()=>{let query=supabase.from('anime_moments').select('id,caption,media_path,media_type,created_at').eq('status','pending').order('created_at',{ascending:false}).limit(isAdmin?30:5);if(!isAdmin)query=query.eq('creator_id',user.id);return query})():Promise.resolve({data:[]})
  ]);
  const profileMap=Object.fromEntries((profilesResult.data||[]).map(profile=>[profile.id,profile]));
  const counts={};for(const reaction of reactionsResult.data||[])counts[reaction.moment_id]=(counts[reaction.moment_id]||0)+1;
  setLiked(Object.fromEntries((myReactionsResult.data||[]).map(reaction=>[reaction.moment_id,true])));
  setPending((pendingResult.data||[]).map(item=>({...item,mediaUrl:supabase.storage.from('anime-moments').getPublicUrl(item.media_path).data.publicUrl})));
  setMoments(rows.map(row=>({...row,profile:profileMap[row.creator_id]||null,likes:counts[row.id]||0,mediaUrl:supabase.storage.from('anime-moments').getPublicUrl(row.media_path).data.publicUrl})));
  setLoading(false);
 },[user?.id,isAdmin]);
 useEffect(()=>{load()},[load]);
 const chooseFile=file=>{
  if(!file)return;
  if(!MIME_EXTENSIONS[file.type]){setError('Choose a JPG, PNG, WebP, GIF, MP4 or WebM file.');return}
  if(file.size>MAX_FILE_SIZE){setError('The file must be 20 MB or smaller.');return}
  setError('');setSelectedFile(file);
 };
 const submit=async event=>{
  event.preventDefault();
  if(!user){setError('Sign in to share an Anime Moment.');return}
  if(!selectedFile){setError('Choose an image or video first.');return}
  if(!supabase){setError('The upload service is unavailable.');return}
  setUploading(true);setError('');
  const path=user.id+'/'+crypto.randomUUID()+'.'+MIME_EXTENSIONS[selectedFile.type];
  const {error:uploadError}=await supabase.storage.from('anime-moments').upload(path,selectedFile,{contentType:selectedFile.type,cacheControl:'3600',upsert:false});
  if(uploadError){setError(uploadError.message||'Upload failed.');setUploading(false);return}
  const {error:insertError}=await supabase.from('anime_moments').insert({creator_id:user.id,caption:caption.trim(),media_path:path,media_type:selectedFile.type.startsWith('video/')?'video':'image',status:'pending'});
  if(insertError){await supabase.storage.from('anime-moments').remove([path]);setError(insertError.message||'Your moment could not be submitted.');setUploading(false);return}
  setCaption('');setSelectedFile(null);const input=document.getElementById('anime-moment-file');if(input)input.value='';
  await load();setUploading(false);
 };
 const moderate=async(item,status)=>{
  if(!isAdmin||moderating[item.id])return;
  setModerating(prev=>({...prev,[item.id]:true}));
  const {error:updateError}=await supabase.from('anime_moments').update({status,published_at:status==='published'?new Date().toISOString():null,updated_at:new Date().toISOString()}).eq('id',item.id);
  if(updateError)setError('Moderation update failed: '+updateError.message);
  else await load();
  setModerating(prev=>({...prev,[item.id]:false}));
 };
 const toggleLike=async moment=>{
  if(!user){setError('Sign in to like Anime Moments.');return}
  if(busyLike[moment.id])return;
  setBusyLike(prev=>({...prev,[moment.id]:true}));
  const wasLiked=!!liked[moment.id];
  setLiked(prev=>({...prev,[moment.id]:!wasLiked}));
  setMoments(prev=>prev.map(item=>item.id===moment.id?{...item,likes:Math.max(0,item.likes+(wasLiked?-1:1))}:item));
  const result=wasLiked?await supabase.from('anime_moment_reactions').delete().eq('moment_id',moment.id).eq('user_id',user.id):await supabase.from('anime_moment_reactions').insert({moment_id:moment.id,user_id:user.id});
  if(result.error){setLiked(prev=>({...prev,[moment.id]:wasLiked}));setMoments(prev=>prev.map(item=>item.id===moment.id?{...item,likes:Math.max(0,item.likes+(wasLiked?1:-1))}:item));setError('Your reaction could not be saved.');}
  setBusyLike(prev=>({...prev,[moment.id]:false}));
 };
 return <section className="page moments-page">
  <div className="moments-heading"><div><span className="eyebrow">STRAW HAT STUDIO · COMMUNITY</span><h1>Anime <em>Moments.</em></h1><p>Little pieces of the stories we love. Shared by the crew.</p></div><Link className="moments-back" to="/community"><ArrowLeft size={16}/> Crew</Link></div>
  <div className="moments-layout">
   <div className="moments-feed-column">
    {loading?<div className="moments-state"><span className="moments-spinner"/><b>Finding moments from the crew…</b></div>:error&&!moments.length?<div className="moments-state"><b>{error}</b><button className="secondary" onClick={load}><RefreshCw size={15}/> Try again</button></div>:moments.length===0?<div className="moments-state"><Compass size={28}/><b>The feed is waiting for its first moment.</b><span>Share original fan art, edits or anime-inspired creations with the crew.</span></div>:<div className="moments-grid">{moments.map(moment=><article className="moment-card" key={moment.id}>
      <div className="moment-media">{moment.media_type==='video'?<video src={moment.mediaUrl} controls playsInline preload="metadata"/>:<img src={moment.mediaUrl} alt={moment.caption||'Community anime moment'} loading="lazy" decoding="async"/>}<span className="moment-type">{moment.media_type==='video'?<Video size={13}/>:<ImageIcon size={13}/>} {moment.media_type}</span></div>
      <div className="moment-card-content"><div className="moment-author"><span className="moment-avatar">{moment.profile?.avatar_url?<img src={moment.profile.avatar_url} alt=""/>:(moment.profile?.username||'C').slice(0,1).toUpperCase()}</span><span><b>{moment.profile?.username||'Crew member'}</b><small>{formatDate(moment.published_at||moment.created_at)}</small></span></div>{moment.caption&&<p>{moment.caption}</p>}<button className={liked[moment.id]?'moment-like is-liked':'moment-like'} onClick={()=>toggleLike(moment)} disabled={!!busyLike[moment.id]} aria-label={liked[moment.id]?'Unlike moment':'Like moment'}><Heart size={17} fill={liked[moment.id]?'currentColor':'none'}/><span>{moment.likes}</span></button></div>
     </article>)}</div>}
    {error&&moments.length>0&&<p className="moments-inline-error">{error}</p>}
   </div>
   <aside className="moments-side">
    <form className="moment-compose" onSubmit={submit}><span className="eyebrow">SHARE WITH THE CREW</span><h2>Post a moment</h2><p>Upload original artwork, fan edits or media you have permission to share. New submissions are reviewed before appearing publicly.</p>
     <label className="moment-upload" htmlFor="anime-moment-file"><Upload size={19}/><b>{selectedFile?selectedFile.name:'Choose image or video'}</b><small>JPG, PNG, WebP, GIF, MP4 or WebM · Max 20 MB</small></label>
     <input id="anime-moment-file" type="file" accept="image/jpeg,image/png,image/webp,image/gif,video/mp4,video/webm" onChange={event=>chooseFile(event.target.files?.[0])}/>
     <label className="moment-caption-label" htmlFor="anime-moment-caption">Caption</label><textarea id="anime-moment-caption" rows="3" maxLength="500" value={caption} onChange={event=>setCaption(event.target.value)} placeholder="What makes this moment special?"/>
     <div className="moment-compose-footer"><small>{caption.length}/500</small><button className="primary" type="submit" disabled={uploading||!user||!selectedFile}>{uploading?'Uploading…':<><Plus size={16}/> Submit moment</>}</button></div>
     {!user&&<small className="moment-signin-note">Sign in to upload and react to moments.</small>}
    </form>
    {user&&pending.length>0&&<div className="moment-pending"><span className="eyebrow">{isAdmin?'CREW MODERATION':'YOUR SUBMISSIONS'}</span><h3>{isAdmin?'Review queue':'Awaiting review'}</h3>{pending.map(item=><div className="moment-pending-item" key={item.id}>{item.media_type==='video'?<video src={item.mediaUrl} muted playsInline preload="metadata"/>:<img src={item.mediaUrl} alt="Pending submission"/>}<span>{item.caption||'Untitled moment'}<small>{formatDate(item.created_at)}</small></span>{isAdmin?<span className="moment-moderation-actions"><button className="primary" disabled={!!moderating[item.id]} onClick={()=>moderate(item,'published')}>Approve</button><button className="secondary" disabled={!!moderating[item.id]} onClick={()=>moderate(item,'removed')}>Remove</button></span>:<b>Pending</b>}</div>)}</div>}
    <div className="moment-guidelines"><b>Keep the seas welcoming.</b><p>Share content you own or have permission to distribute. No episode uploads, pirated clips, harassment or harmful material.</p></div>
   </aside>
  </div>
 </section>;
}
