import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DiscourseURL from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import {
  itemVisible,
  orderedItems,
  resolveHref,
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

  @tracked openDropdown = null;
  @tracked currentURL = this.router.currentURL || "/";

  destinations = settings.je_nav_destinations || [];
  showBrand = settings.je_nav_show_brand;
  brandLabel = settings.je_nav_brand_label;
  brandIcon = settings.je_nav_brand_icon;
  showAvatar = settings.je_nav_show_avatar;
  showAnon = settings.je_nav_show_anon;

  // Sidebar toggle: master switch + per-user remembered preference.
  sidebarMasterOn = settings.je_nav_hide_sidebar_in_plaza;
  @tracked sidebarHidden = this._readSidebarPref();

  get showStrip() {
    return !!this.currentUser || this.showAnon;
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
  // reads simple properties (resolvedHref, isActive, isOpen, sections) —
  // never calls a method with arguments — the strict-mode-safe Glimmer
  // pattern. Recomputes when currentURL or openDropdown change (tracked).
  // Stable order-aware sort: items with an `order` number sort ascending;
  // items without keep their list position, after ordered ones on ties.
  get decoratedDestinations() {
    const current = this.currentURL;
    return orderedItems(this.destinations)
      .filter((dest) => itemVisible(dest, this.currentUser))
      .map((dest) => {
        const isDropdown = dest.type === "dropdown";
        const children = orderedItems(dest.children || [])
          .filter((child) => itemVisible(child, this.currentUser))
          .map((child) => {
            const href = resolveHref(child.href, this.currentUser);
            return {
              ...child,
              resolvedHref: href,
              isActive: urlMatches(href, current),
            };
          });

        // MEGA MENU: group children by `section` (shared sectionize —
        // the mobile sheet renders the same groups). One untitled group
        // = the classic v1 single-column dropdown.
        const sections = sectionize(children);
        const isMega =
          sections.length > 1 || (sections.length === 1 && sections[0].hasTitle);

        const resolvedHref = resolveHref(dest.href, this.currentUser);
        const isActive = isDropdown
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
          isOpen: this.openDropdown === dest.label,
        };
      })
      .filter((dest) => !dest.isDropdown || dest.children.length > 0);
  }

  @action
  trackRoute() {
    this.currentURL = this.router.currentURL || "/";
    this.routeListener = () => {
      this.currentURL = this.router.currentURL || "/";
      this.openDropdown = null;
    };
    this.router.on("routeDidChange", this.routeListener);
    document.addEventListener("click", this.closeOnOutside);
  }

  @action
  teardown() {
    if (this.routeListener) {
      this.router.off("routeDidChange", this.routeListener);
    }
    document.removeEventListener("click", this.closeOnOutside);
  }

  closeOnOutside = () => {
    this.openDropdown = null;
  };

  @action
  navigate(dest, event) {
    event?.preventDefault();
    event?.stopPropagation();
    DiscourseURL.routeTo(dest.resolvedHref);
  }

  @action
  toggleDropdown(label, event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.openDropdown = this.openDropdown === label ? null : label;
  }

  @action
  navigateChild(child, event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.openDropdown = null;
    DiscourseURL.routeTo(child.resolvedHref);
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
        class="je-nav"
        {{didInsert this.trackRoute}}
        {{willDestroy this.teardown}}
      >
        <div class="je-nav__inner">
          {{#if this.showBrand}}
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
            {{#each this.decoratedDestinations as |dest|}}
              {{#if dest.isDropdown}}
                <div class="je-nav__group">
                  <button
                    type="button"
                    class="je-nav__item
                      {{if dest.isActive 'active'}}
                      {{if dest.isOpen 'open'}}"
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

                  {{#if dest.isOpen}}
                    <div
                      class="je-nav__dropdown {{if dest.isMega 'je-nav__dropdown--mega'}}"
                      {{on "click" this.stop}}
                    >
                      {{#each dest.sections as |section|}}
                        <div class="je-nav__section">
                          {{#if section.hasTitle}}
                            <div class="je-nav__section-title">{{section.title}}</div>
                          {{/if}}
                          {{#each section.children as |child|}}
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
