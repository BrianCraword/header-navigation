import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

// ── The sacred timeline (v0.6.0) ─────────────────────────────────────
//
// X's rule: the timeline is never rebuilt out from under you. Thread
// visits are excursions; return is instant, scroll held, counts fresh.
// This service owns the stream state so the index route can be left and
// re-entered without cost, and so the thread view can write engagement
// (a like given, a reply posted) back onto the very card the member
// returns to.
export default class VcFeedState extends Service {
  @tracked items = [];
  @tracked cards = [];
  @tracked hasMore = false;
  @tracked pendingCount = 0;

  scrollY = 0;
  loaded = false;

  hydrate({ items, cards, hasMore }) {
    this.items = items;
    this.cards = cards;
    this.hasMore = hasMore;
    this.loaded = true;
  }

  updateItem(topicId, fn) {
    const item = this.items.find((i) => i.topic_id === topicId);
    if (item) {
      fn(item);
      // Items are plain objects — reassign to notify tracking.
      this.items = [...this.items];
    }
  }

  recordLike(topicId, liked) {
    this.updateItem(topicId, (item) => {
      item.liked = liked;
      item.like_count = Math.max(0, (item.like_count || 0) + (liked ? 1 : -1));
    });
  }

  recordReply(topicId) {
    this.updateItem(topicId, (item) => {
      item.reply_count = (item.reply_count || 0) + 1;
    });
  }

  reset() {
    this.items = [];
    this.cards = [];
    this.hasMore = false;
    this.pendingCount = 0;
    this.scrollY = 0;
    this.loaded = false;
  }
}
