import {test} from 'node:test';
import assert from 'node:assert/strict';
import {personalRoute, withInvitations, youSections} from '../javascripts/discourse/lib/je-nav-you-model.js';
const origin='https://community.example';
const user={username_lower:'member',can_invite_to_forum:true,draft_count:3};
const labels={activity:'Your activity',profiles:'Your profiles',account:'Account',links:'Your links'};
test('invitation management uses native permission and preserves hidden configured aliases',()=>{
 assert.equal(withInvitations([],{},'Invitations',origin).length,0);
 assert.equal(withInvitations([],null,'Invitations',origin).length,0);
 for(const href of ['/my/invited','/u/Member/invited/','https://community.example/my/invited?filter=pending']) {
  const rows=[{href,show_when:'staff',label:'Private invitation list'}];
  assert.equal(withInvitations(rows,user,'Invitations',origin),rows);
 }
 assert.equal(withInvitations([],user,'Invitations',origin)[0].href,'/my/invited');
});
test('grouping preserves all custom links, labels and relative order without mutation',()=>{
 const rows=[{href:'/custom',label:'First'},{href:'/my/activity/drafts',label:'Work in progress'},{href:'https://other.example/my/activity',label:'External'},{href:'/my/summary',label:'My corner'},{href:'/other',label:'Last'}];
 const before=JSON.stringify(rows); const groups=youSections(rows,user,labels,origin);
 assert.equal(JSON.stringify(rows),before);
 assert.deepEqual(groups.find(g=>g.key==='links').rows.map(r=>r.label),['First','External','Last']);
 assert.equal(groups.find(g=>g.key==='activity').rows[0].draftCount,3);
 assert.equal(groups.find(g=>g.key==='profiles').rows[0].label,'My corner');
 assert.equal(groups.reduce((n,g)=>n+g.rows.length,0),rows.length);
});
test('draft count is absent for zero, invalid, other user or unrelated routes',()=>{
 for(const value of [0,-1,NaN,'3',1.5]) assert.equal(youSections([{href:'/my/activity/drafts'}],{...user,draft_count:value},labels,origin)[0].rows[0].draftCount,null);
 assert.equal(personalRoute('/u/another/activity/drafts',user,origin),'/u/another/activity/drafts');
 const out=youSections([{href:'/my/messages'},{href:'/chat'}],user,labels,origin);
 assert.equal(out.flatMap(s=>s.rows).every(r=>r.draftCount===null),true);
 assert.equal(out.find(s=>s.key==='links').rows[0].href,'/chat');
});
