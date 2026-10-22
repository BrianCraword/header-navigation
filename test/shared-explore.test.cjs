const assert = require('node:assert/strict');
const { test } = require('node:test');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
const core = () => import(pathToFileURL(path.join(__dirname,'../javascripts/discourse/lib/je-nav-core.js')));
const member = {id:7,username_lower:'member',groups:[{name:'mm_onboarding'}]};
const rows = [
 {label:'Feed',href:'/feed',surface:'both'},
 {label:'Discussions',type:'dropdown',children:[{label:'Latest',href:'/latest',subtext:'Recent discussions',icon:'comments',badge:'NEW',section:'Browse'}]},
 {label:'Word',type:'dropdown',children:[{label:'Scripture',href:'/scripture-campaign'}]},
 {label:'Matchmaking',type:'dropdown',children:[{label:'Continue',href:'/matchmaking',visible_groups:'mm_onboarding'},{label:'Matches',href:'/matchmaking/matches',visible_groups:'mm_participants'}]},
 {label:'Staff',type:'dropdown',show_when:'staff',children:[{label:'Admin',href:'/admin'}]},
 {label:'AI Guides',type:'dropdown',children:[{label:'Omega',href:'/discourse-ai/ai-bot/conversations?agent=omega'}]},
 {label:'Messages',href:'/my/messages',surface:'mobile',badge_source:'unread_messages'}
];
test('shared mobile is stable Feed Explore AI Messages; no settings mutation',async()=>{
 const {sharedProjection}=await core(); const before=JSON.stringify(rows);
 const result=sharedProjection({destinations:rows,currentUser:member,surface:'mobile'});
 assert.deepEqual(result.primary.map(r=>r.label),['Feed','Explore','AI','Messages']);
 assert.ok(result.primary.every(r=>r.mobile_pinned && !r.emphasis));
 assert.equal(JSON.stringify(rows),before);
});
test('desktop retains convenience groups but never widens Messages surface',async()=>{
 const {sharedProjection}=await core();
 const result=sharedProjection({destinations:rows,currentUser:member,surface:'desktop'});
 assert.deepEqual(result.primary.map(r=>r.label),['Feed','Explore','Discussions','Word','Matchmaking','AI Conversations']);
 assert.equal(result.explore.children.some(r=>r.href==='/my/messages'),false);
});
test('full Explore preserves metadata, gates and all permitted rows',async()=>{
 const {sharedProjection}=await core();
 const result=sharedProjection({destinations:rows,currentUser:member,surface:'mobile'});
 assert.equal(result.explore.children.some(r=>r.href==='/admin'),false);
 assert.equal(result.explore.children.some(r=>r.href==='/matchmaking/matches'),false);
 assert.ok(result.explore.children.some(r=>r.href==='/matchmaking'));
 const latest=result.explore.children.find(r=>r.href==='/latest');
 assert.equal(latest.subtext,'Recent discussions');assert.equal(latest.icon,'comments');assert.equal(latest.badge,'NEW');assert.equal(latest.subsection,'Browse');
});
test('parent inclusion and exclusion survive promotion and grouping',async()=>{
 const {sharedProjection}=await core();
 for(const gate of [{visible_groups:'mm_participants'},{hidden_groups:'mm_onboarding'}]){
  const restricted=rows.map(r=>r.label==='AI Guides'?{...r,...gate}:r);
  const result=sharedProjection({destinations:restricted,currentUser:member,surface:'mobile'});
  assert.equal(result.primary.some(r=>r.label==='AI'),false);
  assert.equal(result.explore.children.some(r=>r.href.includes('conversations')),false);
 }
});
test('desktop-only feed and AI never promoted to mobile',async()=>{
 const {sharedProjection}=await core();
 const restricted=rows.map(r=>['Feed','AI Guides'].includes(r.label)?{...r,surface:'desktop'}:r);
 const result=sharedProjection({destinations:restricted,currentUser:member,surface:'mobile'});
 assert.deepEqual(result.primary.map(r=>r.label),['Explore','Messages']);
});
test('participant direct matches retain their own gate and staff remains separate',async()=>{
 const {sharedProjection}=await core();
 const user={...member,groups:[{name:'mm_participants'}]};
 const result=sharedProjection({destinations:rows,currentUser:user,surface:'mobile'});
 assert.ok(result.explore.children.some(r=>r.href==='/matchmaking/matches'));
 assert.equal(result.explore.children.some(r=>r.href==='/admin'),false);
});

test('normalized Feed and Messages links remain reachable',async()=>{
 const {sharedProjection}=await core();
 for(const suffix of ['/', '?x=1', '#section']) {
  const destinations=[{label:'Feed',href:'/feed'+suffix},{label:'Messages',href:'/my/messages'+suffix}];
  assert.deepEqual(sharedProjection({destinations,currentUser:member,surface:'mobile'}).primary.map(r=>r.href),destinations.map(r=>r.href));
 }
});
test('Explore selects Community but yields to direct destinations and AI topics',async()=>{
 const {sharedProjection,sharedExploreSelected}=await core();
 const destinations=[...rows,{label:'Community',type:'dropdown',children:[{label:'Badges',href:'/badges'}]}];
 const {primary}=sharedProjection({destinations,currentUser:member,surface:'desktop'});
 assert.equal(sharedExploreSelected(primary,'/badges',member),true);
 assert.equal(sharedExploreSelected(primary,'/latest',member),false);
 assert.equal(sharedExploreSelected(primary,'/feed',member),false);
 assert.equal(sharedExploreSelected(primary,'/badges',member,true),false);
});
