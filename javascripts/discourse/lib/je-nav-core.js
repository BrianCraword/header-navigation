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
