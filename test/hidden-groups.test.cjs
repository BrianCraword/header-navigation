// ── 5.2.0: hidden_groups ─────────────────────────────────────────────
//
// The live Matchmaking menu showed an mm_onboarding member both "Start
// your Journey" (every trust level) and "Continue your Journey"
// (mm_onboarding), two rows to /matchmaking. hidden_groups lets the entry
// row step aside once a member is in the funnel. These tests copy the
// live rows' gates (theme 250, je_nav_destinations, read 2026-10-11).
const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { test } = require("node:test");

const SOURCE = path.resolve(
  __dirname,
  "../javascripts/discourse/lib/je-nav-core.js"
);
const load = () => import(pathToFileURL(SOURCE).href);

const FUNNEL = "mm_onboarding|mm_interviewing|mm_participants|pending_verification";
const TL = "trust_level_0|trust_level_1|trust_level_2|trust_level_3|trust_level_4";

const start = { label: "Start your Journey", visible_groups: TL, hidden_groups: FUNNEL };
const cont = { label: "Continue your Journey", visible_groups: "mm_onboarding" };

const user = (...names) => ({ id: 7, groups: names.map((name) => ({ name })) });

test("a member not yet in the funnel sees Start, not Continue", async () => {
  const core = await load();
  const u = user("trust_level_0", "trust_level_1");
  assert.equal(core.groupsAllow(start, u), true);
  assert.equal(core.groupsAllow(cont, u), false);
});

test("an mm_onboarding member sees Continue, not Start", async () => {
  const core = await load();
  const u = user("mm_onboarding", "trust_level_0", "trust_level_1");
  assert.equal(core.groupsAllow(start, u), false);
  assert.equal(core.groupsAllow(cont, u), true);
});

test("group names match case-insensitively, whitespace ignored", async () => {
  const core = await load();
  const row = { hidden_groups: " MM_Onboarding | other " };
  assert.equal(core.groupsAllow(row, user("mm_onboarding")), false);
  assert.equal(core.groupsAllow(row, user("trust_level_1")), true);
});

test("hidden_groups alone never hides a row from a logged-out visitor", async () => {
  const core = await load();
  assert.equal(core.groupsAllow({ hidden_groups: FUNNEL }, null), true);
});

test("visible_groups behaviour is unchanged", async () => {
  const core = await load();
  assert.equal(core.groupsAllow({ visible_groups: "mm_participants" }, null), false);
  assert.equal(core.groupsAllow({ visible_groups: "" }, null), true);
  assert.equal(core.groupsAllow({}, user()), true);
  assert.equal(core.groupsAllow({ visible_groups: ["a", "b"] }, user("b")), true);
});

test("staff do not bypass hidden_groups", async () => {
  const core = await load();
  const staff = { ...user("mm_onboarding", "staff"), staff: true, admin: true };
  assert.equal(core.groupsAllow(start, staff), false);
});
