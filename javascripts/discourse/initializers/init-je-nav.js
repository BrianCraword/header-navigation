import { apiInitializer } from "discourse/lib/api";
import JeNav from "../components/je-nav/je-nav";

const SIDEBAR_PREF_KEY = "je_nav_sidebar_hidden";

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  if (!user) {
    return;
  }

  // Desktop only — FNAV owns mobile.
  const site = api.container.lookup("service:site");
  if (site?.mobileView) {
    return;
  }

  const masterOn = settings.je_nav_hide_sidebar_in_plaza;

  const forumClasses = (settings.je_nav_forum_route_classes || "")
    .split("|")
    .map((c) => c.trim())
    .filter(Boolean);

  function userWantsHidden() {
    try {
      const stored = window.localStorage.getItem(SIDEBAR_PREF_KEY);
      if (stored === "true") {
        return true;
      }
      if (stored === "false") {
        return false;
      }
    } catch (e) {
      // ignore
    }
    return settings.je_nav_sidebar_default_hidden;
  }

  function isForumRoute() {
    const router = api.container.lookup("service:router");
    const name = router?.currentRouteName || "";
    if (name.startsWith("topic.")) {
      return true;
    }
    return forumClasses.some((c) => document.body.classList.contains(c));
  }

  function applyMode() {
    // Plaza mode = master on AND user wants it hidden AND not on a forum route.
    const plaza = masterOn && userWantsHidden() && !isForumRoute();
    document.body.classList.toggle("je-plaza-mode", plaza);
    // Toggle Discourse's own sidebar-page class so the content grid reclaims
    // the column (collapses to 0px). We only remove it in Plaza mode and
    // restore it otherwise, so native sidebar behaviour is untouched elsewhere.
    if (plaza) {
      document.body.classList.remove("has-sidebar-page");
    } else {
      document.body.classList.add("has-sidebar-page");
    }
  }

  api.onPageChange(() => {
    requestAnimationFrame(applyMode);
  });

  // Re-evaluate immediately when the user flips the strip's pin toggle.
  document.addEventListener("je-nav:sidebar-pref-changed", () => {
    requestAnimationFrame(applyMode);
  });

  api.renderInOutlet("above-main-container", JeNav);

  requestAnimationFrame(applyMode);
});
