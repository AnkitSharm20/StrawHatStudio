import React,{useEffect,useState}from'react';
import{useParams,useNavigate}from'react-router-dom';
import{ArrowLeft,Users,MessageCircle,Calendar,UserPlus,UserCheck}from'lucide-react';
import{supabase}from'./lib/supabase.js';

export default function PublicProfile({user,notify}){
 const{username:routeUsername}=useParams(),navigate=useNavigate();
 const[profile,setProfile]=useState(null),[stats,setStats]=useState({posts:0,replies:0,followers:0,following:0});
 const[posts,setPosts]=useState([]),[watchlist,setWatchlist]=useState([]),[tab,setTab]=useState('posts'),[busy,setBusy]=useState(false),[following,setFollowing]=useState(false);
 const[list,setList]=useState(''),[members,setMembers]=useState([]),[loading,setLoading]=useState(true),[error,setError]=useState('');
 useEffect(()=>{let active=true;(async()=>{
  setLoading(true);setError('');setProfile(null);
  if(!supabase){setError('The profile service is unavailable.');setLoading(false);return}
  const name=decodeURIComponent(routeUsername||'').trim().toLowerCase();
  if(!/^[a-z0-9_]{3,24}$/.test(name)){setError('This profile address is not valid.');setLoading(false);return}
  const{data:p,error:e}=await supabase.from('profiles').select('id,username,avatar_url,banner_url,bio,created_at,favorite_anime,favorite_characters,favorite_genres,is_public,show_watchlist').eq('username',name).maybeSingle();
  if(!active)return;
  if(e){setError(e.message);setLoading(false);return}
  if(!p){setError('This crew member could not be found.');setLoading(false);return}
  setProfile(p);
  const[postCount,replyCount,followerCount,followingCount,postRows,followRow]=await Promise.all([
   supabase.from('community_posts').select('id',{count:'exact',head:true}).eq('author_id',p.id).eq('status','published'),
   supabase.from('community_replies').select('id',{count:'exact',head:true}).eq('author_id',p.id).eq('status','published'),
   supabase.from('community_follows').select('follower_id',{count:'exact',head:true}).eq('followed_id',p.id),
   supabase.from('community_follows').select('followed_id',{count:'exact',head:true}).eq('follower_id',p.id),
   supabase.from('community_posts').select('id,body,created_at,spoiler').eq('author_id',p.id).eq('status','published').order('created_at',{ascending:false}).limit(30),
   user?.id&&user.id!==p.id?supabase.from('community_follows').select('follower_id').eq('follower_id',user.id).eq('followed_id',p.id).maybeSingle():Promise.resolve({data:null})
  ]);
  if(!active)return;
  setStats({posts:postCount.count||0,replies:replyCount.count||0,followers:followerCount.count||0,following:followingCount.count||0});
  setPosts(postRows.data||[]);setFollowing(!!followRow.data);setLoading(false);
 })();return()=>{active=false}},[routeUsername,user?.id]);
 const toggleFollow=async()=>{if(!user){notify('Sign in with Discord to follow crew members.');return}if(!profile||busy)return;setBusy(true);
  const result=following?await supabase.from('community_follows').delete().eq('follower_id',user.id).eq('followed_id',profile.id):await supabase.from('community_follows').insert({follower_id:user.id,followed_id:profile.id});
  setBusy(false);if(result.error){notify(result.error.message);return}setFollowing(!following);setStats(v=>({...v,followers:Math.max(0,v.followers+(following?-1:1))}));notify(following?'Unfollowed member':'Following member');
 };
 const openList=async kind=>{if(list===kind){setList('');return}setList(kind);setMembers([]);
  const field=kind==='followers'?'follower_id':'followed_id',filter=kind==='followers'?'followed_id':'follower_id';
  const{data,error:e}=await supabase.from('community_follows').select(field).eq(filter,profile.id).order('created_at',{ascending:false}).limit(100);
  if(e){notify('Could not load '+kind+': '+e.message);return}
  const ids=(data||[]).map(x=>x[field]);if(!ids.length)return;
  const{data:rows,error:pe}=await supabase.from('profiles').select('id,username,avatar_url').in('id',ids);
  if(pe){notify('Could not load member profiles.');return}
  const map=Object.fromEntries((rows||[]).map(x=>[x.id,x]));setMembers(ids.map(id=>map[id]).filter(Boolean));
 };
 if(loading)return <div className="page"><p className="empty">Loading crew profile…</p></div>;
 if(error||!profile)return <div className="page public-profile-page"><button className="secondary" onClick={()=>navigate(-1)}><ArrowLeft size={15}/> Go back</button><div className="empty"><b>Profile unavailable</b><span>{error||'This member may have changed their username.'}</span></div></div>;
 const avatar=profile.avatar_url;
 return <div className="page public-profile-page">
  <button className="text-btn" onClick={()=>navigate('/community')}><ArrowLeft size={15}/> Back to community</button>
  <div className="profile-cover public-profile-cover" style={profile.banner_url?{backgroundImage:'linear-gradient(90deg,#07131d66,#07131d22),url("'+profile.banner_url+'")'}:undefined}><div className="profile-avatar">{avatar?<img src={avatar} alt="" style={{width:'100%',height:'100%',borderRadius:'50%',objectFit:'cover'}}/>:(profile.username||'N').slice(0,1).toUpperCase()}</div></div>
  <div className="profile-row"><div><h2>{profile.username}</h2><p>CREW MEMBER · JOINED {new Date(profile.created_at).toLocaleDateString(undefined,{month:'long',year:'numeric'})}</p></div>{user?.id!==profile.id&&<button className="primary" onClick={toggleFollow} disabled={busy}>{following?<UserCheck size={15}/>:<UserPlus size={15}/>} {busy?'Please wait…':following?'Following':'Follow'}</button>}</div>
  <section className="profile-about"><span className="eyebrow">ABOUT THIS MEMBER</span><p>{profile.bio||'This crew member has not added a bio yet.'}</p></section>{(profile.favorite_anime?.length>0||profile.favorite_characters?.length>0||profile.favorite_genres?.length>0)&&<section className="profile-about"><span className="eyebrow">THE CAPTAIN'S FAVOURITES</span>{profile.favorite_anime?.length>0&&<p><b>Anime</b> · {profile.favorite_anime.join(' · ')}</p>}{profile.favorite_characters?.length>0&&<p><b>Characters</b> · {profile.favorite_characters.join(' · ')}</p>}{profile.favorite_genres?.length>0&&<p><b>Genres</b> · {profile.favorite_genres.join(' · ')}</p>}</section>}
  <div className="public-profile-stats">
   <div><b>{stats.posts}</b><span>POSTS</span></div><div><b>{stats.replies}</b><span>REPLIES</span></div>
   <button onClick={()=>openList('followers')}><b>{stats.followers}</b><span>FOLLOWERS</span></button>
   <button onClick={()=>openList('following')}><b>{stats.following}</b><span>FOLLOWING</span></button>
  </div>
  {list&&<section className="public-follow-list"><div className="public-follow-head"><b>{list==='followers'?'Followers':'Following'}</b><button className="text-btn" onClick={()=>setList('')}>Close</button></div>{members.length?members.map(m=><button className="public-follow-member" key={m.id} onClick={()=>navigate('/u/'+encodeURIComponent(m.username||''))}><span className="avatar alt">{m.avatar_url?<img src={m.avatar_url} alt=""/>:(m.username||'N')[0].toUpperCase()}</span><b>{m.username||'Crew member'}</b></button>):<p className="empty">No members to show yet.</p>}</section>}
  <div className="public-profile-tabs"><button className={tab==='posts'?'active':''} onClick={()=>setTab('posts')}>Posts</button><button className={tab==='replies'?'active':''} onClick={()=>setTab('replies')}>Replies</button></div>
  {tab==='posts'?posts.length?<div className="feed">{posts.map(p=><article className="post" key={p.id}><small>{new Date(p.created_at).toLocaleString()}{p.spoiler?' · SPOILER':''}</small><p style={{whiteSpace:'pre-wrap'}}>{p.body}</p></article>)}</div>:<p className="empty">No published posts yet.</p>:<ProfileReplies userId={profile.id}/>}
 </div>;
}
function ProfileReplies({userId}){const[items,setItems]=useState([]),[loading,setLoading]=useState(true);useEffect(()=>{let active=true;supabase.from('community_replies').select('id,body,created_at').eq('author_id',userId).eq('status','published').order('created_at',{ascending:false}).limit(30).then(({data})=>{if(active){setItems(data||[]);setLoading(false)}});return()=>{active=false}},[userId]);if(loading)return <p className="empty">Loading replies…</p>;return items.length?<div className="feed">{items.map(r=><article className="post" key={r.id}><small>{new Date(r.created_at).toLocaleString()}</small><p style={{whiteSpace:'pre-wrap'}}>{r.body}</p></article>)}</div>:<p className="empty">No published replies yet.</p>}
