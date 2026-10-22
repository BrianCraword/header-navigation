import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import { htmlSafe } from "@ember/template";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DiscourseURL from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  DEFAULT_AI_WORKSPACE_HREF,
  feedFocusRouteActive,
  focusedProjection,
  sharedProjection,
  sharedExploreSelected,
  navigationAllowed,
  orderedItems,
  resolveBadge,
  resolveDynamicHref,
  rowVisible,
  sectionize,
  urlMatches,
} from "../../lib/je-nav-core";

const SIDEBAR_PREF_KEY = "je_nav_sidebar_hidden";

// ── Header Mega Nav (v3) — desktop strip ────────────────────────────────
//
// One repo, many sites: the whole menu is the je_nav_destinations objects
// setting, edited per site in the admin panel. This component only renders
// what that setting declares. v2 additions, all schema-additive so every
// site's stored v1 value renders unchanged:
//
//   • MEGA MENU — children carrying a `section` label group into titled
//     columns; a dropdown with no sections renders the classic single
//     column, byte-for-byte the v1 layout.
//   • VISIBILITY — show_when (all/members/staff) per destination and per
//     child; je_nav_show_anon opens the strip to logged-out visitors
//     (members/staff items stay hidden for them).
//   • BADGES — an optional short `badge` chip (NEW, LIVE) per destination
//     and per child, for launching a surface without redesigning the menu.

export default class JeNav extends Component {
  @service router;
  @service currentUser;
  @service capabilities;

  @tracked openDropdown = null;
  @tracked aiContext = document.body.classList.contains("vcai-navigation-ready");
  @tracked currentURL = this.router.currentURL || "/";

  // v4.1.1 — hover intent. Dropdowns open on mouseenter and close on
  // mouseleave (after a short grace period so the pointer can cross the
  // gap into the panel). Only for pointers that can actually hover;
  @tracked focusRoute = feedFocusRouteActive();
@tracked sidebarHidden = this._readSidebarPref();
// touch keeps the click toggle, keyboard keeps Enter/Escape.
  hoverEnabled =
    settings.je_nav_desktop_open_on_hover &&
    typeof window !== "undefined" &&
    window.matchMedia?.("(hover: hover) and (pointer: fine)").matches;
  hoverCloseDelay = Number.isFinite(
    Number(settings.je_nav_desktop_hover_close_delay)
  )
    ? Number(settings.je_nav_desktop_hover_close_delay)
    : 160;
  destinations = settings.je_nav_destinations || [];
// other page.
focusCompanionEnabled = settings.je_nav_focus_companion_enabled;
// to the Feed's own focused route, so turning it on cannot change any
focusAiHref = settings.je_nav_focus_ai_href || DEFAULT_AI_WORKSPACE_HREF;
// v5.1.0 — the focused-Feed companion. Opt-in, and additionally scoped
focusHomeHref = settings.je_nav_focus_home_href || "/feed";
showBrand = settings.je_nav_show_brand;
brandLabel = settings.je_nav_brand_label;
brandIcon = settings.je_nav_brand_icon;
showAvatar = settings.je_nav_show_avatar;
showAnon = settings.je_nav_show_anon;
// Sidebar toggle: master switch + per-user remembered preference.
sidebarMasterOn = settings.je_nav_hide_sidebar_in_plaza;
forumClasses = (settings.je_nav_forum_route_classes || "")
    .split("|")
    .map((className) => className.trim())
    .filter(Boolean);
onBodyClassChanged = () => {
    this.aiContext = document.body.classList.contains("vcai-navigation-ready");
    const active = feedFocusRouteActive();
    if (this.focusRoute !== active) {
      this.focusRoute = active;
      // A projection change replaces the strip's rows, so an open panel
      // would be anchored to a trigger that no longer exists.
      this.openDropdown = null;
    }
  };
closeOnOutside = () => {
    this.openDropdown = null;
  };
onSidebarPrefChanged = () => {
    this._scheduleDesktopMode();
  };
_hoverTimer = null;

  
  
  
  
  
  
  
  
  

  
  
  
  

  
  
  
  

  


_desktopModeFrame = null;
  _desktopMounted = false;

  _scheduleDesktopMode = () => {
    if (!this._desktopMounted || this._desktopModeFrame !== null) {
      return;
    }
    this._desktopModeFrame = requestAnimationFrame(() => {
      this._desktopModeFrame = null;
      this._applyDesktopMode();
    });
  };

  get showStrip() {
    return (
      (!!this.currentUser || this.showAnon) &&
      this.capabilities.viewport.sm
    );
  }

  // The per-user pin control only appears when the admin master switch is
  // on — and only for logged-in users (the preference is per-browser, but
  // an anon strip stays uncluttered).
  get showSidebarToggle() {
    return this.sidebarMasterOn && !!this.currentUser;
  }

  _readSidebarPref() {
    try {
      const stored = window.localStorage.getItem(SIDEBAR_PREF_KEY);
      if (stored === "true") {
        return true;
      }
      if (stored === "false") {
        return false;
      }
    } catch (e) {
      // localStorage unavailable (private mode etc.) — fall through to default
    }
    return settings.je_nav_sidebar_default_hidden;
  }

  // Pre-compute all dynamic state into plain objects. The template only ever
  // reads simple properties (resolvedHref, isActive, sections) — never
  // calls a method with arguments — the strict-mode-safe Glimmer pattern.
  //
  // v4.1.3: @cached, and it no longer reads openDropdown. Before, every
  // hover/open invalidated this getter, it rebuilt every object, and the
  // key-less {{#each}} blocks replaced every node under .je-nav__items —
  // Chrome hit-tested a row, the row was destroyed mid-gesture, mousedown
  // and mouseup landed on different node instances, and no click was ever
  // synthesized. Open state is now resolved in the template with `eq`, so
  // this model only recomputes when the route or user changes.
  //
  // Stable order-aware sort: items with an `order` number sort ascending;
  // items without keep their list position, after ordered ones on ties.
  get sharedMode() { return settings.je_nav_layout === "shared_explore"; }

  get focusActive() {
    return !this.sharedMode && !settings.je_nav_unified_navigation_enabled && !!this.focusCompanionEnabled && this.focusRoute;
  }

  // The brand lockup owns the word "Home" and points at "/". In the
  // focused projection Home is /feed, so the brand stands down here and
  // its destination is offered inside Explore as "Community home" —
  // there is never a second competing Home label. Everywhere else the
  // brand renders exactly as configured.
  get showBrandNow() {
    return !this.sharedMode && this.showBrand && !settings.je_nav_unified_navigation_enabled && !this.focusActive;
  }

  // The focused projection, or the configured list. Both are the same
  // shape, so ONE decoration path below serves both and the two surfaces
  // cannot drift.
  get stripSource() {
    if (this.sharedMode) { return sharedProjection({destinations: this.destinations, currentUser: this.currentUser, surface: "desktop"}).primary; }
    if (!this.focusActive) {
      return this.destinations;
    }
    const { primary } = focusedProjection({
      destinations: this.destinations,
      currentUser: this.currentUser,
      surface: "desktop",
      brand: {
        show: this.showBrand,
        label: this.brandLabel,
        icon: this.brandIcon,
        href: "/",
      },
      aiHref: this.focusAiHref,
      homeHref: this.focusHomeHref,
      labels: {
        home: i18n(themePrefix("je_nav.focus.home")),
        explore: i18n(themePrefix("je_nav.focus.explore")),
        explore_title: i18n(themePrefix("je_nav.focus.explore_title")),
        explore_subtext: i18n(themePrefix("je_nav.focus.explore_subtext")),
        messages: i18n(themePrefix("je_nav.focus.messages")),
        ai: i18n(themePrefix("je_nav.focus.ai")),
        community_home: i18n(themePrefix("je_nav.focus.community_home")),
        community_home_subtext: i18n(themePrefix("je_nav.focus.community_home_subtext")),
      },
    });
    return primary;
  }

  @cached
  get decoratedDestinations() {
    const current = this.currentURL;
    // `focusRoute` is read through focusActive/stripSource, which is what
    // makes this recompute when the member enters or leaves /feed.
    return orderedItems(this.stripSource)
      .filter((dest) => rowVisible(dest, this.currentUser, "desktop"))
      .map((dest) => {
        const isDropdown = dest.type === "dropdown";
        const children = orderedItems(dest.children || [])
          .filter((child) => rowVisible(child, this.currentUser, "desktop"))
          .map((child) => {
            const href = resolveDynamicHref(child, this.currentUser);
            return {
              ...child,
              resolvedHref: href,
              badge: resolveBadge(child, this.currentUser),
              isActive: urlMatches(href, current),
            };
          });

        // MEGA MENU: group children by `section` (shared sectionize —
        // the mobile sheet renders the same groups). One untitled group
        // = the classic v1 single-column dropdown.
        const sections = sectionize(children);
        const isMega =
          sections.length > 1 || (sections.length === 1 && sections[0].hasTitle);

        const resolvedHref = resolveDynamicHref(dest, this.currentUser);
        const isActive = dest.shared_explore ? sharedExploreSelected(this.stripSource, current, this.currentUser, this.aiContext) : dest.shared_ai && this.aiContext ? true : dest.shared_messages && this.aiContext ? false : isDropdown
          ? children.some((c) => c.isActive)
          : urlMatches(resolvedHref, current);
        // Custom icon color applies only when NOT active — the active state's
        // accent fill takes over so "you are here" stays unambiguous.
        const iconStyle =
          dest.color && !isActive ? htmlSafe(`color: ${dest.color};`) : null;
        return {
          ...dest,
          isDropdown,
          resolvedHref,
          children,
          sections,
          isMega,
          isActive,
          iconStyle,
          badge: resolveBadge(dest, this.currentUser),
          // A panel with a heading is a mega menu with something to say;
          // without one it stays the plain link list it has always been.
          hasPanelHeader: !!(dest.panel_title || dest.panel_subtext),
        };
      })
      .filter((dest) => !dest.isDropdown || dest.children.length > 0);
  }

  @action
  trackRoute() {
    this._desktopMounted = true;
    this.onExploreRequest = event => {
      if (!this.sharedMode || !this.stripSource.some(d => d.shared_explore)) { return; }
      event.preventDefault();
      this.openDropdown = "Explore";
      requestAnimationFrame(() => document.querySelector(".je-nav__dropdown a")?.focus());
    };
    document.addEventListener("je-nav:explore:open", this.onExploreRequest);
    this.currentURL = this.router.currentURL || "/";
    this.routeListener = () => {
      this.currentURL = this.router.currentURL || "/";
      this.openDropdown = null;
      this.focusRoute = feedFocusRouteActive();
      this._scheduleDesktopMode();
    };
    this.router.on("routeDidChange", this.routeListener);
    // The Feed route adds its body classes in activate(), which can run
    // after routeDidChange, so the route event alone is not enough to
    // notice the focused route. Observing the attribute is exact and
    // costs one listener. Only when the companion is on; with it off
    // nothing reads the focused route.
    if (this.focusCompanionEnabled || this.sharedMode) {
      this._focusObserver = new MutationObserver(this.onBodyClassChanged);
      this._focusObserver.observe(document.body, {
        attributes: true,
        attributeFilter: ["class"],
      });
    }
    document.addEventListener("click", this.closeOnOutside);
    document.addEventListener(
      "je-nav:sidebar-pref-changed",
      this.onSidebarPrefChanged
    );
    this._scheduleDesktopMode();
  }

  

  

@action
  teardown() {
    this._desktopMounted = false;
    document.removeEventListener("je-nav:explore:open", this.onExploreRequest);
    this._focusObserver?.disconnect();
    this._focusObserver = null;
    if (this._desktopModeFrame !== null) {
      cancelAnimationFrame(this._desktopModeFrame);
      this._desktopModeFrame = null;
    }
    if (this.routeListener) {
      this.router.off("routeDidChange", this.routeListener);
    }
    document.removeEventListener("click", this.closeOnOutside);
    document.removeEventListener(
      "je-nav:sidebar-pref-changed",
      this.onSidebarPrefChanged
    );
    this._clearHoverTimer();
    document.body.classList.remove("je-plaza-mode");
    // Restore the desktop grid only when teardown happens on a desktop
    // viewport. Mobile Discourse does not own this class.
    if (this.capabilities.viewport.sm) {
      document.body.classList.add("has-sidebar-page");
    }
  }

  

  

_isForumRoute() {
    const name = this.router.currentRouteName || "";
    if (name.startsWith("topic.")) {
      return true;
    }
    return this.forumClasses.some((className) =>
      document.body.classList.contains(className)
    );
  }

  _applyDesktopMode() {
    if (!this._desktopMounted) {
      return;
    }
    const plaza =
      this.sidebarMasterOn && this.sidebarHidden && !this._isForumRoute();
    document.body.classList.toggle("je-plaza-mode", plaza);
    // Toggle Discourse's sidebar-page class so the content grid reclaims
    // the column. This method only runs while the desktop root is mounted.
    document.body.classList.toggle("has-sidebar-page", !plaza);
  }

  

  

  // v4.1.2 — one navigation path for strip items and dropdown rows.
  //   • modifier / middle clicks are left to the browser (new tab works)
  //   • routeTo runs BEFORE the dropdown closes, so the row is still in
  //     the DOM when the transition starts
  //   • if routeTo throws or refuses the href (external, unknown), fall
  //     back to a plain location change instead of a dead click
  _go(href, event) {
    if (!href) {
      return;
    }
    if (
      event &&
      (event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey ||
        event.button === 1)
    ) {
      return; // browser handles it
    }
    event?.preventDefault();
    event?.stopPropagation();
    if (!navigationAllowed(href)) { return; }
    try {
      DiscourseURL.routeTo(href);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[je-nav] routeTo failed, falling back", href, e);
      window.location.assign(href);
    }
    this.openDropdown = null;
  }

  @action
  navigate(dest, event) {
    this._go(dest.resolvedHref, event);
  }

  @action
  toggleDropdown(label, event) {
    event?.preventDefault();
    event?.stopPropagation();
    // With hover active, a click on an already-open trigger keeps it
    // open (the hover just opened it; a toggle would slam it shut).
    if (this.hoverEnabled && this.openDropdown === label) {
      return;
    }
    this.openDropdown = this.openDropdown === label ? null : label;
  }

  @action
  hoverOpen(label) {
    if (!this.hoverEnabled) {
      return;
    }
    this._clearHoverTimer();
    if (this.openDropdown !== label) {
      this.openDropdown = label;
    }
  }

  @action
  hoverClose() {
    if (!this.hoverEnabled) {
      return;
    }
    this._clearHoverTimer();
    this._hoverTimer = setTimeout(() => {
      this._hoverTimer = null;
      this.openDropdown = null;
    }, this.hoverCloseDelay);
  }

  @action
  onGroupKeydown(event) {
    if (event.key === "Escape" && this.openDropdown) {
      this.openDropdown = null;
      event.currentTarget.querySelector(".je-nav__item")?.focus();
    }
  }

  _clearHoverTimer() {
    if (this._hoverTimer !== null) {
      clearTimeout(this._hoverTimer);
      this._hoverTimer = null;
    }
  }

  @action
  navigateChild(child, event) {
    this._go(child.resolvedHref, event);
  }

  @action
  goHome(event) {
    event?.preventDefault();
    DiscourseURL.routeTo("/");
  }

  @action
  goAccount(event) {
    event?.preventDefault();
    if (this.currentUser) {
      DiscourseURL.routeTo(`/u/${this.currentUser.username_lower}/summary`);
    }
  }

  @action
  stop(event) {
    event.stopPropagation();
  }

  @action
  toggleSidebar(event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.sidebarHidden = !this.sidebarHidden;
    try {
      window.localStorage.setItem(SIDEBAR_PREF_KEY, String(this.sidebarHidden));
    } catch (e) {
      // ignore persistence failure
    }
    // Tell the initializer to re-evaluate Plaza mode immediately.
    document.dispatchEvent(
      new CustomEvent("je-nav:sidebar-pref-changed", {
        detail: { hidden: this.sidebarHidden },
      })
    );
  }

  <template>
    {{#if this.showStrip}}
      <div
        class="je-nav {{if this.sharedMode 'je-nav--shared'}} {{if this.focusActive 'je-nav--focus'}}"
        {{didInsert this.trackRoute}}
        {{willDestroy this.teardown}}
      >
        <div class="je-nav__inner">
          {{#if this.showBrandNow}}
            <a
              href="/"
              class="je-nav__brand"
              {{on "click" this.goHome}}
            >
              {{icon this.brandIcon}}
              <span>{{this.brandLabel}}</span>
            </a>
          {{/if}}

          <div class="je-nav__items">
            {{#each this.decoratedDestinations key="label" as |dest|}}
              {{#if dest.isDropdown}}
                <div
                  class="je-nav__group {{if dest.shared_shortcut 'je-nav__shortcut'}} {{if this.hoverEnabled 'is-hover'}}"
                  {{on "mouseenter" (fn this.hoverOpen dest.label)}}
                  {{on "mouseleave" this.hoverClose}}
                  {{on "keydown" this.onGroupKeydown}}
                >
                  <button
                    type="button"
                    class="je-nav__item
                      {{if dest.isActive 'active'}}
                      {{if (eq this.openDropdown dest.label) 'open'}}"
                    aria-haspopup="true"
                    aria-expanded={{if (eq this.openDropdown dest.label) "true" "false"}}
                    {{on "click" (fn this.toggleDropdown dest.label)}}
                  >
                    <span class="je-nav__icon" style={{dest.iconStyle}}>
                      {{icon dest.icon}}
                    </span>
                    <span>{{dest.label}}</span>
                    {{#if dest.badge}}
                      <span class="je-nav__badge">{{dest.badge}}</span>
                    {{/if}}
                    {{icon "angle-down" class="je-nav__caret"}}
                  </button>

                  {{#if (eq this.openDropdown dest.label)}}
                    <div
                      class="je-nav__dropdown {{if dest.isMega 'je-nav__dropdown--mega'}}"
                      {{on "click" this.stop}}
                    >
                      {{#if dest.hasPanelHeader}}
                        <div class="je-nav__panel-header">
                          {{#if dest.panel_title}}
                            <div class="je-nav__panel-title">
                              {{dest.panel_title}}
                            </div>
                          {{/if}}
                          {{#if dest.panel_subtext}}
                            <div class="je-nav__panel-subtext">
                              {{dest.panel_subtext}}
                            </div>
                          {{/if}}
                        </div>
                      {{/if}}
                      {{#each dest.sections key="@index" as |section|}}
                        <div class="je-nav__section">
                          {{#if section.hasTitle}}
                            <div class="je-nav__section-title">{{section.title}}</div>
                          {{/if}}
                          {{#each section.children key="label" as |child|}}
                            <a
                              href={{child.resolvedHref}}
                              class="je-nav__dropdown-row
                                {{if child.isActive 'active'}}"
                              {{on "click" (fn this.navigateChild child)}}
                            >
                              {{#if child.icon}}{{icon child.icon}}{{/if}}
                              <span class="je-nav__dropdown-text">
                                <span class="je-nav__dropdown-label">
                                  {{child.label}}
                                  {{#if child.badge}}
                                    <span class="je-nav__badge">{{child.badge}}</span>
                                  {{/if}}
                                </span>
                                {{#if child.subtext}}
                                  <span class="je-nav__dropdown-subtext">{{child.subtext}}</span>
                                {{/if}}
                              </span>
                            </a>
                          {{/each}}
                        </div>
                      {{/each}}
                    </div>
                  {{/if}}
                </div>
              {{else}}
                <a
                  href={{dest.resolvedHref}}
                  class="je-nav__item {{if dest.isActive 'active'}}"
                  {{on "click" (fn this.navigate dest)}}
                >
                  <span class="je-nav__icon" style={{dest.iconStyle}}>
                    {{icon dest.icon}}
                  </span>
                  <span>{{dest.label}}</span>
                  {{#if dest.badge}}
                    <span class="je-nav__badge">{{dest.badge}}</span>
                  {{/if}}
                </a>
              {{/if}}
            {{/each}}
          </div>

          <div class="je-nav__spacer"></div>

          {{#if this.showSidebarToggle}}
            <button
              type="button"
              class="je-nav__sidebar-toggle {{if this.sidebarHidden 'is-hidden' 'is-shown'}}"
              title={{if this.sidebarHidden "Show sidebar" "Hide sidebar"}}
              aria-label={{if this.sidebarHidden "Show sidebar" "Hide sidebar"}}
              aria-pressed="{{this.sidebarHidden}}"
              {{on "click" this.toggleSidebar}}
            >
              {{icon "table-columns"}}
            </button>
          {{/if}}

          {{#if this.showAvatar}}
            {{#if this.currentUser}}
              <button
                type="button"
                class="je-nav__avatar"
                title="Account"
                aria-label="Account"
                {{on "click" this.goAccount}}
              >
                {{this.currentUser.username}}
              </button>
            {{/if}}
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
