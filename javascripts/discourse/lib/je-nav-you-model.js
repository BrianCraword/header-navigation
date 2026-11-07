export function personalRoute(href, user, origin) {
  try {
    const base = new URL(origin);
    const url = new URL(href, base);
    if (url.origin !== base.origin) {
      return null;
    }
    let path = url.pathname.replace(/\/$/, "");
    const own = path.match(/^\/u\/([^/]+)(\/.*)$/);
    if (
      own &&
      decodeURIComponent(own[1]).toLowerCase() ===
        (user?.username_lower || user?.username || "").toLowerCase()
    ) {
      path = `/my${own[2]}`;
    }
    return path;
  } catch {
    return null;
  }
}

export function withInvitations(rows, user, label, origin) {
  if (
    !user?.can_invite_to_forum ||
    rows.some((row) => personalRoute(row.href, user, origin) === "/my/invited")
  ) {
    return rows;
  }
  return [
    ...rows,
    { label, href: "/my/invited", icon: "user-plus", show_when: "members" },
  ];
}

export function youSections(rows, user, labels, origin) {
  const sections = ["activity", "profiles", "account", "links"].map((key) => ({
    key,
    title: labels[key],
    rows: [],
  }));
  for (const row of rows) {
    const path = personalRoute(row.href, user, origin);
    let key = "links";
    if (
      path === "/my/badges" ||
      path === "/my/activity" ||
      path?.startsWith("/my/activity/") ||
      path === "/my/messages"
    ) {
      key = "activity";
    } else if (path === "/my/summary" || path === "/matchmaking/profile") {
      key = "profiles";
    } else if (
      path === "/my/invited" ||
      path === "/my/preferences" ||
      path?.startsWith("/my/preferences/")
    ) {
      key = "account";
    }
    const draftCount =
      path === "/my/activity/drafts" &&
      Number.isSafeInteger(user?.draft_count) &&
      user.draft_count > 0
        ? user.draft_count
        : null;
    sections
      .find((section) => section.key === key)
      .rows.push({
        ...row,
        label:
          path === "/my/messages" && row.label === "Messages"
            ? labels.private_messages
            : row.label,
        draftCount,
      });
  }
  return sections.filter(
    (section) => section.rows.length || section.key === "account"
  );
}

export function modifiedClick(event) {
  return (
    event.ctrlKey ||
    event.metaKey ||
    event.shiftKey ||
    event.altKey ||
    event.button !== 0
  );
}
