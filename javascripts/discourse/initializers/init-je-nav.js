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

// ── v4.1: core-chrome suppression ────────────────────────────────────────
//
// Once a destination lives on the strip or the bottom bar, the equivalent
// core control is duplication — and on phones the duplicate header is the
// thing that makes the chrome look bolted on. Admins retire core controls
// per surface via je_nav_suppress_core_desktop / _mobile.
//
// The mechanism is deliberately dumb: this adds a static class per token
// per surface, and the stylesheet does the hiding inside a media query.
// WHY not decide the viewport here — the same reason the render surfaces
// don't: Discourse changes viewport mode at runtime, and a JS-side
// decision would need listeners and could disagree with the CSS that
// governs which nav is actually on screen. CSS owns one truth.
//
// WHY classes and not DOM removal: ADR-F1. Nothing core is patched or
// deleted. Disable this component and every control returns on the next
// paint, with no cleanup to get wrong.
const SUPPRESSIBLE = ["hamburger", "search", "chat", "ai-bot", "avatar"];

function suppressionClasses(rawList, surface) {
  return (rawList || "")
    .split("|")
    .map((token) => token.trim().toLowerCase())
    .filter((token) => SUPPRESSIBLE.includes(token))
    .map((token) => `je-nav-hide-${token}-${surface}`);
}

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  if (!user && !settings.je_nav_show_anon) {
    return;
  }

  if (settings.je_nav_mode === "takeover") {
    document.body.classList.add("je-nav-takeover");
  }

  [
    ...suppressionClasses(settings.je_nav_suppress_core_desktop, "desktop"),
    ...suppressionClasses(settings.je_nav_suppress_core_mobile, "mobile"),
  ].forEach((className) => document.body.classList.add(className));

  api.renderInOutlet("above-main-container", JeNavResponsive);
});
