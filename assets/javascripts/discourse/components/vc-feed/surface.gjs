import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import { dismissCard, fetchFeedCards } from "../../lib/feed-cards";
import VcFeedComposer from "./composer";
import VcFeedItem from "./item";
import VcFeedProgramCard from "./program-card";

// ── The wall (§7 feed-stream.gjs) ─────────────────────────────────────
//
// Owns the stream state so the three writers — initial load, optimistic
// insert from the composer, and the MessageBus "new posts" refresh —
// converge on ONE items array with ONE dedupe rule (topic_id). The
// compose endpoint returns exactly a stream item (plugin contract), so
// no reconciliation special cases exist by design.
export default class VcFeedSurface extends Component {
  @service currentUser;
  @service messageBus;
  @service siteSettings;
  @service vcFeedState;

  @tracked loading = true;
  @tracked loadingMore = false;

  #observer;

  constructor() {
    super(...arguments);
    if (this.vcFeedState.loaded) {
      // The sacred timeline: instant restore, scroll held, then a
      // silent head refresh so anything that happened while away
      // merges in without moving the member.
      this.loading = false;
      requestAnimationFrame(() =>
        window.scrollTo(0, this.vcFeedState.scrollY || 0)
      );
      this.showPending();
    } else {
      this.loadInitial();
    }
    this.messageBus.subscribe("/vc-feed/stream", this.onNewPost);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.vcFeedState.scrollY = window.scrollY;
    this.messageBus.unsubscribe("/vc-feed/stream", this.onNewPost);
    this.#observer?.disconnect();
  }

  get items() {
    return this.vcFeedState.items;
  }

  get cards() {
    return this.vcFeedState.cards;
  }

  get hasMore() {
    return this.vcFeedState.hasMore;
  }

  get pendingCount() {
    return this.vcFeedState.pendingCount;
  }

  @bind
  onNewPost(data) {
    // Our own optimistic insert already holds this id — don't count it.
    if (this.items.some((i) => i.topic_id === data.topic_id)) {
      return;
    }
    this.vcFeedState.pendingCount++;
  }

  async loadInitial() {
    this.loading = true;
    try {
      // Stream and cards race in parallel; neither blocks the other, and
      // a card failure costs nothing (ADR-F3 lives in fetchFeedCards).
      const [response, cards] = await Promise.all([
        ajax("/vc-feed/stream.json"),
        fetchFeedCards(),
      ]);
      this.vcFeedState.hydrate({
        items: response.items,
        cards,
        hasMore: response.has_more,
      });
    } catch {
      this.vcFeedState.hydrate({ items: [], cards: [], hasMore: false });
    } finally {
      this.loading = false;
    }
  }

  // ── The interleaver (§5 rules, client half) ─────────────────────────
  // Merge program cards into the member stream by timestamp, but never
  // closer than `feed_card_spacing` member posts apart — the wall's
  // rhythm guarantee. Pinned cards lead. Cards older than the loaded
  // window wait at the bottom edge and surface as scrolling reaches
  // their era.
  get renderList() {
    const spacing = this.siteSettings?.feed_card_spacing ?? 3;
    const out = [];
    const queue = [...this.cards]; // already ts-desc sorted

    for (const card of queue.filter((c) => c.pin && c.pin !== "none")) {
      out.push({ kind: "card", card });
    }
    const rest = queue.filter((c) => !c.pin || c.pin === "none");

    let sinceCard = 0;
    let next = rest.shift();

    for (const item of this.items) {
      if (
        next &&
        sinceCard >= spacing &&
        next._ts >= new Date(item.created_at).getTime()
      ) {
        out.push({ kind: "card", card: next });
        next = rest.shift();
        sinceCard = 0;
      }
      out.push({ kind: "post", item });
      sinceCard++;
    }

    // End of loaded window: flush a due card only if spacing allows and
    // there is no more stream to come (otherwise it waits for loadMore).
    if (next && !this.hasMore && sinceCard >= spacing) {
      out.push({ kind: "card", card: next });
    }

    return out;
  }

  @action
  dismissCard(card) {
    dismissCard(card);
    this.vcFeedState.cards = this.cards.filter((c) => c.id !== card.id);
  }

  @action
  async showPending() {
    // Head refetch + merge-above: scroll position is sacred (§6.5 —
    // the pill never yanks the member down the page).
    try {
      const response = await ajax("/vc-feed/stream.json");
      const known = new Set(this.items.map((i) => i.topic_id));
      const fresh = response.items.filter((i) => !known.has(i.topic_id));
      this.vcFeedState.items = [...fresh, ...this.items];
      this.vcFeedState.pendingCount = 0;
    } catch {
      // Quiet failure; the pill remains and the member can retry.
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore || this.items.length === 0) {
      return;
    }
    this.loadingMore = true;
    try {
      const last = this.items[this.items.length - 1];
      const response = await ajax("/vc-feed/stream.json", {
        data: { before: last.topic_id },
      });
      const known = new Set(this.items.map((i) => i.topic_id));
      this.vcFeedState.items = [
        ...this.items,
        ...response.items.filter((i) => !known.has(i.topic_id)),
      ];
      this.vcFeedState.hasMore = response.has_more;
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  onPosted(item) {
    // Optimistic insert — byte-identical to a stream item by contract.
    this.vcFeedState.items = [item, ...this.items];
  }

  @action
  setupSentinel(element) {
    this.#observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          this.loadMore();
        }
      },
      { rootMargin: "600px" }
    );
    this.#observer.observe(element);
  }

  <template>
    <div class="vc-feed">
      <header class="vc-feed-header">
        <h2 class="vc-feed-header__title">{{i18n "vc_feed.header"}}</h2>
        <nav class="vc-feed-header__tabs">
          <span class="vc-feed-header__tab is-active">{{i18n "vc_feed.tabs.latest"}}</span>
        </nav>
      </header>

      {{#if this.currentUser.can_vc_feed_post}}
        <VcFeedComposer @onPosted={{this.onPosted}} />
      {{/if}}

      {{#if this.pendingCount}}
        <button
          type="button"
          class="vc-feed__pill"
          {{on "click" this.showPending}}
        >
          {{i18n "vc_feed.new_posts_pill" count=this.pendingCount}}
        </button>
      {{/if}}

      {{#if this.loading}}
        <div class="vc-feed__loading"><div class="spinner" /></div>
      {{else if this.items.length}}
        <div class="vc-feed__stream">
          {{#each this.renderList as |entry|}}
            {{#if (eq entry.kind "card")}}
              <VcFeedProgramCard
                @card={{entry.card}}
                @onDismiss={{this.dismissCard}}
              />
            {{else}}
              <VcFeedItem @item={{entry.item}} />
            {{/if}}
          {{/each}}
        </div>
        {{#if this.hasMore}}
          <div class="vc-feed__sentinel" {{didInsert this.setupSentinel}}>
            {{#if this.loadingMore}}<div class="spinner small" />{{/if}}
          </div>
        {{/if}}
      {{else}}
        <div class="vc-feed__empty">{{i18n "vc_feed.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
