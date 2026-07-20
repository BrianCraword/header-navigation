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
import { ajax } from "discourse/lib/ajax";
import avatar from "discourse/helpers/avatar";
import icon from "discourse-common/helpers/d-icon";
import {
  itemVisible,
  orderedItems,
  resolveHref,
  sectionize,
  urlMatches,
} from "../../lib/je-nav-core";

// ── Mobile Bottom Nav (v3) ───────────────────────────────────────────────
//
// The mobile render surface of the Header Mega Nav system. Same
// je_nav_destinations objects as the desktop strip, three behaviors:
//
//   • BOTTOM TAB BAR — destinations with mobile_pinned render as fixed
//     tabs in the thumb zone (icon + optional label). If NO destination
//     is pinned yet (fresh install, or a site whose stored v2 values
//     predate the property), the first four visible destinations are
//     auto-pinned so the bar is never empty on day one.
//   • BOTTOM SHEET — the overflow surface. The trailing "More" tab opens
//     the full map of unpinned destinations; tapping a PINNED DROPDOWN
//     tab opens a contextual sheet of just that dropdown's children —
//     the mega-menu `section` labels render as grouped sub-headers.
//   • HIDE ON SCROLL — the bar slips away scrolling down, returns
//     scrolling up, and always shows near the top of the page or while
//     the sheet is open. rAF-throttled, passive listener.
//
// Suppression on immersive routes (docked AI composer etc.) is CSS-only,
// via body classes the initializer maintains — this component never has
// to know.

const SCROLL_REVEAL_CEILING = 64; // always visible above this scroll depth
const SCROLL_DELTA_MIN = 6; // ignore jitter smaller than this

export default class JeNavMobile extends Component {
  @service router;
  @service currentUser;
  @service capabilities;

  @tracked currentURL = this.router.currentURL || "/";
  @tracked barHidden = false;
  // null = closed · "__more__" = full overflow sheet · any other string =
  // the label of the pinned dropdown whose contextual sheet is open.
  @tracked sheetKey = null;
  // v4: the identity sheet — the mobile hero, summoned instead of
  // squatting. Opens from the avatar tab, the More-sheet profile row,
  // or any surface dispatching the "je-nav:identity:open" event (the
  // vc-feed porch avatar does).
  @tracked identityOpen = false;
  @tracked identityStats = null;

  destinations = settings.je_nav_destinations || [];
  showLabels = settings.je_nav_mobile_show_labels;
  hideOnScroll = settings.je_nav_mobile_hide_on_scroll;
  moreLabel = settings.je_nav_mobile_more_label || "More";
  moreIcon = settings.je_nav_mobile_more_icon || "ellipsis";
  avatarTab = settings.je_nav_mobile_avatar_tab;
  identityLinks = settings.je_nav_identity_links || [];
  identityPrimaryLabel =
    settings.je_nav_identity_primary_label || "Update your profile";
  identityPrimaryHref =
    settings.je_nav_identity_primary_href || "/matchmaking";
  showAnon = settings.je_nav_show_anon;
  showMobile = settings.je_nav_show_mobile;
  suppressClasses = (settings.je_nav_mobile_suppress_classes || "")
    .split("|")
    .map((className) => className.trim())
    .filter(Boolean);

  _lastY = 0;
  _scrollTicking = false;
  _mobileMounted = false;
  _mobileModeFrame = null;
  _mobileModeTimer = null;
  _classObserver = null;

  get showBar() {
    return (
      this.showMobile &&
      (!!this.currentUser || this.showAnon) &&
      !this.capabilities.viewport.sm
    );
  }

  // ── Destination decoration ────────────────────────────────────────────

  _decorate(dest) {
    const current = this.currentURL;
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
    const resolvedHref = resolveHref(dest.href, this.currentUser);
    const isActive = isDropdown
      ? children.some((c) => c.isActive)
      : urlMatches(resolvedHref, current);
    return { ...dest, isDropdown, children, resolvedHref, isActive };
  }

  get _visibleDestinations() {
    return orderedItems(this.destinations)
      .filter((dest) => itemVisible(dest, this.currentUser))
      .map((dest) => this._decorate(dest))
      .filter((dest) => !dest.isDropdown || dest.children.length > 0);
  }

  get _split() {
    const all = this._visibleDestinations;
    let pinned = all.filter((dest) => dest.mobile_pinned === true);
    let rest = all.filter((dest) => dest.mobile_pinned !== true);
    if (pinned.length === 0) {
      // Day-one fallback: stored v2 objects have no mobile_pinned yet.
      pinned = all.slice(0, 4);
      rest = all.slice(4);
    }
    return { pinned, rest };
  }

  // The tab row: pinned destinations plus the trailing More tab when
  // anything remains unpinned. Every property the template reads is
  // precomputed here — strict-mode discipline.
  get tabs() {
    const { pinned, rest } = this._split;
    const tabs = pinned.map((dest) => ({
      key: dest.label,
      kind: dest.isDropdown ? "dropdown" : "link",
      emphasis: dest.emphasis === true,
      label: dest.label,
      icon: dest.icon,
      badge: dest.badge,
      resolvedHref: dest.resolvedHref,
      isActive: dest.isActive,
      isOpen: this.sheetKey === dest.label,
      iconStyle:
        dest.color && !dest.isActive
          ? htmlSafe(`color: ${dest.color};`)
          : null,
    }));
    if (rest.length > 0) {
      const restActive = rest.some((dest) => dest.isActive);
      const restBadged = rest.some(
        (dest) => dest.badge || dest.children.some((c) => c.badge)
      );
      tabs.push({
        key: "__more__",
        kind: "more",
        label: this.moreLabel,
        icon: this.moreIcon,
        badge: null,
        hasDot: restBadged,
        resolvedHref: null,
        isActive: restActive,
        isOpen: this.sheetKey === "__more__",
        iconStyle: null,
      });
    }
    if (this.avatarTab && this.currentUser) {
      tabs.push({
        key: "__me__",
        kind: "identity",
        label: "You",
        icon: null,
        emphasis: false,
        avatarUser: this.currentUser,
        badge: null,
        resolvedHref: null,
        isActive: false,
        isOpen: this.identityOpen,
        iconStyle: null,
      });
    }
    return tabs;
  }

  // ── Sheet model ───────────────────────────────────────────────────────

  get sheetOpen() {
    return this.sheetKey !== null;
  }

  get overlayOpen() {
    return this.sheetOpen || this.identityOpen;
  }

  get moreProfileVisible() {
    return this.sheetKey === "__more__" && !!this.currentUser;
  }

  // ── Identity sheet model (v4) ─────────────────────────────────────────

  get identityName() {
    return this.currentUser?.name || this.currentUser?.username || "";
  }

  get changePhotoHref() {
    // The one place changing your photo must always be a SNAP: the
    // account preferences page, where the avatar selector lives.
    return resolveHref("/my/preferences/account", this.currentUser);
  }

  get identityPrimaryResolved() {
    return resolveHref(this.identityPrimaryHref, this.currentUser);
  }

  get identityRows() {
    return orderedItems(this.identityLinks)
      .filter((link) => itemVisible(link, this.currentUser))
      .map((link) => ({
        key: link.label,
        label: link.label,
        icon: link.icon || "angle-right",
        resolvedHref: resolveHref(link.href, this.currentUser),
      }));
  }

  get statChips() {
    const s = this.identityStats;
    if (!s) {
      return [];
    }
    return [
      { key: "received", value: s.likes_received ?? 0, label: "hearts received" },
      { key: "given", value: s.likes_given ?? 0, label: "hearts given" },
      { key: "topics", value: s.topic_count ?? 0, label: "topics" },
      { key: "posts", value: s.post_count ?? 0, label: "posts" },
      { key: "days", value: s.days_visited ?? 0, label: "days walked" },
    ];
  }

  async _loadIdentityStats() {
    if (this.identityStats || !this.currentUser) {
      return;
    }
    try {
      const res = await ajax(
        `/u/${this.currentUser.username_lower}/summary.json`
      );
      this.identityStats = res?.user_summary || null;
    } catch {
      this.identityStats = null; // chips simply don't render
    }
  }

  get sheetTitle() {
    if (this.sheetKey === "__more__") {
      return this.moreLabel;
    }
    return this.sheetKey || "";
  }

  // Groups of rows. Contextual sheet (a pinned dropdown): that dropdown's
  // sections. Full sheet: every unpinned destination — bare links gather
  // into an untitled leading group; each dropdown contributes one group
  // per mega-menu section (titled "Dropdown — Section" when sections
  // exist, or just the dropdown label when they don't).
  get sheetGroups() {
    if (!this.sheetOpen) {
      return [];
    }

    const linkRow = (dest) => ({
      key: dest.label,
      label: dest.label,
      icon: dest.icon,
      subtext: dest.subtext,
      badge: dest.badge,
      resolvedHref: dest.resolvedHref,
      isActive: dest.isActive,
      iconStyle:
        dest.color && !dest.isActive
          ? htmlSafe(`color: ${dest.color};`)
          : null,
    });
    const childRow = (child) => ({
      key: child.label,
      label: child.label,
      icon: child.icon,
      subtext: child.subtext,
      badge: child.badge,
      resolvedHref: child.resolvedHref,
      isActive: child.isActive,
      iconStyle: null,
    });

    if (this.sheetKey !== "__more__") {
      const dest = this._visibleDestinations.find(
        (candidate) => candidate.label === this.sheetKey
      );
      if (!dest) {
        return [];
      }
      return sectionize(dest.children).map((section) => ({
        title: section.title,
        hasTitle: section.hasTitle,
        rows: section.children.map(childRow),
      }));
    }

    const { rest } = this._split;
    const groups = [];
    const looseLinks = rest.filter((dest) => !dest.isDropdown);
    if (looseLinks.length > 0) {
      groups.push({
        title: "",
        hasTitle: false,
        rows: looseLinks.map(linkRow),
      });
    }
    rest
      .filter((dest) => dest.isDropdown)
      .forEach((dest) => {
        const sections = sectionize(dest.children);
        const multi = sections.length > 1 || sections[0]?.hasTitle;
        sections.forEach((section) => {
          groups.push({
            title: multi
              ? section.hasTitle
                ? `${dest.label} — ${section.title}`
                : dest.label
              : dest.label,
            hasTitle: true,
            rows: section.children.map(childRow),
          });
        });
      });
    return groups;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @action
  setup() {
    this._mobileMounted = true;
    this.routeListener = () => {
      this.currentURL = this.router.currentURL || "/";
      this._closeSheet();
      this._closeIdentity();
      this.barHidden = false;
      this._lastY = Math.max(0, window.scrollY);
      this._scheduleMobileMode(true);
    };
    this.router.on("routeDidChange", this.routeListener);

    if (this.hideOnScroll) {
      this._lastY = Math.max(0, window.scrollY);
      window.addEventListener("scroll", this.onScroll, { passive: true });
    }
    document.addEventListener("keydown", this.onKeydown);

    // Other surfaces (the vc-feed porch avatar) summon the identity
    // sheet through this event; preventDefault signals "claimed", so
    // the dispatcher knows not to fall back to a navigation.
    this.onIdentityRequest = (event) => {
      event.preventDefault();
      this.openIdentity();
    };
    document.addEventListener("je-nav:identity:open", this.onIdentityRequest);

    // Route classes live on <body>, while state classes such as
    // composer-open live on <html>. Observe both so suppression responds to
    // route transitions and overlays that do not emit a route change.
    this._classObserver = new MutationObserver(this.onClassMutation);
    this._classObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });
    this._classObserver.observe(document.body, {
      attributes: true,
      attributeFilter: ["class"],
    });
    this._scheduleMobileMode(true);
  }

  @action
  teardown() {
    this._mobileMounted = false;
    if (this._mobileModeFrame !== null) {
      cancelAnimationFrame(this._mobileModeFrame);
      this._mobileModeFrame = null;
    }
    if (this._mobileModeTimer !== null) {
      clearTimeout(this._mobileModeTimer);
      this._mobileModeTimer = null;
    }
    this._classObserver?.disconnect();
    this._classObserver = null;
    if (this.routeListener) {
      this.router.off("routeDidChange", this.routeListener);
    }
    window.removeEventListener("scroll", this.onScroll);
    document.removeEventListener("keydown", this.onKeydown);
    if (this.onIdentityRequest) {
      document.removeEventListener(
        "je-nav:identity:open",
        this.onIdentityRequest
      );
    }
    document.body.classList.remove("je-nav-sheet-open");
    document.body.classList.remove(
      "je-nav-mobile-on",
      "je-nav-mobile-suppressed"
    );
  }

  _suppressActive() {
    return this.suppressClasses.some(
      (className) =>
        document.body.classList.contains(className) ||
        document.documentElement.classList.contains(className)
    );
  }

  _applyMobileMode() {
    if (!this._mobileMounted) {
      return;
    }
    const suppressed = this._suppressActive();
    document.body.classList.toggle("je-nav-mobile-on", !suppressed);
    document.body.classList.toggle("je-nav-mobile-suppressed", suppressed);
  }

  _scheduleMobileMode(delayed = false) {
    if (!this._mobileMounted) {
      return;
    }
    if (this._mobileModeFrame === null) {
      this._mobileModeFrame = requestAnimationFrame(() => {
        this._mobileModeFrame = null;
        this._applyMobileMode();
      });
    }
    if (delayed) {
      if (this._mobileModeTimer !== null) {
        clearTimeout(this._mobileModeTimer);
      }
      // Route-owned body classes can land after routeDidChange.
      this._mobileModeTimer = setTimeout(() => {
        this._mobileModeTimer = null;
        this._applyMobileMode();
      }, 150);
    }
  }

  onClassMutation = () => {
    this._scheduleMobileMode();
  };

  onScroll = () => {
    if (this._scrollTicking) {
      return;
    }
    this._scrollTicking = true;
    requestAnimationFrame(() => {
      this._scrollTicking = false;
      if (this.overlayOpen) {
        return; // never hide under an open sheet
      }
      const y = Math.max(0, window.scrollY); // iOS rubber-band guard
      const delta = y - this._lastY;
      if (Math.abs(delta) < SCROLL_DELTA_MIN) {
        return;
      }
      if (y <= SCROLL_REVEAL_CEILING) {
        this.barHidden = false;
      } else {
        this.barHidden = delta > 0;
      }
      this._lastY = y;
    });
  };

  onKeydown = (event) => {
    if (event.key === "Escape" && this.overlayOpen) {
      this._closeSheet();
      this._closeIdentity();
    }
  };

  _openSheet(key) {
    this.sheetKey = key;
    this.barHidden = false;
    document.body.classList.add("je-nav-sheet-open");
  }

  _closeSheet() {
    this.sheetKey = null;
    if (!this.identityOpen) {
      document.body.classList.remove("je-nav-sheet-open");
    }
  }

  openIdentity() {
    this.sheetKey = null;
    this.identityOpen = true;
    this.barHidden = false;
    document.body.classList.add("je-nav-sheet-open");
    this._loadIdentityStats();
  }

  _closeIdentity() {
    if (!this.identityOpen) {
      return;
    }
    this.identityOpen = false;
    if (this.sheetKey === null) {
      document.body.classList.remove("je-nav-sheet-open");
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────

  @action
  tabTap(tab, event) {
    event?.preventDefault();
    if (tab.kind === "identity") {
      if (this.identityOpen) {
        this._closeIdentity();
      } else {
        this.openIdentity();
      }
      return;
    }
    this._closeIdentity();
    if (tab.kind === "link") {
      this._closeSheet();
      DiscourseURL.routeTo(tab.resolvedHref);
      return;
    }
    // dropdown or more: toggle the matching sheet
    if (this.sheetKey === tab.key) {
      this._closeSheet();
    } else {
      this._openSheet(tab.key);
    }
  }

  @action
  rowTap(row, event) {
    event?.preventDefault();
    this._closeSheet();
    DiscourseURL.routeTo(row.resolvedHref);
  }

  @action
  closeSheet(event) {
    event?.preventDefault();
    this._closeSheet();
  }

  @action
  closeIdentity(event) {
    event?.preventDefault();
    this._closeIdentity();
  }

  @action
  closeAll(event) {
    event?.preventDefault();
    this._closeSheet();
    this._closeIdentity();
  }

  @action
  identityRowTap(href, event) {
    event?.preventDefault();
    this._closeIdentity();
    DiscourseURL.routeTo(href);
  }

  @action
  moreProfileTap(event) {
    event?.preventDefault();
    this.openIdentity();
  }

  @action
  stop(event) {
    event.stopPropagation();
  }

  <template>
    {{#if this.showBar}}
      <div
        class="je-mnav-root"
        {{didInsert this.setup}}
        {{willDestroy this.teardown}}
      >
        {{! Scrim — mounted always so open/close both transition }}
        <div
          class="je-mnav-scrim {{if this.overlayOpen 'is-open'}}"
          aria-hidden="true"
          {{on "click" this.closeAll}}
        ></div>

        {{! Bottom sheet }}
        <div
          class="je-mnav-sheet {{if this.sheetOpen 'is-open'}}"
          role="dialog"
          aria-modal="true"
          aria-label={{this.sheetTitle}}
          {{on "click" this.stop}}
        >
          <div class="je-mnav-sheet__handle" aria-hidden="true"></div>
          <div class="je-mnav-sheet__head">
            <span class="je-mnav-sheet__title">{{this.sheetTitle}}</span>
            <button
              type="button"
              class="je-mnav-sheet__close"
              aria-label="Close"
              {{on "click" this.closeSheet}}
            >
              {{icon "xmark"}}
            </button>
          </div>
          <div class="je-mnav-sheet__body">
            {{#if this.moreProfileVisible}}
              <button
                type="button"
                class="je-mnav-identity-row"
                {{on "click" this.moreProfileTap}}
              >
                {{avatar this.currentUser imageSize="medium"}}
                <span class="je-mnav-identity-row__text">
                  <span class="je-mnav-identity-row__name">
                    {{this.identityName}}
                  </span>
                  <span class="je-mnav-identity-row__sub">
                    View your profile
                  </span>
                </span>
                {{icon "angle-right"}}
              </button>
            {{/if}}
            {{#each this.sheetGroups key="title" as |group|}}
              <div class="je-mnav-sheet__group">
                {{#if group.hasTitle}}
                  <div class="je-mnav-sheet__group-title">{{group.title}}</div>
                {{/if}}
                {{#each group.rows key="key" as |row|}}
                  <a
                    href={{row.resolvedHref}}
                    class="je-mnav-sheet__row {{if row.isActive 'active'}}"
                    {{on "click" (fn this.rowTap row)}}
                  >
                    {{#if row.icon}}
                      <span class="je-mnav-sheet__row-icon" style={{row.iconStyle}}>
                        {{icon row.icon}}
                      </span>
                    {{/if}}
                    <span class="je-mnav-sheet__row-text">
                      <span class="je-mnav-sheet__row-label">
                        {{row.label}}
                        {{#if row.badge}}
                          <span class="je-mnav__badge">{{row.badge}}</span>
                        {{/if}}
                      </span>
                      {{#if row.subtext}}
                        <span class="je-mnav-sheet__row-subtext">{{row.subtext}}</span>
                      {{/if}}
                    </span>
                    {{icon "angle-right" class="je-mnav-sheet__row-caret"}}
                  </a>
                {{/each}}
              </div>
            {{/each}}
          </div>
        </div>

        {{! Identity sheet (v4) — the mobile hero, one tap away }}
        <div
          class="je-mnav-sheet je-mnav-identity {{if this.identityOpen 'is-open'}}"
          role="dialog"
          aria-modal="true"
          aria-label="Your profile"
          {{on "click" this.stop}}
        >
          <div class="je-mnav-sheet__handle" aria-hidden="true"></div>
          <div class="je-mnav-sheet__head">
            <span class="je-mnav-sheet__title">You</span>
            <button
              type="button"
              class="je-mnav-sheet__close"
              aria-label="Close"
              {{on "click" this.closeIdentity}}
            >
              {{icon "xmark"}}
            </button>
          </div>
          <div class="je-mnav-sheet__body">
            {{#if this.currentUser}}
              <div class="je-mnav-identity__hero">
                <a
                  class="je-mnav-identity__avatar"
                  href={{this.changePhotoHref}}
                  {{on "click" (fn this.identityRowTap this.changePhotoHref)}}
                >
                  {{avatar this.currentUser imageSize="huge"}}
                  <span class="je-mnav-identity__avatar-edit">
                    {{icon "camera"}}
                  </span>
                </a>
                <div class="je-mnav-identity__name">{{this.identityName}}</div>
                <div class="je-mnav-identity__handle">
                  @{{this.currentUser.username}}
                </div>
                <a
                  class="je-mnav-identity__change"
                  href={{this.changePhotoHref}}
                  {{on "click" (fn this.identityRowTap this.changePhotoHref)}}
                >
                  {{icon "camera"}}
                  Change photo
                </a>
              </div>
              {{#if this.statChips.length}}
                <div class="je-mnav-identity__chips">
                  {{#each this.statChips key="key" as |chip|}}
                    <span class="je-mnav-identity__chip">
                      <b>{{chip.value}}</b>
                      {{chip.label}}
                    </span>
                  {{/each}}
                </div>
              {{/if}}
              <a
                class="je-mnav-identity__primary"
                href={{this.identityPrimaryResolved}}
                {{on
                  "click"
                  (fn this.identityRowTap this.identityPrimaryResolved)
                }}
              >
                {{this.identityPrimaryLabel}}
              </a>
              <div class="je-mnav-identity__grid">
                {{#each this.identityRows key="key" as |row|}}
                  <a
                    class="je-mnav-identity__door"
                    href={{row.resolvedHref}}
                    {{on "click" (fn this.identityRowTap row.resolvedHref)}}
                  >
                    <span class="je-mnav-identity__door-icon">
                      {{icon row.icon}}
                    </span>
                    <span class="je-mnav-identity__door-label">
                      {{row.label}}
                    </span>
                  </a>
                {{/each}}
              </div>
            {{/if}}
          </div>
        </div>

        {{! Bottom tab bar }}
        <nav
          class="je-mnav {{if this.barHidden 'is-hidden'}}"
          aria-label="Primary"
        >
          <div class="je-mnav__bar {{if this.showLabels 'has-labels'}}">
            {{#each this.tabs key="key" as |tab|}}
              {{#if tab.resolvedHref}}
                <a
                  href={{tab.resolvedHref}}
                  class="je-mnav__tab
                    {{if tab.isActive 'active'}}
                    {{if tab.emphasis 'is-emphasis'}}"
                  aria-current={{if tab.isActive "page"}}
                  {{on "click" (fn this.tabTap tab)}}
                >
                  <span class="je-mnav__tab-icon" style={{tab.iconStyle}}>
                    {{icon tab.icon}}
                    {{#if tab.badge}}
                      <span class="je-mnav__tab-badge">{{tab.badge}}</span>
                    {{/if}}
                  </span>
                  {{#if this.showLabels}}
                    <span class="je-mnav__tab-label">{{tab.label}}</span>
                  {{/if}}
                </a>
              {{else}}
                <button
                  type="button"
                  class="je-mnav__tab
                    {{if tab.isActive 'active'}}
                    {{if tab.isOpen 'open'}}
                    {{if tab.emphasis 'is-emphasis'}}"
                  aria-expanded="{{tab.isOpen}}"
                  {{on "click" (fn this.tabTap tab)}}
                >
                  <span
                    class="je-mnav__tab-icon {{if tab.avatarUser 'is-avatar'}}"
                    style={{tab.iconStyle}}
                  >
                    {{#if tab.avatarUser}}
                      {{avatar tab.avatarUser imageSize="small"}}
                    {{else}}
                      {{icon tab.icon}}
                    {{/if}}
                    {{#if tab.badge}}
                      <span class="je-mnav__tab-badge">{{tab.badge}}</span>
                    {{/if}}
                    {{#if tab.hasDot}}
                      <span class="je-mnav__tab-dot" aria-hidden="true"></span>
                    {{/if}}
                  </span>
                  {{#if this.showLabels}}
                    <span class="je-mnav__tab-label">{{tab.label}}</span>
                  {{/if}}
                </button>
              {{/if}}
            {{/each}}
          </div>
        </nav>
      </div>
    {{/if}}
  </template>
}
