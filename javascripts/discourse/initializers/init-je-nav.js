import { apiInitializer } from "discourse/lib/api";
import JeNav from "../components/je-nav/je-nav";

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  if (!user) {
    return;
  }

  // Desktop only — FNAV owns mobile. The component itself also guards on
  // currentUser, and CSS scopes the strip to non-mobile, but skipping the
  // mount on mobile avoids any wasted render.
  const site = api.container.lookup("service:site");
  if (site?.mobileView) {
    return;
  }

  // Allowlist: the sidebar stays visible only on "forum mode" routes.
  // Everything else is Plaza mode -> body gets `je-plaza-mode`, and the
  // stylesheet hides the sidebar off that single class.
  const hideSidebar = settings.je_nav_hide_sidebar_in_plaza;
  const forumClasses = (settings.je_nav_forum_route_classes || "")
    .split("|")
    .map((c) => c.trim())
    .filter(Boolean);

  function isForumRoute() {
    const router = api.container.lookup("service:router");
    const name = router?.currentRouteName || "";
    // Topic pages don't carry a navigation-* body class; match by route name.
    if (name.startsWith("topic.")) {
      return true;
    }
    return forumClasses.some((c) => document.body.classList.contains(c));
  }

  function applyMode() {
    if (!hideSidebar) {
      document.body.classList.remove("je-plaza-mode");
      return;
    }
    document.body.classList.toggle("je-plaza-mode", !isForumRoute());
  }

  api.onPageChange(() => {
    // Defer one tick so Discourse has stamped the route's body classes first.
    requestAnimationFrame(applyMode);
  });

  // Render the strip above the page content (sidebar + main-outlet).
  api.renderInOutlet("above-main-container", JeNav);

  // Initial pass for the first painted route.
  requestAnimationFrame(applyMode);
});
