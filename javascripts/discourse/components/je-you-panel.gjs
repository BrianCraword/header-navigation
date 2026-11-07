import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import UserMenuProfileTabContent from "discourse/components/user-menu/profile-tab-content";
import DiscourseURL from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  itemVisible,
  navigationAllowed,
  orderedItems,
  resolveHref,
} from "../lib/je-nav-core.js";
import { identityClarityRows } from "../lib/je-nav-identity-clarity.js";
import {
  modifiedClick,
  withInvitations,
  youSections,
} from "../lib/je-nav-you-model.js";

export default class JeYouPanel extends Component {
  @service currentUser;
  @service router;
  @service composer;
  @service dialog;

  @tracked accountOpen = false;
  #element;
  #invoker;
  #replaying = false;
  #pending = false;
  #generation = 0;

  #openRequest = (event) => {
    if (!this.enabled || !this.#element) {
      return;
    }
    event.preventDefault();
    if (this.#pending) {
      return;
    }
    this.#generation++;
    this.#invoker = document.activeElement;
    this.accountOpen = false;
    if (this.datingPrimary) {
      this.datingNextStep?.refresh();
    }
    if (!this.#element.open) {
      this.#element.showModal();
    }
    requestAnimationFrame(() =>
      this.#element?.querySelector(".je-you__close")?.focus()
    );
  };
  #routeChanged = () => {
    this.#generation++;
    this.#close(false);
  };
  #nativeClick = async (event) => {
    if (this.#replaying) {
      return;
    }
    const control = event.target.closest("a[href], button");
    if (!control || !control.closest(".je-you__native")) {
      return;
    }
    const sessionAction = !!control.closest(
      ".logout, .enable-anonymous, .disable-anonymous"
    );
    const href = control.getAttribute("href");
    if (!sessionAction && !href) {
      return;
    }
    if (!sessionAction && modifiedClick(event)) {
      return;
    }
    event.preventDefault();
    event.stopImmediatePropagation();
    if (this.#pending) {
      return;
    }
    this.#pending = true;
    const generation = this.#generation;
    const route = this.router.currentURL;
    const user = this.currentUser.id;
    this.#close();
    try {
      // Session-changing native actions reload without the router's composer handling.
      if (
        sessionAction &&
        this.composer.model &&
        this.composer.model.composeState !== "closed"
      ) {
        this.dialog.alert(this.labels.finish_draft);
        return;
      }
      if (!(await navigationAllowed(href || "/session"))) {
        return;
      }
      if (
        generation !== this.#generation ||
        route !== this.router.currentURL ||
        user !== this.currentUser?.id ||
        !control.isConnected
      ) {
        return;
      }
      this.#replaying = true;
      try {
        control.click();
      } finally {
        this.#replaying = false;
      }
    } finally {
      this.#pending = false;
    }
  };

  get enabled() {
    return settings.je_nav_you_enabled && this.currentUser;
  }

  get labels() {
    return Object.fromEntries(
      [
        "title",
        "close",
        "back",
        "account_controls",
        "activity",
        "profiles",
        "account",
        "links",
        "invitations",
        "private_messages",
        "change_photo",
        "open_dating",
        "finish_draft",
      ].map((key) => [key, i18n(themePrefix(`je_nav.you.${key}`))])
    );
  }

  get sections() {
    const clarityLabels = Object.fromEntries(
      [
        "community_profile",
        "badge_catalog",
        "activity",
        "drafts",
        "my_badges",
      ].map((key) => [key, i18n(themePrefix(`je_nav.identity.${key}`))])
    );
    let rows = orderedItems(settings.je_nav_identity_links || []);
    if (settings.je_nav_identity_clarity_enabled) {
      rows = identityClarityRows(
        rows,
        this.currentUser,
        clarityLabels,
        window.location.origin
      );
    }
    rows = withInvitations(
      rows,
      this.currentUser,
      this.labels.invitations,
      window.location.origin
    );
    rows = rows
      .filter((row) => itemVisible(row, this.currentUser))
      .map((row, index) => ({
        ...row,
        key: `${index}:${row.href}`,
        resolvedHref: resolveHref(row.href, this.currentUser),
      }));
    return youSections(
      rows,
      this.currentUser,
      this.labels,
      window.location.origin
    );
  }

  get name() {
    return this.currentUser.name || this.currentUser.username;
  }

  get photoHref() {
    return resolveHref("/my/preferences/account", this.currentUser);
  }

  get datingNextStep() {
    return getOwner(this).lookup("service:vc-dating-next-step");
  }

  get datingPrimary() {
    return (
      (settings.je_nav_identity_primary_href || "/matchmaking").replace(
        /\/$/,
        ""
      ) === "/matchmaking"
    );
  }

  get primaryHref() {
    return this.datingPrimary
      ? this.datingNextStep?.peripheral.action_url || "/matchmaking"
      : resolveHref(settings.je_nav_identity_primary_href, this.currentUser);
  }

  get primaryLabel() {
    return this.datingPrimary
      ? this.datingNextStep?.peripheral.label || this.labels.open_dating
      : settings.je_nav_identity_primary_label;
  }

  @action
  setup(element) {
    this.#element = element;
    element.addEventListener("cancel", this.cancel);
    element.addEventListener("click", this.backdrop);
    document.addEventListener("je-nav:identity:open", this.#openRequest);
    element.addEventListener("click", this.#nativeClick, true);
    this.router.on("routeDidChange", this.#routeChanged);
  }

  @action
  teardown() {
    this.#generation++;
    document.removeEventListener("je-nav:identity:open", this.#openRequest);
    this.#element?.removeEventListener("click", this.#nativeClick, true);
    this.router.off("routeDidChange", this.#routeChanged);
    this.#close(false);
    this.#element?.removeEventListener("cancel", this.cancel);
    this.#element?.removeEventListener("click", this.backdrop);
    this.#element = null;
  }

  @action
  close() {
    this.#generation++;
    this.#close();
  }

  @action
  closeForNativeModal() {
    this.#close(false);
  }

  @action
  cancel(event) {
    event.preventDefault();
    this.close();
  }

  @action
  backdrop(event) {
    if (event.target === this.#element) {
      this.close();
    }
  }

  @action
  account() {
    this.accountOpen = true;
    requestAnimationFrame(() =>
      this.#element?.querySelector(".je-you__back")?.focus()
    );
  }

  @action
  back() {
    this.accountOpen = false;
    requestAnimationFrame(() =>
      this.#element?.querySelector(".je-you__account-trigger")?.focus()
    );
  }

  @action
  async navigate(href, event) {
    if (modifiedClick(event)) {
      return;
    }
    event.preventDefault();
    this.#close();
    if (await navigationAllowed(href)) {
      DiscourseURL.routeTo(href);
    }
  }

  #close(restoreFocus = true) {
    this.#element?.close();
    if (restoreFocus && this.#invoker?.isConnected) {
      this.#invoker.focus();
    }
  }

  <template>
    {{#if this.enabled}}
      <dialog
        aria-labelledby="je-you-title"
        class="je-you"
        {{didInsert this.setup}}
        {{willDestroy this.teardown}}
      >
        <div class="je-you__frame">
          <header class="je-you__head">
            {{#if this.accountOpen}}<button
                class="je-you__back"
                type="button"
                {{on "click" this.back}}
              >{{this.labels.back}}</button>{{/if}}
            <h2 id="je-you-title">{{if
                this.accountOpen
                this.labels.account_controls
                this.labels.title
              }}</h2>
            <button
              aria-label={{this.labels.close}}
              class="je-you__close"
              type="button"
              {{on "click" this.close}}
            >{{dIcon "xmark"}}</button>
          </header>
          <div class="je-you__body">
            {{#if this.accountOpen}}
              <div class="je-you__native">
                <UserMenuProfileTabContent
                  @ariaLabelledby="je-you-title"
                  @class="je-you__native-list"
                  @closeUserMenu={{this.closeForNativeModal}}
                />
              </div>
            {{else}}
              <div class="je-you__identity">
                <a
                  aria-label={{this.labels.change_photo}}
                  href={{this.photoHref}}
                  {{on "click" (fn this.navigate this.photoHref)}}
                >{{dAvatar this.currentUser imageSize="large"}}</a>
                <div><strong>{{this.name}}</strong><span
                  >@{{this.currentUser.username}}</span></div>
                <a
                  href={{this.photoHref}}
                  {{on "click" (fn this.navigate this.photoHref)}}
                >{{this.labels.change_photo}}</a>
              </div>
              {{#if this.primaryHref}}<a
                  class="je-you__primary"
                  href={{this.primaryHref}}
                  {{on "click" (fn this.navigate this.primaryHref)}}
                >{{this.primaryLabel}}</a>{{/if}}
              {{#each this.sections key="key" as |group|}}
                <section
                  aria-labelledby={{concat "je-you-" group.key}}
                  class="je-you__section"
                >
                  <h3 id={{concat "je-you-" group.key}}>{{group.title}}</h3>
                  <ul>
                    {{#each group.rows key="key" as |row|}}
                      <li><a
                          href={{row.resolvedHref}}
                          {{on "click" (fn this.navigate row.resolvedHref)}}
                        >{{dIcon (if row.icon row.icon "angle-right")}}<span
                          >{{row.label}}</span>{{#if row.draftCount}}<span
                              class="je-you__count"
                            >{{row.draftCount}}</span>{{/if}}</a></li>
                    {{/each}}
                    {{#if (eq group.key "account")}}<li><button
                          class="je-you__account-trigger"
                          type="button"
                          {{on "click" this.account}}
                        >{{dIcon "gear"}}<span
                          >{{this.labels.account_controls}}</span>{{dIcon
                            "angle-right"
                          }}</button></li>{{/if}}
                  </ul>
                </section>
              {{/each}}
            {{/if}}
          </div>
        </div>
      </dialog>
    {{/if}}
  </template>
}
