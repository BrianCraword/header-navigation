const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../javascripts/discourse/components/je-nav-mobile/je-nav-mobile.gjs'),'utf8');
const start=source.indexOf('  _suppressActive() {')+'  _suppressActive() {'.length;
const end=source.indexOf('\n  _applyMobileMode()',start);
const body=source.slice(start,end).trim().replace(/}$/, '');
const evaluate=new Function('document',`return function(){${body}}`);
function suppressed(sharedMode,classes=[],fullscreen=false,configured=[],coordinated=false,keyboard=false) {
 const doc={body:{classList:{contains:n=>classes.includes(n)}},documentElement:{classList:{contains:()=>false}},fullscreenElement:fullscreen?{}:null};
 return evaluate(doc).call({sharedMode,suppressClasses:configured,aiBottomCoordinated:coordinated,aiKeyboardOpen:keyboard});
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

test('compatible AI exempts only its two route suppressors',()=>{
 for(const name of ['has-ai-bot-docked-composer','ai-bot-conversations-page']) {
  assert.equal(suppressed(true,[name],false,[name],true),false);
  assert.equal(suppressed(true,[name],false,[name],false),true);
 }
 for(const name of ['composer-open','modal-open','has-full-page-chat','chat-page','fullscreen-composer','custom-overlay','vcai-history--drawer-open','vcai-memory--open']) {
  assert.equal(suppressed(true,[name],false,['custom-overlay'],true),true,name);
 }
 assert.equal(suppressed(true,[],true,[],true),true);
 assert.equal(suppressed(true,[],false,[],true,true),true);
 assert.equal(suppressed(true,[],false,[],true,false),false);
});

test('paired handshake requires enabled mobile owner and admitted AI; no suppression recursion',()=>{
 const getBody=name=>source.slice(source.indexOf(`  get ${name}() {`)+`  get ${name}() {`.length,source.indexOf('\n  }',source.indexOf(`  get ${name}() {`)));
 const classes=new Set(['vcai-navigation-ready','vcai-mobile-nav-v1','has-ai-bot-docked-composer']);
 const doc={body:{classList:{contains:n=>classes.has(n)}},documentElement:{classList:{contains:()=>false}},fullscreenElement:null,querySelector:()=>null};
 const config={je_nav_ai_bottom_navigation_enabled:true};
 const win={matchMedia:()=>({matches:true}),visualViewport:{scale:1,height:844},innerHeight:844};
 const ctx={sharedMode:true,_mobileMounted:true,showBar:true,_barElement:{isConnected:true},_visibleDestinations:[{shared_explore:true}],suppressClasses:[]};
 Object.defineProperty(ctx,'aiBottomCoordinated',{get:new Function('document','window','settings',`return function(){${getBody('aiBottomCoordinated')}}`)(doc,win,config)});
 Object.defineProperty(ctx,'aiKeyboardOpen',{get:new Function('document','window',`return function(){${getBody('aiKeyboardOpen')}}`)(doc,win)});
 Object.defineProperty(ctx,'_exploreOwned',{get(){throw Error('Handshake must not depend on visibility/suppression');}});
 assert.equal(evaluate(doc).call(ctx),false);
 for(const key of ['sharedMode','_mobileMounted','showBar']) {ctx[key]=false;assert.equal(ctx.aiBottomCoordinated,false,key);ctx[key]=true;}
 config.je_nav_ai_bottom_navigation_enabled=false;assert.equal(evaluate(doc).call(ctx),true);config.je_nav_ai_bottom_navigation_enabled=true;
 classes.delete('vcai-mobile-nav-v1');assert.equal(evaluate(doc).call(ctx),true);classes.add('vcai-mobile-nav-v1');
 win.visualViewport.height=600;assert.equal(evaluate(doc).call(ctx),true);win.visualViewport.height=844;assert.equal(evaluate(doc).call(ctx),false);
 ctx._visibleDestinations=[];assert.equal(ctx.aiBottomCoordinated,false);
});
