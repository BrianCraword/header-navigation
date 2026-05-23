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

const SIDEBAR_PREF_KEY = "je_nav_sidebar_hidden";

function cleanURL(url) {
  if (!url) {
    return "";
  }
  return url.replace(/(\?|#).*/g, "").replace(/\/$/, "");
}

// True when `current` is at or under `target`. Home ("/") only matches exactly,
// so it doesn't light up on every page.
function urlMatches(target, current) {
  const t = cleanURL(target);
  const c = cleanURL(current);
  if (!t || !c) {
    return false;
  }
  if (t === "/" || t === "") {
    return c === "/" || c === "";
  }
  return c === t || c.startsWith(t + "/");
}

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

  // Sidebar toggle: master switch + per-user remembered preference.
  sidebarMasterOn = settings.je_nav_hide_sidebar_in_plaza;
  @tracked sidebarHidden = this._readSidebarPref();

  // The per-user pin control only appears when the admin master switch is on.
  get showSidebarToggle() {
    return this.sidebarMasterOn;
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

  _resolve(href) {
    if (!href) {
      return "";
    }
    if (href.startsWith("/my/") && this.currentUser) {
      return href.replace("/my/", `/u/${this.currentUser.username_lower}/`);
    }
    return href;
  }

  // Pre-compute all dynamic state into plain objects. The template only ever
  // reads simple properties (resolvedHref, isActive, isOpen) — never calls a
  // method with arguments — which is the strict-mode-safe Glimmer pattern.
  // Recomputes whenever currentURL or openDropdown change (both tracked).
  get decoratedDestinations() {
    const current = this.currentURL;
    return this.destinations.map((dest) => {
      const isDropdown = dest.type === "dropdown";
      const children = (dest.children || []).map((child) => {
        const href = this._resolve(child.href);
        return {
          ...child,
          resolvedHref: href,
          isActive: urlMatches(href, current),
        };
      });
      const resolvedHref = this._resolve(dest.href);
      const isActive = isDropdown
        ? children.some((c) => c.isActive)
        : urlMatches(resolvedHref, current);
      // Custom icon color applies only when NOT active — the active state's
      // accent fill takes over so "you are here" stays unambiguous.
      const iconStyle =
        dest.color && !isActive
          ? htmlSafe(`color: ${dest.color};`)
          : null;
      return {
        ...dest,
        isDropdown,
        resolvedHref,
        children,
        isActive,
        iconStyle,
        isOpen: this.openDropdown === dest.label,
      };
    });
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
    {{#if this.currentUser}}
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
                    {{icon "angle-down" class="je-nav__caret"}}
                  </button>

                  {{#if dest.isOpen}}
                    <div class="je-nav__dropdown" {{on "click" this.stop}}>
                      {{#each dest.children as |child|}}
                        <a
                          href={{child.resolvedHref}}
                          class="je-nav__dropdown-row
                            {{if child.isActive 'active'}}"
                          {{on "click" (fn this.navigateChild child)}}
                        >
                          {{#if child.icon}}{{icon child.icon}}{{/if}}
                          <span class="je-nav__dropdown-text">
                            <span class="je-nav__dropdown-label">{{child.label}}</span>
                            {{#if child.subtext}}
                              <span class="je-nav__dropdown-subtext">{{child.subtext}}</span>
                            {{/if}}
                          </span>
                        </a>
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
        </div>
      </div>
    {{/if}}
  </template>
}
