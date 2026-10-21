import { apiInitializer } from "discourse/lib/api";
import { siteMenuRows } from "../lib/je-nav-menu-model";

// Data-only adapter. Reuses the existing gates without changing tab suppression.
// The requesting UI owns focus, layout and lifecycle. No second global overlay.
export default apiInitializer((api) => {
  const listener = (event) => {
    const detail = event.detail;
    if (detail?.version !== 1 || !["mobile", "desktop"].includes(detail.surface)) { return; }
    const user = api.getCurrentUser();
    if (!user && !settings.je_nav_show_anon) { return; }
    detail.rows = siteMenuRows(settings.je_nav_destinations || [], user, detail.surface);
  };
  document.addEventListener("je-nav:destinations:request", listener);
  // App initializers live for the page lifetime; no route-scoped state is retained.
});
