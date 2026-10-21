import {randomBytes} from 'node:crypto';
import {db,admin,checked,validate,eventDefaults,confirmation,wishEmail,publicParticipant} from '../../../lib/server';
import {generateMatches} from '../../../lib/matching.mjs';
export const runtime='nodejs';
const response=(x,status=200)=>Response.json(x,{status,headers:{'Cache-Control':'no-store'}});
async function handle(req,{params}){try{
 const {path}=await params;const action=path.join('/');
 if(action==='event'&&req.method==='GET'){if(!process.env.NEXT_PUBLIC_SUPABASE_URL)return response({event:eventDefaults,configured:false});const e=checked(await db().from('events').select('*').limit(1).single());return response({event:e,configured:true});}
 if(action==='config')return response({url:process.env.NEXT_PUBLIC_SUPABASE_URL||'',key:process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||''});
 const database=db();
 const event=checked(await database.from('events').select('*').limit(1).single());
 if(action==='register'&&req.method==='POST'){
 const values=validate(await req.json());const token=randomBytes(32).toString('hex');
 const p=checked(await database.rpc('register_participant',{payload:{...values,event_id:event.id,edit_token:token}}));
 let emailSent=true;try{await confirmation(p,event);}catch{emailSent=false;}
 return response({token,emailSent},201);
 }
 if(path[0]==='edit'&&/^[a-f0-9]{64}$/.test(path[1]||'')){
 const p=checked(await database.from('participants').select('*').eq('edit_token',path[1]).single());
 if(req.method==='GET')return response({participant:publicParticipant(p),locked:event.matching_status!=='not_started'});
 if(req.method==='PUT'){const values=validate(await req.json());checked(await database.rpc('edit_participant',{token:path[1],payload:values}));return response({ok:true});}
 }
 await admin(req);
 if(action==='admin/data'&&req.method==='GET'){
 const participants=checked(await database.from('participants').select('*').eq('event_id',event.id).order('created_at'));
 const matches=checked(await database.from('gift_matches').select('*').eq('event_id',event.id));
 return response({event,participants:participants.map(publicParticipant),matches});
 }
 if(action==='admin/generate'&&req.method==='POST'){
 const participants=checked(await database.from('participants').select('id,wish_1').eq('event_id',event.id).eq('join_gift_exchange',true));
 if(participants.some(p=>!p.wish_1?.trim()))throw new Error('Please complete all wishlists before generating.');
 const restrictions=checked(await database.from('match_restrictions').select('*').eq('event_id',event.id));
 const matches=generateMatches(participants,restrictions);checked(await database.rpc('save_matches',{target_event:event.id,pairs:matches}));return response({count:matches.length});
 }
 if(action==='admin/send'&&req.method==='POST'){
 const participants=checked(await database.from('participants').select('*').eq('event_id',event.id));
 const matches=checked(await database.from('gift_matches').select('*').eq('event_id',event.id).neq('notification_status','sent'));
 let sent=0,failed=0;for(const m of matches){try{await wishEmail(participants.find(p=>p.id===m.giver_id),participants.find(p=>p.id===m.receiver_id),event,m.id);checked(await database.from('gift_matches').update({notification_status:'sent',notification_sent_at:new Date().toISOString()}).eq('id',m.id));sent++;}catch{checked(await database.from('gift_matches').update({notification_status:'failed'}).eq('id',m.id));failed++;}}return response({sent,failed});
 }
 return response({error:'Not found'},404);
 }catch(e){const unauthorized=e.message==='Unauthorized';return response({error:unauthorized?'Please sign in as the organizer.':e.message},unauthorized?401:400);}}
export const GET=handle;export const POST=handle;export const PUT=handle;
