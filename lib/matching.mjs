import {randomInt} from 'node:crypto';
export function generateMatches(participants, restrictions = []) {
 if(participants.length<2) throw new Error('Secret Wish requires at least two participants.');
 if(new Set(participants.map(p=>p.id)).size!==participants.length) throw new Error('Duplicate participants.');
 for(let attempt=0;attempt<1000;attempt++){
  const order=[...participants];
  for(let i=order.length-1;i>0;i--){const j=randomInt(i+1);[order[i],order[j]]=[order[j],order[i]];}
  const matches=order.map((p,i)=>({giver_id:p.id,receiver_id:order[(i+1)%order.length].id}));
  if(!matches.some(m=>restrictions.some(r=>(r.participant_a===m.giver_id&&r.participant_b===m.receiver_id)||(r.participant_b===m.giver_id&&r.participant_a===m.receiver_id))))return matches;
 }
 throw new Error('Unable to generate a valid match. Please review match restrictions.');
}
