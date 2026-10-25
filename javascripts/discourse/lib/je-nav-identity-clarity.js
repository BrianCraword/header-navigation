// Presentation-only projection: never mutate stored identity-link settings.
// Existing destinations (even hidden ones) suppress automatic additions.
export function identityClarityRows(rows, user, labels, origin) {
  if (!user) { return rows; }
  const username = (user.username_lower || user.username || "").toLowerCase();
  const canonical = href => {
    if (typeof href !== "string") { return ""; }
    try {
      // A synthetic base resolves relative paths without equating external links.
      const base = new URL(origin || "https://identity.invalid");
      const url = new URL(href, base);
      if (url.origin !== base.origin) { return ""; }
      let path = url.pathname.replace(/\/$/, "");
      const own = path.match(/^\/u\/([^/]+)(\/.*)$/);
      if (own && username && decodeURIComponent(own[1]).toLowerCase() === username) {
        path = `/my${own[2]}`;
      }
      return path;
    } catch {
      return "";
    }
  };
  const result = rows.map(row => {
    const href = canonical(row.href);
    if (href === "/my/summary" && row.label === "My Profile") {
      return { ...row, label: labels.community_profile };
    }
    if (href === "/badges" && row.label === "Badges") {
      return { ...row, label: labels.badge_catalog };
    }
    return row;
  });
  const existing = new Set(rows.map(row => canonical(row.href)));
  for (const [key, href, icon] of [
    ["activity", "/my/activity", "user"],
    ["drafts", "/my/activity/drafts", "comments"],
    ["my_badges", "/my/badges", "medal"],
  ]) {
    if (!existing.has(href)) {
      result.push({ label: labels[key], href, icon, show_when: "members" });
    }
  }
  return result;
}
