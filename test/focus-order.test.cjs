// ── 5.1.3: the focused four are pinned and ordered ────────────────────
//
// 5.1.2 copied `order` and `mobile_pinned` from the configured rows. On
// the live site Messages (order 7) and the AI row are not pinned, and
// Explore has no order, so the mobile bar showed Home · Explore · More and
// the desktop strip sorted Explore last. The shape below mirrors the live
// je_nav_destinations (2026-10-11).
const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { test } = require("node:test");

const SOURCE = path.resolve(
  __dirname,
  "../javascripts/discourse/lib/je-nav-core.js"
);
const load = () => import(pathToFileURL(SOURCE).href);

const member = { id: 7, username_lower: "member", groups: [] };

const destinations = (ai) => [
  { label: "Feed", type: "link", href: "/feed", surface: "both", mobile_pinned: true, order: 1 },
  {
    label: "Discussions",
    type: "dropdown",
    surface: "both",
    mobile_pinned: false,
    order: 2,
    children: [{ label: "Latest", href: "/latest" }],
  },
  {
    label: "AI Guides",
    type: "dropdown",
    surface: "both",
    mobile_pinned: false,
    order: 5,
    children: [{ label: "Your AI workspace", href: ai }],
  },
  { label: "Messages", type: "link", href: "/my/messages", surface: "mobile", mobile_pinned: false, order: 7 },
];

for (const surface of ["desktop", "mobile"]) {
  test(`${surface}: Home · Explore · Messages · AI, all pinned, in order`, async () => {
    const core = await load();
    const ai = core.DEFAULT_AI_WORKSPACE_HREF;
    const { primary } = core.focusedProjection({
      destinations: destinations(ai),
      currentUser: member,
      surface,
      labels: { home: "Home", explore: "Explore", messages: "Messages", ai: "AI Conversations" },
    });
    const ordered = core.orderedItems(primary);
    assert.deepEqual(
      ordered.map((dest) => dest.label),
      ["Home", "Explore", "Messages", "AI Conversations"]
    );
    assert.ok(ordered.every((dest) => dest.mobile_pinned === true));
  });
}
