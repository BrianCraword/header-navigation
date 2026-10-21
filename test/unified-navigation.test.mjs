import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import test from "node:test";
// Exercise the actual component getter bodies without requiring Ember services.
// Full component lifecycle/rendering remains an integrated-runtime test.
function getter(source, name, settings) {
  const start = source.indexOf(`get ${name}() {`);
  assert.notEqual(start, -1);
  const from = source.indexOf("{", start) + 1;
  let depth = 1, end = from;
  for (; depth; end++) {
    if (source[end] === "{") depth++;
    if (source[end] === "}") depth--;
  }
  return new Function("settings", `return function(){${source.slice(from,end-1)}}`)(settings);
}
for (const [component, sourceName] of [["je-nav", "stripSource"], ["je-nav-mobile", "barSource"]]) {
  const source = await readFile(new URL(`../javascripts/discourse/components/${component}/${component}.gjs`, import.meta.url), "utf8");
  test(`${component}: unified Feed and standard routes retain the configured source`, () => {
    const settings = {je_nav_unified_navigation_enabled:true};
    const focus = getter(source,"focusActive",settings);
    const rows = Object.freeze([{label:"Feed",href:"/feed"}, {label:"Restricted",visible_groups:"mm_participants"}]);
    for (const focusRoute of [true,false]) for (const focusCompanionEnabled of [true,false]) {
      const context = {focusRoute,focusCompanionEnabled,destinations:rows};
      context.focusActive=focus.call(context);
      assert.equal(context.focusActive,false);
      assert.equal(getter(source,sourceName,settings).call(context),rows);
    }
  });
  test(`${component}: disabling unified mode restores legacy scope`, () => {
    const focus=getter(source,"focusActive",{je_nav_unified_navigation_enabled:false});
    assert.equal(focus.call({focusCompanionEnabled:true,focusRoute:true}),true);
    assert.equal(focus.call({focusCompanionEnabled:true,focusRoute:false}),false);
    assert.equal(focus.call({focusCompanionEnabled:false,focusRoute:true}),false);
  });
  if(component==="je-nav") test("unified desktop hides only the redundant brand affordance",()=>{
    const context={showBrand:true,focusActive:false};
    assert.equal(getter(source,"showBrandNow",{je_nav_unified_navigation_enabled:true}).call(context),false);
    assert.equal(getter(source,"showBrandNow",{je_nav_unified_navigation_enabled:false}).call(context),true);
  });
}
