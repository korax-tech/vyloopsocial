const chatStyle=document.createElement('style');chatStyle.textContent=`
.chat-shell{background:#0b1012;border:1px solid #263033;border-radius:22px;overflow:hidden;color:#f4f7f7;min-height:600px}
.chat-head{padding:18px;display:flex;align-items:center;justify-content:space-between;background:#11191b}
.chat-search{margin:14px 16px;width:calc(100% - 32px);padding:14px 18px;border:0;border-radius:30px;background:#20282b;color:white}
.chat-filters{display:flex;gap:8px;overflow:auto;padding:0 16px 14px}
.chat-filters button{white-space:nowrap;border-radius:24px;background:transparent;border-color:#303a3d;color:#bdc7c9;padding:8px 14px}
.chat-filters button.active{background:#263033;color:white}
.chat-item{display:flex;align-items:center;gap:13px;padding:12px;border-radius:14px;cursor:pointer}
.chat-item:hover{background:#182123}.chat-item .avatar{width:54px;height:54px;border:2px solid #25bd78;background:#263b32}
.chat-meta{min-width:0;flex:1}.chat-last{color:#9aa6a8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:4px}
.chat-time{color:#9aa6a8;font-size:12px}.chat-bottom{display:grid;grid-template-columns:repeat(4,1fr);padding:10px 4px;background:#101719;border-top:1px solid #253033}
.chat-bottom button{background:transparent;border:0;color:#c8d0d1;display:grid;gap:4px;justify-items:center}.chat-bottom button.active{color:#36d58b}
.chat-thread{background:#0b1516;border-radius:20px;overflow:hidden;min-height:570px}.thread-top{padding:14px;background:#172123;display:flex;align-items:center;gap:12px}
.thread-body{padding:18px;min-height:390px;background:#0d1718}.bubble{max-width:78%;padding:10px 14px;border-radius:14px;background:#202b2d;margin:9px 0;white-space:pre-wrap;overflow-wrap:anywhere}.bubble.mine{margin-left:auto;background:#075e48}
.thread-compose{display:flex;gap:8px;padding:12px;background:#172123}.thread-compose input{flex:1;min-width:0;border-radius:24px;background:#263235;border:0;color:white;padding:13px}
`;document.head.appendChild(chatStyle);
let chatFilterNow='All',activeChatId=null;
async function renderWhatsApp(v){
v.innerHTML='<section class="chat-shell"><div class="chat-head"><div><h2 style="margin:0">Chats</h2><small style="color:#9aa6a8">Your conversations</small></div><div><button onclick="go(\'discover\')">＋</button><button onclick="chatOverflow()">⋮</button></div></div><input id="chatSearchBox" class="chat-search" placeholder="⌕  Search..."><div class="chat-filters" id="chatFilterRow">'+['All','Unread','Favorites','Groups','Archived'].map(x=>'<button class="'+(x===chatFilterNow?'active':'')+'" onclick="chooseChatFilter(\''+x+'\')">'+x+'</button>').join('')+'</div><div id="chatRows" style="padding:0 8px 18px"><p style="padding:20px;color:#9aa6a8">Loading chats…</p></div><div class="chat-bottom"><button class="active" onclick="chatTab(this,\'Chats\')">▤<b>Chats</b></button><button onclick="chatTab(this,\'Calls\')">☎<b>Calls</b></button><button onclick="chatTab(this,\'Updates\')">◉<b>Updates</b></button><button onclick="chatTab(this,\'Tools\')">▣<b>Tools</b></button></div></section>';
document.getElementById('chatSearchBox').oninput=loadWhatsAppChats;await loadWhatsAppChats();
}
function chooseChatFilter(x){chatFilterNow=x;document.querySelectorAll('#chatFilterRow button').forEach(b=>b.classList.toggle('active',b.textContent===x));loadWhatsAppChats()}
function chatTab(b,n){document.querySelectorAll('.chat-bottom button').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(n!=='Chats')notice(n+' will be enabled as its module is built.')}
function chatOverflow(){const x=prompt('Type "new" to find people, or "archived" to view archived chats.');if(x?.toLowerCase()==='new')go('discover');else if(x?.toLowerCase()==='archived')notice('Chat archiving will be added with chat settings.')}
async function loadWhatsAppChats(){
const list=document.getElementById('chatRows');if(!list)return;
const {data:mine,error}=await db.from('conversation_members').select('conversation_id').eq('user_id',user.id);
if(error){list.textContent=error.message;return}
const ids=(mine||[]).map(x=>x.conversation_id);
if(!ids.length){list.innerHTML='<div style="padding:30px;text-align:center;color:#9aa6a8">No chats yet.<p>Find someone and tap Message to start a conversation.</p><button onclick="go(\'discover\')">Find people</button></div>';return}
const {data:convs,error:ce}=await db.from('conversations').select('*').in('id',ids).order('updated_at',{ascending:false});
if(ce){list.textContent=ce.message;return}
const {data:members}=await db.from('conversation_members').select('conversation_id,user_id').in('conversation_id',ids);
const others=(members||[]).filter(x=>x.user_id!==user.id),uids=[...new Set(others.map(x=>x.user_id))];
const {data:profiles}=uids.length?await db.from('profiles').select('id,username,display_name,avatar_url').in('id',uids):{data:[]};
const pm=Object.fromEntries((profiles||[]).map(x=>[x.id,x]));let rows=[];
for(const cv of convs||[]){const other=others.find(x=>x.conversation_id===cv.id),p=pm[other?.user_id]||{display_name:cv.title||'Group chat'};const {data:m}=await db.from('messages').select('body,created_at,sender_id').eq('conversation_id',cv.id).is('deleted_at',null).order('created_at',{ascending:false}).limit(1).maybeSingle();rows.push({cv,p,m})}
const q=(document.getElementById('chatSearchBox')?.value||'').toLowerCase();
rows=rows.filter(x=>(x.p.display_name+' '+x.p.username+' '+(x.m?.body||'')).toLowerCase().includes(q));
if(chatFilterNow==='Groups')rows=rows.filter(x=>x.cv.is_group);
list.innerHTML=rows.map(x=>'<div class="chat-item" onclick="openWhatsAppThread(\''+x.cv.id+'\')">'+avatar(x.p)+'<div class="chat-meta"><div style="display:flex;justify-content:space-between;gap:8px"><b>'+esc(x.cv.is_group?(x.cv.title||'Group chat'):x.p.display_name)+'</b><span class="chat-time">'+(x.m?new Date(x.m.created_at).toLocaleDateString():'')+'</span></div><div class="chat-last">'+(x.m?.sender_id===user.id?'You: ':'')+esc(x.m?.body||'Start a conversation')+'</div></div></div>').join('')||'<p style="padding:24px;color:#9aa6a8">No matching chats.</p>';
}
async function openWhatsAppThread(id){
activeChatId=id;const v=document.getElementById('view');
v.innerHTML='<section class="chat-thread"><div class="thread-top"><button onclick="go(\'messages\')">←</button><div id="threadAvatar" class="avatar">V</div><b id="threadName">Chat</b><button style="margin-left:auto" onclick="chatOverflow()">⋮</button></div><div id="threadMessages" class="thread-body">Loading…</div><form id="threadSend" class="thread-compose"><input id="threadText" placeholder="Message" autocomplete="off"><button class="primary">➤</button></form></section>';
const {data:mem}=await db.from('conversation_members').select('user_id').eq('conversation_id',id).neq('user_id',user.id).limit(1).maybeSingle();
if(mem){const {data:p}=await db.from('profiles').select('*').eq('id',mem.user_id).maybeSingle();if(p){document.getElementById('threadName').textContent=p.display_name||p.username;document.getElementById('threadAvatar').innerHTML=avatar(p)}}
await loadWhatsAppMessages();
document.getElementById('threadSend').onsubmit=async e=>{e.preventDefault();const body=document.getElementById('threadText').value.trim();if(!body)return;const {error}=await db.from('messages').insert({conversation_id:id,sender_id:user.id,body});if(error)notice(error.message);else{document.getElementById('threadText').value='';await loadWhatsAppMessages()}};
}
async function loadWhatsAppMessages(){const {data,error}=await db.from('messages').select('*').eq('conversation_id',activeChatId).is('deleted_at',null).order('created_at',{ascending:true}).limit(200);const b=document.getElementById('threadMessages');if(!b)return;if(error){b.textContent=error.message;return}b.innerHTML=(data||[]).map(m=>'<div class="bubble '+(m.sender_id===user.id?'mine':'')+'">'+esc(m.body||'')+'</div>').join('')||'<p style="text-align:center;color:#9aa6a8">Say hello 👋</p>';b.scrollTop=b.scrollHeight;}
