import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { relativeAge } from "discourse/lib/formatter";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

const LIKE_TYPE = 2; // PostActionType.types[:like] — stable core enum

// ── The card (§7 feed-card micropost/titled renderers) ───────────────
//
// Microposts lead with the body; titled posts (the wall is a category
// UNION, §12.1) keep their title as a headline. The heart toggles
// through core's post_actions endpoint so likes on the wall and likes
// in the classic topic view are the SAME like — one engagement system,
// two skins (ADR-F1). Reply routes to the topic (the permalink layer)
// until the Phase 5 slide-over panel exists.
export default class VcFeedItem extends Component {
  @tracked liked = this.args.item.liked;
  @tracked likeCount = this.args.item.like_count;
  @tracked busy = false;
  @tracked clamped = false;

  get item() {
    return this.args.item;
  }

  get cooked() {
    return htmlSafe(this.item.cooked);
  }

  get age() {
    return relativeAge(new Date(this.item.created_at));
  }

  // Long expositions must not swallow the wall: measure once on insert;
  // anything taller than the clamp gets a fade and a "Show more" that
  // NAVIGATES to the thread — X's exact treatment. The wall is the
  // stream; the thread is the reading room.
  @action
  measureBody(el) {
    if (el.scrollHeight > 460) {
      this.clamped = true;
    }
  }

  // Straight to the conversation surface: the classic topic page, with
  // the full Discourse toolkit (docked composer, quotes, edits). The
  // "<- Feed" connector on that page is the road home; the sacred
  // timeline restores the stream on return.
  @action
  openThread() {
    DiscourseURL.routeTo(this.item.url);
  }

  // The whole card is a door (X behavior). Real interactive elements
  // inside — links in the cooked body, usernames, tags, the heart —
  // keep their own behavior; text selection is not a click.
  //
  // composedPath, not target.closest: the like button re-renders when
  // its @tracked state flips, so by the time the click bubbles here the
  // original target can be DETACHED and closest() finds nothing — the
  // bug where hearting a post navigated to it. The composed path is
  // captured at dispatch and immune to re-renders.
  @action
  cardClick(event) {
    const path = event.composedPath?.() || [];
    if (path.some((n) => n.tagName === "A" || n.tagName === "BUTTON")) {
      return;
    }
    if (window.getSelection()?.toString()) {
      return;
    }
    this.openThread();
  }

  @action
  async toggleLike(event) {
    event?.stopPropagation();
    if (this.busy) {
      return;
    }
    this.busy = true;
    const wasLiked = this.liked;
    // Optimistic — revert on failure.
    this.liked = !wasLiked;
    this.likeCount += wasLiked ? -1 : 1;
    try {
      if (wasLiked) {
        await ajax(`/post_actions/${this.item.post_id}.json`, {
          type: "DELETE",
          data: { post_action_type_id: LIKE_TYPE },
        });
      } else {
        await ajax("/post_actions.json", {
          type: "POST",
          data: { id: this.item.post_id, post_action_type_id: LIKE_TYPE },
        });
      }
    } catch (e) {
      this.liked = wasLiked;
      this.likeCount += wasLiked ? 1 : -1;
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <article
      class="vc-feed-item {{if this.item.is_micropost 'is-micropost'}}"
      role="link"
      tabindex="0"
      {{on "click" this.cardClick}}
    >
      <a
        class="vc-feed-item__avatar"
        href="/u/{{this.item.user.username}}"
        data-user-card={{this.item.user.username}}
        aria-label={{this.item.user.username}}
      >
        {{avatar this.item.user imageSize="medium"}}
      </a>

      <div class="vc-feed-item__main">
        <header class="vc-feed-item__header">
          <a
            class="vc-feed-item__author"
            href="/u/{{this.item.user.username}}"
            data-user-card={{this.item.user.username}}
          >
            {{if this.item.user.name this.item.user.name this.item.user.username}}
          </a>
          <span class="vc-feed-item__handle">@{{this.item.user.username}}</span>
          <a class="vc-feed-item__age" href={{this.item.url}}>{{this.age}}</a>
        </header>

        {{#unless this.item.is_micropost}}
          <a class="vc-feed-item__title" href={{this.item.url}}>
            {{this.item.title}}
          </a>
        {{/unless}}

        <div
          class="vc-feed-item__body cooked {{if this.clamped 'is-clamped'}}"
          {{didInsert this.measureBody}}
        >{{this.cooked}}</div>
        {{#if this.clamped}}
          <button
            type="button"
            class="vc-feed-item__show-more"
            {{on "click" this.openThread}}
          >
            {{i18n "vc_feed.show_more"}}
          </button>
        {{/if}}

        {{#if this.item.tags.length}}
          <div class="vc-feed-item__tags">
            {{#each this.item.tags as |tag|}}
              <a class="vc-feed-item__tag" href="/tag/{{tag}}">#{{tag}}</a>
            {{/each}}
          </div>
        {{/if}}

        <footer class="vc-feed-item__actions">
          <button
            type="button"
            class="vc-feed-item__action vc-feed-item__like {{if this.liked 'is-liked'}}"
            {{on "click" this.toggleLike}}
          >
            {{icon (if this.liked "heart" "far-heart")}}
            {{#if this.likeCount}}<span>{{this.likeCount}}</span>{{/if}}
          </button>
          <a class="vc-feed-item__action vc-feed-item__reply" href={{this.item.url}}>
            {{icon "comment"}}
            {{#if this.item.reply_count}}<span>{{this.item.reply_count}}</span>{{/if}}
          </a>
          {{#if this.item.views}}
            <span class="vc-feed-item__action vc-feed-item__views" title="Views">
              {{icon "chart-bar"}}
              <span>{{this.item.views}}</span>
            </span>
          {{/if}}
        </footer>
      </div>
    </article>
  </template>
}
