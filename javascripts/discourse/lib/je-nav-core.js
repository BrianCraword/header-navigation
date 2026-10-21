// je-nav-core.js
//
// The one source of truth for interpreting the je_nav_destinations
// schema. Both render surfaces — the desktop strip (je-nav) and the
// mobile bottom bar + sheet (je-nav-mobile) — decorate the SAME stored
// objects through these helpers, so a destination added in the admin
// panel appears everywhere with identical visibility, ordering, active
// detection, and /my/ resolution. Never fork this logic into a
// component; extend it here.

export function cleanURL(url) {
  if (!url) {
    return "";
  }
  return url.replace(/(\?|#).*/g, "").replace(/\/$/, "");
}

// True when `current` is at or under `target`. Home ("/") only matches
// exactly, so it doesn't light up on every page.
export function urlMatches(target, current) {
  const t = cleanURL(target);
  const c = cleanURL(current);
  if (!t || !c) {
    return false;
  }
  if (t === "/" || t === "") {
    return c === "/" || c === "";
  }
  return c === t || c.startsWith(t + "/");
}

// Stable order-aware sort: items with an `order` number sort ascending;
// items without keep their list position, after ordered ones on ties.
export function orderedItems(list) {
  return (list || [])
    .map((item, idx) => ({ item, idx }))
    .sort((a, b) => {
      const ao =
        Number.isFinite(+a.item.order) &&
        a.item.order !== null &&
        a.item.order !== ""
          ? +a.item.order
          : Number.MAX_SAFE_INTEGER;
      const bo =
        Number.isFinite(+b.item.order) &&
        b.item.order !== null &&
        b.item.order !== ""
          ? +b.item.order
          : Number.MAX_SAFE_INTEGER;
      return ao === bo ? a.idx - b.idx : ao - bo;
    })
    .map((w) => w.item);
}

// show_when gate: all | members | staff. Unknown values fail open to
// "all" so a typo in the admin panel never blanks a menu item silently.
export function itemVisible(item, currentUser) {
  const w = item.show_when;
  if (w === "staff") {
    return !!currentUser?.staff;
  }
  if (w === "members") {
    return !!currentUser;
  }
  return true;
}

// The /my/ href alias resolves to the current user.
export function resolveHref(href, currentUser) {
  if (!href) {
    return "";
  }
  if (href.startsWith("/my/") && currentUser) {
    return href.replace("/my/", `/u/${currentUser.username_lower}/`);
  }
  return href;
}

// Group a decorated child list by `section`, preserving first-seen
// order. Children without a section form the untitled first group.
export function sectionize(children) {
  const sectionOrder = [];
  const byTitle = new Map();
  children.forEach((child) => {
    const title = (child.section || "").trim();
    if (!byTitle.has(title)) {
      byTitle.set(title, []);
      sectionOrder.push(title);
    }
    byTitle.get(title).push(child);
  });
  return sectionOrder.map((title) => ({
    title,
    hasTitle: title.length > 0,
    children: byTitle.get(title),
  }));
}

// ── v4.1: surface, groups, and dynamic state ─────────────────────────
//
// Three additive concerns, all resolved HERE so the desktop strip and
// the mobile bar can never drift apart:
//
//   SURFACE  — one destination list, two render surfaces. A row's
//              `surface` says where it belongs: "both" (default),
//              "desktop", or "mobile". This is what makes "show this on
//              phones only" a dropdown in the admin panel instead of a
//              second configuration to keep in sync.
//   GROUPS   — `visible_groups` narrows a row to members of specific
//              groups by NAME. It composes with show_when rather than
//              replacing it: both gates must pass.
//   STATE    — `href_source` and `badge_source` let a row read live
//              state a plugin publishes on current_user, instead of
//              hardcoding a URL or a number. See stateBag() for the
//              contract and WHY it lives on current_user.

export const SURFACES = ["both", "desktop", "mobile"];

// A row renders on `surface` ("desktop" | "mobile") when it asks for
// that surface or for both. Unknown values fail open to "both" — a typo
// in the admin panel must never blank a menu (same law as itemVisible).
export function surfaceMatches(item, surface) {
  const want = (item?.surface || "both").toString().trim().toLowerCase();
  if (want === "desktop" || want === "mobile") {
    return want === surface;
  }
  return true;
}

// visible_groups: compact list of group NAMES (the admin panel's list
// widget stores "a|b|c"; an array is accepted too). Empty = unrestricted.
//
// WHY names and not ids: ids are invisible in the admin UI and change
// between sites; this component ships to more than one. Names are what
// the admin actually types.
//
// Staff do NOT bypass this. A group gate is usually a FUNNEL STAGE
// ("show 'Finish your interview' to mm_onboarding"), and staff seeing
// every stage at once would make the funnel impossible to inspect. Use
// show_when: staff for genuine staff tools.
//
// hidden_groups (5.2.0) is the inverse: the row is hidden from members of
// ANY listed group. It exists for the entry row of a funnel — "Start your
// Journey" is for everyone NOT yet in it, and without an exclusion an
// mm_onboarding member saw it next to "Continue your Journey", two rows
// to the same place. Same name-list format; same no-staff-bypass rule.
// Checked after visible_groups, so a row can be narrowed and excluded.
function groupNames(raw) {
  if (!raw) {
    return [];
  }
  return (Array.isArray(raw) ? raw : String(raw).split("|"))
    .map((name) => String(name).trim().toLowerCase())
    .filter(Boolean);
}

export function groupsAllow(item, currentUser) {
  const wanted = groupNames(item?.visible_groups);
  const hidden = groupNames(item?.hidden_groups);
  if (wanted.length === 0 && hidden.length === 0) {
    return true;
  }
  const mine = new Set(
    (currentUser?.groups || []).map((g) =>
      String(g?.name || "").toLowerCase()
    )
  );
  if (wanted.length > 0 && !wanted.some((name) => mine.has(name))) {
    return false;
  }
  return !hidden.some((name) => mine.has(name));
}

// The one visibility question, asked once. Every render surface calls
// THIS — never the three gates separately — so a row added to the admin
// panel appears (or doesn't) identically everywhere.
export function rowVisible(item, currentUser, surface) {
  return (
    itemVisible(item, currentUser) &&
    groupsAllow(item, currentUser) &&
    surfaceMatches(item, surface)
  );
}

// ── The state bag ────────────────────────────────────────────────────
//
// A theme component cannot import a plugin's JavaScript, and re-fetching
// plugin endpoints from the nav would duplicate vc-feed's rail-fetch
// queue/TTL/429 layer inside a theme. So plugins publish what the nav
// needs on the CURRENT USER serializer, which every page already has:
// zero extra requests, available on every route, and the nav degrades to
// static behavior when the plugin is absent (ADR-F1).
//
// Contract (discourse-matchmaking >= the serializer release):
//   currentUser.matchmaking_view = {
//     journey_href, completion, meets_minimum, verification_status,
//     new_match_count, pending_introductions
//   }
// Anything missing simply resolves to null and the row renders static.
export function stateBag(currentUser) {
  return currentUser?.matchmaking_view || null;
}

// href_source: let a row follow a plugin's own routing law instead of
// hardcoding a destination.
//
// WHY this exists: matchmaking's documented law is that GATED
// DESTINATIONS ARE NEVER LINKED DIRECTLY — a member who hasn't been
// confirmed doors to /matchmaking (the resumable Journey), and only a
// confirmed member doors to /matchmaking/profile (the hub). Every menu
// that hardcoded /matchmaking/profile was breaking that law for every
// unconfirmed member. `href_source: matchmaking_journey` makes the menu
// ask rather than assume. `href` stays as the fallback for when the
// plugin is absent or dark.
export function resolveDynamicHref(item, currentUser) {
  if (item?.href_source === "matchmaking_journey") {
    const view = stateBag(currentUser);
    if (view?.journey_href) {
      return view.journey_href;
    }
  }
  return resolveHref(item?.href, currentUser);
}

// badge_source: a live count in place of (or falling back to) the static
// `badge` chip. Returns a STRING to render, or null for no chip.
//
// A grey label is furniture; a label carrying a number is a pull. Zero
// renders nothing on purpose — an empty badge is worse than no badge.
export function resolveBadge(item, currentUser) {
  const source = item?.badge_source;
  if (!source || source === "static") {
    return item?.badge || null;
  }

  const view = stateBag(currentUser);
  let count = null;

  switch (source) {
    case "matchmaking_new_matches":
      count = view?.new_match_count;
      break;
    case "matchmaking_introductions":
      count = view?.pending_introductions;
      break;
    case "matchmaking_incomplete":
      // Not a count — a nudge. Only speaks while the profile is short of
      // the minimum the plugin itself enforces.
      if (view && view.meets_minimum === false) {
        return `${Math.round(Number(view.completion) || 0)}%`;
      }
      return item?.badge || null;
    case "messages_unread":
      // Discourse's own number for the envelope badge. Named field, not
      // a notification-type magic number, so it survives core changes.
      count = currentUser?.new_personal_messages_notifications_count;
      break;
    case "notifications_unread":
      count = currentUser?.unread_high_priority_notifications;
      break;
    default:
      return item?.badge || null;
  }

  const n = Number(count) || 0;
  if (n <= 0) {
    return item?.badge || null;
  }
  return n > 99 ? "99+" : String(n);
}

// ── v5.1.0: the focused projection ───────────────────────────────────
//
// On the focused Feed the member needs FOUR primary controls — Home,
// Explore, Messages, AI Conversations — rather than the eight-item
// strip. What it must NOT need is a second copy of the menu.
//
// So this is a PROJECTION, computed per render from the configured
// `je_nav_destinations`, and nothing is ever written back to that
// setting. Turn the companion setting off and the configured menu
// renders exactly as before, because the configured menu is the only
// stored menu there has ever been.
//
// The schema is one level deep (dropdown -> children), and Explore needs
// two: the original groups, each holding its own destinations. The trick
// is that the schema ALREADY carries a second grouping axis — a child's
// `section`, which sectionize() turns into titled columns on desktop and
// grouped sub-headers in the mobile sheet. So a projected child takes
// its ORIGINAL PARENT'S LABEL as its section, and the existing renderers
// group it correctly with no new rendering concept. The child's own
// original section is preserved as `subsection` so nothing is discarded.
//
// ── Permissions are resolved BEFORE regrouping ──────────────────────
//
// This is the part that is easy to get wrong and expensive to get wrong.
// A child under `Matchmaking` was reachable only because its parent
// passed `show_when: members` AND the child passed its own
// `visible_groups` funnel stage. Flatten first and the parent's gate is
// simply gone, and a member sees a link the server will refuse. So every
// projected child is admitted only when rowVisible() passes for the
// PARENT and for the CHILD, evaluated against the same user and surface
// the projection is being built for.
//
// A server denial does not make a visible link acceptable. The gate is
// the point, not the 403.

// The AI workspace route. A setting rather than a constant so a site
// whose AI plugin moves can correct it without a component release.
export const DEFAULT_AI_WORKSPACE_HREF = "/discourse-ai/ai-bot/conversations";

// Labels the focused projection restates. The configured value stays
// untouched in the admin panel; only the projection renames it, and only
// for the surfaces the projection builds.
//
// "Continue your Journey" is the VC-owned label that reads as a generic
// site onboarding step when it is in fact the matchmaking funnel. The
// row keeps `href_source: matchmaking_journey`, so the JOURNEY RESOLVER
// is unchanged — this renames the door, not where it leads.
export const FOCUS_RELABELS = new Map([
  ["Start your Journey", "Start matchmaking"],
  ["Continue your Journey", "Continue matchmaking"],
  ["Finish your interview", "Finish your matchmaking interview"],
]);

export function focusRelabel(label) {
  return FOCUS_RELABELS.get((label || "").trim()) || label;
}

// show_when, from least to most restrictive. Projection keeps the
// STRICTER of parent and child so a carried-forward row can never widen.
const SHOW_WHEN_RANK = { all: 0, members: 1, staff: 2 };

function stricterShowWhen(parentValue, childValue) {
  const rank = (value) => SHOW_WHEN_RANK[value] ?? SHOW_WHEN_RANK.all;
  return rank(parentValue) >= rank(childValue)
    ? parentValue || childValue
    : childValue || parentValue;
}

// The access gates WITHOUT the surface rule.
//
// Needed because two of the four primaries are deliberately re-surfaced:
// the configured Messages row is surface "mobile", so a surface-aware
// filter would hide it from the desktop projection before the projection
// ever got to widen it. Access is still fully enforced — this drops only
// the "where does it render" rule, never show_when or visible_groups.
export function gateAllows(item, currentUser) {
  return itemVisible(item, currentUser) && groupsAllow(item, currentUser);
}

// Is this dropdown the site's dedicated AI group?
//
// Several rows legitimately point at the AI workspace: the Word group
// offers "Omega" (a teacher), the AI group offers the workspace itself
// plus each agent. They are NOT interchangeable, so the projection must
// not pick whichever matches the href first — that would surface a row
// meaning "open Omega" as the neutral "AI Conversations" control and
// imply an agent was preselected.
//
// The dedicated group identifies itself structurally: every one of its
// eligible children points at the workspace route. In the Word group one
// child of six does. No label is hardcoded.
function isDedicatedAiGroup(children, aiHref) {
  if (!children.length) {
    return false;
  }
  return children.every((child) => urlMatches(aiHref, child.href));
}

// The configured row that opens the AI workspace, or null.
//
// Priority: a top-level link to the workspace, then the first child of
// the dedicated AI group. Returns the row plus the href with any query
// or fragment removed, because a query is how an agent gets preselected
// and this control must only ever open the workspace.
export function findAiWorkspaceRow({
  destinations,
  currentUser,
  surface,
  aiHref = DEFAULT_AI_WORKSPACE_HREF,
}) {
  // The AI workspace is one member's private conversation list (the
  // configured panel says so: "Private to you."). The configured group
  // carries no show_when, and this component's law is to fail OPEN on an
  // unknown gate — correct for a menu, wrong for a primary control that
  // promises a personal workspace. So the projection NARROWS here: a
  // guest gets no AI primary. Narrowing can only ever remove a link a
  // member could not use; it never widens access. The configured group
  // itself is untouched and still appears in Explore exactly as set.
  if (!currentUser) {
    return null;
  }

  // ── v5.1.1 (F6): the surface rule applies here too ─────────────────
  //
  // 5.1.0 took `surface` as an argument and never used it, filtering on
  // gateAllows alone. gateAllows deliberately DROPS the surface rule,
  // because the configured Messages row is surface "mobile" and the
  // projection re-surfaces it on purpose — that widening is a single,
  // named, documented exception for Messages and nothing else.
  //
  // Applied to the AI candidate, the same omission silently widened every
  // AI row: the independent probe showed a destination an admin had
  // marked surface "desktop" becoming a PRIMARY control in the mobile
  // bottom bar. That is an admin's placement decision being overridden by
  // this component with no exception recorded for it.
  //
  // So both gates are asked here, for the PARENT and for the CHILD, with
  // the same user and the same surface — the same rule projectGroup
  // applies to every other nested row. This can only ever remove a row
  // from a surface the admin did not ask for; it never widens access and
  // never grants a surface.
  const visible = (item) => rowVisible(item, currentUser, surface);

  const tops = orderedItems(destinations).filter(visible);

  for (const dest of tops) {
    if (dest.type !== "dropdown" && urlMatches(aiHref, dest.href)) {
      return { row: dest, href: cleanURL(dest.href) || aiHref };
    }
  }

  for (const dest of tops) {
    if (dest.type !== "dropdown") {
      continue;
    }
    // The group identifies itself by what ALL of its eligible children
    // point at, so eligibility must be the same question here as it is
    // for the row finally returned — otherwise a group could qualify on
    // children that are then filtered out, and the heuristic would pick a
    // row this surface is not allowed to show.
    const children = orderedItems(dest.children || []).filter(visible);
    if (isDedicatedAiGroup(children, aiHref)) {
      const first = children[0];
      return { row: first, href: cleanURL(first.href) || aiHref };
    }
  }

  return null;
}

// Flatten one configured top-level destination into Explore children.
//
// `parent` supplies the section title and the inherited gates; `rows`
// come back already filtered for this user and surface.
function projectGroup(parent, currentUser, surface) {
  const isDropdown = parent.type === "dropdown";
  const section = (parent.label || "").trim();

  if (!isDropdown) {
    // A plain top-level link that is not one of the four primaries still
    // needs a home, or the projection would silently drop it.
    return [
      {
        ...parent,
        label: focusRelabel(parent.label),
        section,
        subsection: null,
        projected_from: section,
        projected_gates: {
          parent: { show_when: null, visible_groups: null, hidden_groups: null },
          child: {
            show_when: parent.show_when || null,
            visible_groups: parent.visible_groups || null,
            hidden_groups: parent.hidden_groups || null,
          },
        },
      },
    ];
  }

  const eligible = orderedItems(parent.children || []).filter(
    (child) =>
      // BOTH gates, same user, same surface. This is the line that
      // keeps the matchmaking funnel and the staff tools correct.
      rowVisible(parent, currentUser, surface) &&
      rowVisible(child, currentUser, surface)
  );

  // Read in the admin's intended order WITHIN the group.
  //
  // `order` interleaves sections: the configured Word group orders
  // Campaign, Omega, Bible Study, Trivia, NT, OT, and the existing
  // renderers only look coherent because sectionize() regroups them into
  // Today / Study with a guide / Read before painting. Flattening to one
  // section would publish that interleaved order as the reading order.
  // So the same helper decides the sequence here, and the rows come out
  // grouped the way the admin grouped them.
  const ordered = sectionize(eligible).flatMap((group) => group.children);

  return ordered
    .map((child) => ({
      ...child,
      label: focusRelabel(child.label),
      // The original parent becomes the group heading; the child's own
      // section is kept rather than thrown away.
      section,
      subsection: (child.section || "").trim() || null,
      projected_from: section,
      // Carried conservatively. The authoritative filtering already
      // happened above against this exact user; these exist so a
      // downstream re-evaluation can only ever be redundant, never wider.
      show_when: stricterShowWhen(parent.show_when, child.show_when),
      visible_groups: child.visible_groups || parent.visible_groups || null,
      // Exclusions only ever narrow, so the parent's and the child's are
      // both kept.
      hidden_groups:
        [child.hidden_groups, parent.hidden_groups].filter(Boolean).join("|") ||
        null,
      projected_gates: {
        parent: {
          show_when: parent.show_when || null,
          visible_groups: parent.visible_groups || null,
          hidden_groups: parent.hidden_groups || null,
        },
        child: {
          show_when: child.show_when || null,
          visible_groups: child.visible_groups || null,
          hidden_groups: child.hidden_groups || null,
        },
      },
    }));
}

// The focused projection.
//
// Returns { primary, explore, mapping }:
//   primary  — the ordered focused controls, ready to decorate exactly
//              like configured destinations
//   explore  — the Explore dropdown, children carrying section titles
//   mapping  — every configured destination and what became of it, so a
//              review can check that nothing was dropped
//
// `brand` is the separate brand link (je_nav_show_brand / _brand_label),
// which owns the real "Home" label and points at "/". Home in the
// focused strip is /feed, so the brand's destination moves into Explore
// as "Community home" and there is never a second Home label.
export function focusedProjection({
  destinations = [],
  currentUser = null,
  surface = "desktop",
  brand = null,
  aiHref = DEFAULT_AI_WORKSPACE_HREF,
  homeHref = "/feed",
  messagesHref = "/my/messages",
  labels = {},
} = {}) {
  const tops = orderedItems(destinations);
  const mapping = [];
  const claimed = new Set();

  const note = (label, outcome, detail) =>
    mapping.push({ label, outcome, detail });

  // Two populations, deliberately different:
  //   permitted — passes show_when and visible_groups. The four
  //               primaries are chosen from here, because the projection
  //               re-surfaces them on purpose.
  //   visibleTop — also passes the surface rule. Explore is built from
  //               here, so a destination an admin marked mobile-only
  //               keeps that meaning in the Explore sheet.
  const permitted = tops.filter((dest) => gateAllows(dest, currentUser));
  const visibleTop = permitted.filter((dest) =>
    surfaceMatches(dest, surface)
  );
  tops
    .filter((dest) => !permitted.includes(dest))
    .forEach((dest) => note(dest.label, "hidden", "gate denied for this user"));

  // ── Home: the configured /feed link, relabelled ──────────────────
  const homeRow =
    permitted.find(
      (dest) => dest.type !== "dropdown" && urlMatches(homeHref, dest.href)
    ) || null;
  let primary = [];
  if (homeRow) {
    claimed.add(homeRow);
    note(homeRow.label, "primary", `Home -> ${homeHref}`);
    primary.push({
      ...homeRow,
      label: labels.home || "Home",
      surface: "both",
      presentation_override: null,
    });
  }

  // ── Explore: everything else, grouped by its original parent ─────
  const exploreChildren = [];

  // The brand's destination leads the sheet, ungrouped, so the way back
  // to the forum is the first thing in it. sectionize() renders a
  // section-less child as the untitled first group.
  if (brand?.show && brand.href) {
    exploreChildren.push({
      label: labels.community_home || "Community home",
      href: brand.href,
      icon: brand.icon || null,
      subtext: labels.community_home_subtext || null,
      section: "",
      subsection: null,
      projected_from: "(brand link)",
    });
    note(
      `${brand.label || "Home"} (brand link)`,
      "explore",
      `kept as "${labels.community_home || "Community home"}" -> ${brand.href}; the global brand outside /feed is unchanged`
    );
  }

  // ── Messages and AI Conversations are primaries, not Explore rows ─
  const messagesRow =
    permitted.find(
      (dest) => dest.type !== "dropdown" && urlMatches(messagesHref, dest.href)
    ) || null;

  const ai = findAiWorkspaceRow({
    destinations,
    currentUser,
    surface,
    aiHref,
  });

  permitted
    .filter((dest) => !visibleTop.includes(dest) && dest !== messagesRow)
    .forEach((dest) =>
      note(
        dest.label,
        "hidden",
        `configured surface "${dest.surface}" excludes the ${surface} projection`
      )
    );

  for (const dest of visibleTop) {
    if (claimed.has(dest) || dest === messagesRow) {
      continue;
    }
    const rows = projectGroup(dest, currentUser, surface);
    if (rows.length === 0) {
      note(dest.label, "empty", "no child passed both gates for this user");
      continue;
    }
    exploreChildren.push(...rows);
    note(
      dest.label,
      "explore",
      `${rows.length} destination(s) under the "${dest.label}" group`
    );
  }

  const explore =
    exploreChildren.length > 0
      ? {
          label: labels.explore || "Explore",
          type: "dropdown",
          icon: "compass",
          surface: "both",
          mobile_pinned: true,
          panel_title: labels.explore_title || "Explore",
          panel_subtext: labels.explore_subtext || null,
          sheet_layout: "list",
          children: exploreChildren,
        }
      : null;
  if (explore) {
    primary.push(explore);
  }

  if (messagesRow) {
    claimed.add(messagesRow);
    // PRESENTATION OVERRIDE, recorded deliberately: the configured row is
    // surface "mobile", so the desktop strip never showed it. In the
    // focused four it is one of the primaries on BOTH surfaces. The gate
    // (show_when: members) and the unread badge_source are untouched —
    // only where it renders changes.
    note(
      messagesRow.label,
      "primary",
      "Messages -> configured /my/messages entry; surface widened from mobile to both (presentation override), gate and unread badge unchanged"
    );
    primary.push({
      ...messagesRow,
      label: labels.messages || messagesRow.label || "Messages",
      surface: "both",
      presentation_override: "surface: mobile -> both",
    });
  }

  if (ai) {
    note(
      ai.row.label,
      "primary",
      `AI Conversations -> ${ai.href} (workspace only; label is neutral and any query was dropped so no agent is preselected). The configured row also remains in Explore.`
    );
    primary.push({
      ...ai.row,
      label: labels.ai || "AI Conversations",
      href: ai.href,
      // The workspace, never an agent: drop anything that could
      // preselect one, including a dynamic href source.
      href_source: null,
      badge_source: ai.row.badge_source || null,
      surface: "both",
      presentation_override: "label neutralised; query/fragment removed",
    });
  }

  // The four are the whole bar, in this order, on both surfaces. Rows
  // copied from the configured menu bring their own `order` and
  // `mobile_pinned`, and Explore has neither: orderedItems() then sorted
  // Explore last, and the mobile bar sent unpinned Messages and AI into
  // More (seen live, 5.1.2). Set both explicitly.
  primary = primary.map((dest, index) => ({
    ...dest,
    order: index + 1,
    mobile_pinned: true,
  }));

  return { primary, explore, mapping };
}

// ── The Feed integration contract (v5.1.0) ───────────────────────────
//
// A theme component and a plugin cannot import each other, so the two
// coordinate through the DOM and one document event. This is the whole
// contract; it is deliberately tiny.
//
// 1. WHEN IS THE FOCUSED ROUTE ACTIVE?
//    The Feed plugin's own route adds `vc-feed-active` on /feed and
//    `vc-feed-focus` when its `vc_feed_focus_enabled` setting is on, and
//    removes both on deactivate. Requiring BOTH is what scopes this
//    projection to the focused Feed route and nothing else — no route
//    name is hardcoded here, and no setting is read across the boundary.
//
// 2. WHO OWNS THE MOBILE EXPLORE CONTROL?
//    While the projection is mounted on mobile this component adds
//    `je-nav-focus-explore` to <body>. That class is the ONLY promise
//    Feed needs: it means "a real Explore control exists in the bottom
//    bar right now". Feed stands its own fallback down when it is
//    present and keeps it otherwise — so if this component is absent,
//    disabled, or not yet mounted, the member still has Explore.
//
// 3. HOW DOES FEED ASK FOR THE SHEET?
//    Dispatch `je-nav:explore:open` on document. If the projection is
//    mounted it opens the shared Explore sheet. If nothing is listening
//    the event is simply unheard, which is why Feed must only hide its
//    own control on the class above, never on the event.
export const FEED_FOCUS_CLASSES = ["vc-feed-active", "vc-feed-focus"];
export const EXPLORE_READY_CLASS = "je-nav-focus-explore";
export const EXPLORE_OPEN_EVENT = "je-nav:explore:open";

export function feedFocusRouteActive(doc) {
  const list = (doc || document)?.body?.classList;
  if (!list) {
    return false;
  }
  return FEED_FOCUS_CLASSES.every((name) => list.contains(name));
}
