import React from 'react';
import{createRoot}from'react-dom/client';
import{BrowserRouter}from'react-router-dom';
import App from'./App.jsx';
import'./styles.css';
import'./studio-upgrade.css';

class RuntimeBoundary extends React.Component{
  constructor(props){super(props);this.state={error:null};}
  static getDerivedStateFromError(error){return{error};}
  componentDidCatch(error,info){console.error('[Straw Hat Studio] render failure',error,info);}
  render(){
    if(this.state.error)return <main style={{minHeight:'100vh',display:'grid',placeItems:'center',padding:24,background:'#070b18',color:'#f4f7ff',fontFamily:'system-ui,sans-serif'}}>
      <section style={{width:'min(560px,100%)',padding:28,border:'1px solid #263a5d',borderRadius:18,background:'#101a30',boxShadow:'0 20px 80px #0008'}}>
        <p style={{letterSpacing:3,color:'#56e7ff',fontSize:11}}>STRAW HAT STUDIO · RECOVERY</p>
        <h1 style={{fontSize:28}}>The page hit an unexpected error.</h1>
        <p style={{color:'#bdc9dc',lineHeight:1.6}}>Your account and saved data have not been intentionally changed. Reload the page to try again. If this keeps happening, share the error details with support.</p>
        <pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere',padding:12,borderRadius:10,background:'#080e1b',color:'#ffb8c4',fontSize:12}}>{String(this.state.error?.message||this.state.error)}</pre>
        <button onClick={()=>window.location.reload()} style={{border:0,borderRadius:10,padding:'12px 18px',background:'#54e4ff',color:'#07101c',fontWeight:800,cursor:'pointer'}}>Reload website</button>
      </section>
    </main>;
    return this.props.children;
  }
}
const root=document.getElementById('root');
if(root)createRoot(root).render(<React.StrictMode><RuntimeBoundary><BrowserRouter><App/></BrowserRouter></RuntimeBoundary></React.StrictMode>);
else document.body.innerHTML='<main style="padding:32px;color:white;background:#070b18;min-height:100vh">Straw Hat Studio could not find its app root. Please refresh the page.</main>';
