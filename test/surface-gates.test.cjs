// ── F6: the AI primary may not escape its configured surface ─────────
//
// 5.1.0 accepted `surface` in findAiWorkspaceRow and never applied it, so
// a destination an admin had marked surface "desktop" became a PRIMARY
// control in the mobile bottom bar. The independent review's
// nav-boundary-probes.cjs reproduced exactly one case of that; this file
// is that probe turned into a permanent regression, plus the boundaries
// the probe did not cover.
//
// What is being protected here is an ADMIN'S PLACEMENT DECISION. The one
// documented exception is Messages, whose configured row is surface
// "mobile" and which the projection re-surfaces on purpose; every
// assertion below either holds the gate or names that exception.
const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { test } = require("node:test");

// pathToFileURL, not "file://" + path: on Windows the latter produces
// file://C:\... which is not a URL, and the suite could not load at all.
const SOURCE = path.resolve(
  __dirname,
  "../javascripts/discourse/lib/je-nav-core.js"
);
const load = () => import(pathToFileURL(SOURCE).href);

const member = (overrides = {}) => ({
  id: 7,
  username_lower: "member",
  groups: [],
  ...overrides,
});

test("a desktop-only AI group is not an AI primary on mobile", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  const destinations = [
    {
      label: "Desktop AI",
      type: "dropdown",
      surface: "desktop",
      show_when: "members",
      children: [{ label: "Workspace", href: ai, surface: "desktop" }],
    },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "mobile",
      aiHref: ai,
    }),
    null
  );
  // ...and is still the AI primary on the surface it was configured for.
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "desktop",
      aiHref: ai,
    }).href,
    ai
  );
});

test("a desktop-only CHILD inside a both-surface group is gated too", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  // The parent is reachable on mobile; the only workspace child is not.
  // The child gate is the one that has to refuse here, which is why both
  // are asserted separately.
  const destinations = [
    {
      label: "AI",
      type: "dropdown",
      surface: "both",
      children: [{ label: "Workspace", href: ai, surface: "desktop" }],
    },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "mobile",
      aiHref: ai,
    }),
    null
  );
});

test("a top-level desktop-only AI link is gated on mobile", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  const destinations = [
    { label: "AI Conversations", href: ai, surface: "desktop" },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "mobile",
      aiHref: ai,
    }),
    null
  );
});

test("an unset or unknown surface still fails open to both", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  // A menu's law is to fail OPEN on an unknown gate: a typo in the admin
  // panel must not silently delete a destination. Narrowing applies to
  // values that actually SAY desktop or mobile.
  for (const surfaceValue of [undefined, "", "Both", "nonsense"]) {
    const destinations = [{ label: "AI", href: ai, surface: surfaceValue }];
    for (const surface of ["desktop", "mobile"]) {
      assert.equal(
        core.findAiWorkspaceRow({
          destinations,
          currentUser: member(),
          surface,
          aiHref: ai,
        })?.href,
        ai,
        `surface ${JSON.stringify(surfaceValue)} on ${surface}`
      );
    }
  }
});

test("the surface gate never widens access", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  // A staff-only group stays staff-only on the surface it is configured
  // for. The surface rule is about WHERE a row renders and must not touch
  // show_when or visible_groups.
  const destinations = [
    {
      label: "AI",
      type: "dropdown",
      surface: "both",
      show_when: "staff",
      children: [{ label: "Workspace", href: ai, surface: "both" }],
    },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "desktop",
      aiHref: ai,
    }),
    null
  );
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member({ staff: true, admin: true }),
      surface: "desktop",
      aiHref: ai,
    }).href,
    ai
  );
});

test("a guest gets no AI primary on either surface", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  const destinations = [{ label: "AI", href: ai, surface: "both" }];
  for (const surface of ["desktop", "mobile"]) {
    assert.equal(
      core.findAiWorkspaceRow({
        destinations,
        currentUser: null,
        surface,
        aiHref: ai,
      }),
      null
    );
  }
});

// ── Ambiguity: the heuristic must never GUESS an agent ───────────────
//
// The review accepted the structural heuristic for these inputs and asked
// for ambiguity coverage. The rule being protected: a group is the
// dedicated AI group only when EVERY eligible child points at the
// workspace. A group where one child of several does is a topical group
// that happens to offer an agent, and promoting its row would present
// "open this particular agent" as the neutral workspace control.
test("a mixed group is not the dedicated AI group", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  const destinations = [
    {
      label: "The Word",
      type: "dropdown",
      surface: "both",
      children: [
        { label: "Studies", href: "/c/studies", surface: "both" },
        { label: "Omega", href: `${ai}?agent=omega`, surface: "both" },
      ],
    },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "desktop",
      aiHref: ai,
    }),
    null
  );
});

test("eligibility decides the group, so a filtered child cannot qualify it", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  // Two children: one workspace link this member may see, one unrelated
  // staff-only link. For a member the staff row is not eligible, so every
  // ELIGIBLE child points at the workspace and the group qualifies. For
  // staff it does not. The group's identity is therefore answered with
  // the same eligibility test as the row that is returned — which is the
  // property that stops a group qualifying on rows that are then dropped.
  const destinations = [
    {
      label: "AI",
      type: "dropdown",
      surface: "both",
      children: [
        { label: "Workspace", href: ai, surface: "both" },
        {
          label: "Admin AI",
          href: "/admin/ai",
          surface: "both",
          show_when: "staff",
        },
      ],
    },
  ];
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member(),
      surface: "desktop",
      aiHref: ai,
    }).href,
    ai
  );
  assert.equal(
    core.findAiWorkspaceRow({
      destinations,
      currentUser: member({ staff: true, admin: true }),
      surface: "desktop",
      aiHref: ai,
    }),
    null
  );
});

test("the returned href is always the neutral workspace, never a preselected agent", async () => {
  const core = await load();
  const ai = core.DEFAULT_AI_WORKSPACE_HREF;
  const destinations = [
    {
      label: "AI",
      type: "dropdown",
      surface: "both",
      children: [
        { label: "Omega", href: `${ai}?agent=omega#top`, surface: "both" },
      ],
    },
  ];
  const found = core.findAiWorkspaceRow({
    destinations,
    currentUser: member(),
    surface: "desktop",
    aiHref: ai,
  });
  // The group IS dedicated (its one eligible child is a workspace link),
  // so a primary is offered — but the query that preselects an agent is
  // stripped, because this control only ever opens the workspace.
  assert.equal(found.href, ai);
  assert.ok(!found.href.includes("agent="));
});

// ── The one documented widening ──────────────────────────────────────
test("Messages is the only row re-surfaced from mobile to both", async () => {
  const core = await load();
  const messagesHref = "/my/messages";
  const destinations = [
    { label: "Messages", href: messagesHref, surface: "mobile" },
    { label: "Groups", href: "/g", surface: "mobile" },
  ];
  const projection = core.focusedProjection({
    destinations,
    currentUser: member(),
    surface: "desktop",
    messagesHref,
  });
  const primaries = projection.primary;
  const messages = primaries.find((row) => row.href === messagesHref);
  assert.ok(messages, "Messages is a desktop primary despite surface mobile");
  assert.equal(messages.presentation_override, "surface: mobile -> both");
  // The other mobile-only row is NOT widened: it keeps the placement the
  // admin gave it, and the projection records why it is absent.
  assert.ok(
    !primaries.some((row) => row.href === "/g"),
    "an unrelated mobile-only row is not promoted to a desktop primary"
  );
});
