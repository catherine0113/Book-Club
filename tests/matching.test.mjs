import test from 'node:test';
import assert from 'node:assert/strict';
import {generateMatches} from '../lib/matching.mjs';
test('circular shuffle gives and receives exactly once, never self',()=>{for(let n=2;n<60;n++){const p=Array.from({length:n},(_,id)=>({id}));const matches=generateMatches(p);assert.equal(matches.length,n);assert.equal(new Set(matches.map(m=>m.giver_id)).size,n);assert.equal(new Set(matches.map(m=>m.receiver_id)).size,n);assert(matches.every(m=>m.giver_id!==m.receiver_id));}});
test('rejects fewer than two people and duplicate IDs',()=>{assert.throws(()=>generateMatches([]));assert.throws(()=>generateMatches([{id:1}]));assert.throws(()=>generateMatches([{id:1},{id:1}]));});
test('honors bidirectional restrictions',()=>{for(let i=0;i<30;i++){const matches=generateMatches([0,1,2,3].map(id=>({id})),[{participant_a:0,participant_b:1}]);assert(!matches.some(m=>(m.giver_id===0&&m.receiver_id===1)||(m.giver_id===1&&m.receiver_id===0)));}});
test('impossible restrictions terminate with useful error',()=>{assert.throws(()=>generateMatches([{id:0},{id:1}],[{participant_a:0,participant_b:1}]),/Unable to generate/);});
