const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../javascripts/discourse/components/je-nav-mobile/je-nav-mobile.gjs'),'utf8');
const start=source.indexOf('  _suppressActive() {')+'  _suppressActive() {'.length;
const end=source.indexOf('\n  _applyMobileMode()',start);
const body=source.slice(start,end).trim().replace(/}$/, '');
const evaluate=new Function('document',`return function(){${body}}`);
function suppressed(sharedMode,classes=[],fullscreen=false,configured=[]) {
 const doc={body:{classList:{contains:n=>classes.includes(n)}},documentElement:{classList:{contains:()=>false}},fullscreenElement:fullscreen?{}:null};
 return evaluate(doc).call({sharedMode,suppressClasses:configured});
}
test('shared mode leaves native overlays and composer in control of bottom edge',()=>{
 for(const name of ['composer-open','has-ai-bot-docked-composer','ai-bot-conversations-page','modal-open','has-full-page-chat','chat-page','fullscreen-composer']) assert.equal(suppressed(true,[name]),true,name);
 assert.equal(suppressed(true,[],true),true);
 assert.equal(suppressed(true),false);
});
test('legacy occupancy continues to use only existing configured rules',()=>{
 assert.equal(suppressed(false,['modal-open']),false);
 assert.equal(suppressed(false,['modal-open'],false,['modal-open']),true);
});
