import { apiInitializer } from "discourse/lib/api";
import JeNav from "../components/je-nav/je-nav";
import JeNavMobile from "../components/je-nav-mobile/je-nav-mobile";

const SIDEBAR_PREF_KEY = "je_nav_sidebar_hidden";

// One navigation system, two render surfaces, one early viewport branch:
//
//   MOBILE  → the bottom tab bar + sheet (je-nav-mobile). The Plaza
//             sidebar machinery NEVER runs here — v2 force-added
//             has-sidebar-page to the mobile body on every page change,
//             which is a class mobile Discourse never uses, and it
//             distorted underlying page layout. The mobile branch owns
//             only its own classes: je-nav-mobile-on (content padding)
//             and je-nav-mobile-suppressed (immersive routes where the
//             bar stands down, e.g. the docked AI composer).
//   DESKTOP → the strip (je-nav) + Plaza sidebar mode, unchanged from v2
//             but now unreachable on mobile by construction.
//
// TAKEOVER MODE (stub): je_nav_mode=takeover adds body.je-nav-takeover.
// No CSS ships against it yet — it exists so the future "this component
// owns ALL site navigation" flip is a stylesheet layer, not a refactor.
// Boundary when that day comes: we take over destinations; Discourse
// keeps search, notifications, and the user menu.

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  if (!user && !settings.je_nav_show_anon) {
    return;
  }

  if (settings.je_nav_mode === "takeover") {
    document.body.classList.add("je-nav-takeover");
  }

  const site = api.container.lookup("service:site");
  const mobile = !!site?.mobileView;

  // ── MOBILE BRANCH ──────────────────────────────────────────────────
  if (mobile) {
    if (!settings.je_nav_show_mobile) {
      return;
    }

    const suppressClasses = (settings.je_nav_mobile_suppress_classes || "")
      .split("|")
      .map((c) => c.trim())
      .filter(Boolean);

    function applyMobileMode() {
      const suppressed = suppressClasses.some((c) =>
        document.body.classList.contains(c)
      );
      document.body.classList.toggle("je-nav-mobile-on", !suppressed);
      document.body.classList.toggle("je-nav-mobile-suppressed", suppressed);
    }

    api.onPageChange(() => {
      // Route-owned body classes (ai-bot-conversations-page etc.) land
      // async around page change; a second pass catches late arrivals.
      requestAnimationFrame(applyMobileMode);
      setTimeout(applyMobileMode, 150);
    });

    api.renderInOutlet("above-main-container", JeNavMobile);
    requestAnimationFrame(applyMobileMode);
    return;
  }

  // ── DESKTOP BRANCH (v2 behavior, verbatim) ─────────────────────────
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
    const plaza = masterOn && userWantsHidden() && !isForumRoute();
    document.body.classList.toggle("je-plaza-mode", plaza);
    // Toggle Discourse's own sidebar-page class so the content grid
    // reclaims the column. Desktop-only by construction — the mobile
    // branch returned above and never touches this class.
    if (plaza) {
      document.body.classList.remove("has-sidebar-page");
    } else {
      document.body.classList.add("has-sidebar-page");
    }
  }

  api.onPageChange(() => {
    requestAnimationFrame(applyMode);
  });

  document.addEventListener("je-nav:sidebar-pref-changed", () => {
    requestAnimationFrame(applyMode);
  });

  api.renderInOutlet("above-main-container", JeNav);

  requestAnimationFrame(applyMode);
});
