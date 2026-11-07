import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {modifiedClick} from '../javascripts/discourse/lib/je-nav-you-model.js';
const source=fs.readFileSync(new URL('../javascripts/discourse/components/je-you-panel.gjs',import.meta.url),'utf8');
function fixture(allow=async()=>true) {
 const listeners={}; let replay=0,alerts=0,opened=0;
 const element={open:true,close(){this.open=false;},showModal(){this.open=true;opened++;},querySelector(){return {focus(){}};},addEventListener(k,fn){listeners[k]=fn;},removeEventListener(){}};
 const doc={activeElement:{isConnected:true,focus(){}},addEventListener(k,fn){listeners[k]=fn;},removeEventListener(){}};
 let js=source.split('  <template>')[0].replace(/import[\s\S]*?from\s+"[^"]+";/g,'').replace(/@service\s+\w+;/g,'').replace(/@tracked\s+/g,'').replace(/@action\s*/g,'').replace('export default class','return class')+'}';
 const Type=new Function('Component','navigationAllowed','modifiedClick','document','settings','requestAnimationFrame','getOwner','i18n','themePrefix',js)(class {},allow,modifiedClick,doc,{je_nav_you_enabled:true,je_nav_identity_primary_href:'/custom'},fn=>fn(),()=>({lookup:()=>null}),s=>s,s=>s);
 const panel=new Type(); panel.currentUser={id:1}; panel.router={currentURL:'/ai',on(k,fn){listeners[k]=fn;},off(){}}; panel.composer={model:null}; panel.dialog={alert(){alerts++;}}; panel.setup(element);
 const control={isConnected:true,href:'/activity',session:false,closest(sel){return sel==='.je-you__native'?{}:this.session?{}:null;},getAttribute(){return this.href;},click(){replay++;}};
 const click=(mods={})=>listeners.click({target:{closest:()=>control},button:0,preventDefault(){},stopImmediatePropagation(){},...mods});
 return {panel,listeners,control,click,element,get replay(){return replay;},get alerts(){return alerts;},get opened(){return opened;}};
}
test('native departure is replayed exactly once only after permission',async()=>{
 const f=fixture(); await f.click(); assert.equal(f.replay,1); assert.equal(f.element.open,false);
 const denied=fixture(async()=>false); await denied.click(); assert.equal(denied.replay,0);
});
test('pending requests remain claimed and duplicate departures do not replay',async()=>{
 let done; const f=fixture(()=>new Promise(r=>done=r)); const pending=f.click(); await f.click(); let claimed=false;
 f.listeners['je-nav:identity:open']({preventDefault(){claimed=true;}}); assert.equal(claimed,true); assert.equal(f.opened,0);
 done(true); await pending; assert.equal(f.replay,1);
});
test('stale route, changed user and detached controls reject replay',async()=>{
 for(const change of [f=>f.panel.router.currentURL='/other',f=>f.panel.currentUser={id:2},f=>f.control.isConnected=false]) {
  let done; const f=fixture(()=>new Promise(r=>done=r)); const pending=f.click(); change(f); done(true); await pending; assert.equal(f.replay,0);
 }
});
test('logout and anonymous switching block open/minimized native composer',async()=>{
 for(const state of ['open','draft','fullscreen']) { const f=fixture(); f.control.session=true; f.control.href=null; f.panel.composer.model={composeState:state}; await f.click(); assert.equal(f.replay,0); assert.equal(f.alerts,1); }
 const f=fixture(); f.control.session=true; f.control.href=null; f.panel.composer.model={composeState:'closed'}; await f.click(); assert.equal(f.replay,1);
});
test('modified links and non-departure native actions are not intercepted',async()=>{
 const f=fixture(); await f.click({ctrlKey:true}); assert.equal(f.replay,0); assert.equal(f.element.open,true);
 f.control.href=null; await f.click(); assert.equal(f.element.open,true); assert.equal(f.alerts,0);
});
