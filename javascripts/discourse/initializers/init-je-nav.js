import { apiInitializer } from "discourse/lib/api";
import JeNavResponsive from "../components/je-nav-responsive";

// One navigation system, two reactive render surfaces. The initializer
// deliberately makes no viewport decision: Discourse can change viewport
// modes while the app is running, so each child component uses the tracked
// capabilities service and owns the setup/cleanup for its active mode.
//
// TAKEOVER MODE (stub): je_nav_mode=takeover adds body.je-nav-takeover.
// No CSS ships against it yet. It exists so a future sole-navigation mode is
// a stylesheet layer, not a refactor.

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  if (!user && !settings.je_nav_show_anon) {
    return;
  }

  if (settings.je_nav_mode === "takeover") {
    document.body.classList.add("je-nav-takeover");
  }

  api.renderInOutlet("above-main-container", JeNavResponsive);
});
