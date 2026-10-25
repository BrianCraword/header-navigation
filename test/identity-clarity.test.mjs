import { test } from 'node:test';
import assert from 'node:assert/strict';
import { identityClarityRows } from '../javascripts/discourse/lib/je-nav-identity-clarity.js';
const user = {username_lower:'member'};
const labels = {community_profile:'Community profile',badge_catalog:'Badge catalog',activity:'Activity',drafts:'Drafts',my_badges:'My badges'};
test('legacy settings are immutable; only exact known labels change, additions follow existing order',()=>{
 const rows = [{label:'My Profile',href:'/my/summary',order:4},{label:'Badges',href:'/badges'},{label:'My dating profile',href:'/matchmaking/profile'}];
 const original=JSON.stringify(rows); const out=identityClarityRows(rows,user,labels);
 assert.equal(JSON.stringify(rows),original);
 assert.deepEqual(out.map(r=>r.label),['Community profile','Badge catalog','My dating profile','Activity','Drafts','My badges']);
 assert.deepEqual(out.slice(0,3).map(r=>r.href),rows.map(r=>r.href));
});
test('custom labels and another user profile are untouched',()=>{
 const rows=[{label:'My corner',href:'/my/summary'},{label:'My Profile',href:'/u/another/summary'},{label:'Achievements',href:'/badges'}];
 assert.deepEqual(identityClarityRows(rows,user,labels).slice(0,3),rows);
});
test('restricted configured destinations suppress automatic copies before visibility filtering',()=>{
 const rows=[{label:'Work in progress',href:'/my/activity/drafts',show_when:'staff'},{label:'Journal',href:'/u/member/activity/'},{label:'Earned',href:'/my/badges'}];
 const out=identityClarityRows(rows,user,labels); assert.deepEqual(out,rows); assert.equal(out[0].show_when,'staff');
});
test('guests receive no synthesized personal links',()=>{
 const rows=[]; assert.equal(identityClarityRows(rows,null,labels),rows);
});
test('repeat projection is idempotent',()=>{
 const once=identityClarityRows([],user,labels); assert.deepEqual(identityClarityRows(once,user,labels),once);
});

test('same-site route aliases retain configured restrictions without synthesized copies',()=>{
 for (const href of ['/my/activity?filter=all','/my/activity#latest','/u/Member/activity/', 'https://community.example/u/MEMBER/activity?filter=all', '//community.example/my/activity']) {
  const row={label:'Custom activity',href,show_when:'staff'};
  const out=identityClarityRows([row],user,labels,'https://community.example');
  assert.equal(out.filter(r=>r.label==='Activity').length,0,href);
  assert.equal(out[0],row);
 }
});
test('external and other-user links do not suppress own personal destinations',()=>{
 for(const href of ['https://external.example/my/activity','/u/another/activity','not a URL://']) {
  const out=identityClarityRows([{label:'Elsewhere',href}],user,labels,'https://community.example');
  assert.equal(out.filter(r=>r.href==='/my/activity').length,1,href);
 }
});
