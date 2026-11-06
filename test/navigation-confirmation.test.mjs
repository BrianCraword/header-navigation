import test from "node:test";
import assert from "node:assert/strict";
import { navigationAllowed } from "../javascripts/discourse/lib/je-nav-core.js";
function setup(listener, draft = false) {
  globalThis.document = {dispatchEvent: listener, querySelectorAll: () => draft ? [{value: "draft"}] : [], querySelector: () => null};
  globalThis.window = {alert() {}};
}
test("versioned confirmation waits, cancels safely, and blocks duplicate navigation", async () => {
  let finish;
  setup(event => { assert.equal(event.detail.version, 2); event.detail.confirmation = new Promise(r => finish = r); return false; });
  const pending = navigationAllowed("/latest");
  assert.equal(await navigationAllowed("/other"), false);
  finish(false);
  assert.equal(await pending, false);
});
test("only explicit true permits departure", async () => {
  for (const result of [false, undefined, "true", true]) {
    setup(event => { event.detail.confirmation = Promise.resolve(result); return false; });
    assert.equal(await navigationAllowed("/latest"), result === true);
  }
});
test("legacy veto and missing companion retain protection", async () => {
  setup(() => false); assert.equal(await navigationAllowed("/latest"), false);
  setup(() => true, true); assert.equal(await navigationAllowed("/latest"), false);
  setup(() => true); assert.equal(await navigationAllowed("/latest"), true);
});
test("failed confirmation does not leave guard permanently busy", async () => {
  setup(event => {event.detail.confirmation = Promise.reject(new Error("failed")); return false;});
  await assert.rejects(navigationAllowed("/latest"));
  setup(() => true); assert.equal(await navigationAllowed("/latest"), true);
});