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
export function groupsAllow(item, currentUser) {
  const raw = item?.visible_groups;
  if (!raw) {
    return true;
  }
  const wanted = (Array.isArray(raw) ? raw : String(raw).split("|"))
    .map((name) => String(name).trim().toLowerCase())
    .filter(Boolean);
  if (wanted.length === 0) {
    return true;
  }
  if (!currentUser) {
    return false;
  }
  const mine = new Set(
    (currentUser.groups || []).map((g) => String(g?.name || "").toLowerCase())
  );
  return wanted.some((name) => mine.has(name));
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
