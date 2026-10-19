import { orderedItems, rowVisible, resolveDynamicHref } from "./je-nav-core";

function safeHref(href) {
  // This menu navigates within VC; reject protocol-relative and external targets.
  return typeof href === "string" && !/[\u0000-\u0020\\]/.test(href) && /^\/(?![\/\\])/.test(href) ? href : null;
}
export function siteMenuRows(destinations, user, surface) {
  return orderedItems(destinations).filter(d => rowVisible(d, user, surface)).flatMap(d => {
    if (d.type === "dropdown") {
      const children = orderedItems(d.children || []).filter(c => rowVisible(c, user, surface)).flatMap(c => {
        const href = safeHref(resolveDynamicHref(c, user));
        return href ? [{label: c.label, href}] : [];
      });
      return children.length ? [{label: d.label, children}] : [];
    }
    const href = safeHref(resolveDynamicHref(d, user));
    // Feed is the always-available explicit exit in the requesting toolbar.
    return href && href !== "/feed" ? [{label:d.label, href}] : [];
  });
}
