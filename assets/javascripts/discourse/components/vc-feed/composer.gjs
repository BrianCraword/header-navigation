import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";

// ── The trigger (v0.7.0) — X geometry, core machinery ────────────────
// Desktop: a quiet input-shaped button. Mobile: the floating compose
// FAB (CSS decides which shows). Both open Discourse's REAL composer,
// preset to the wall's compose category — drafts, GIFs, Ask AI,
// uploads, fullscreen all inherent. Title handling lives in the
// vc-feed-core-composer initializer.
export default class VcFeedComposer extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;
  @service site;

  get categoryId() {
    const first = (this.siteSettings.vc_feed_categories || "").split("|")[0];
    return parseInt(first, 10) || undefined;
  }

  @action
  openComposer() {
    this.composer.open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
      categoryId: this.categoryId,
    });
  }

  <template>
    <div class="vc-feed-trigger">
      <div class="vc-feed-trigger__avatar">
        {{avatar this.currentUser imageSize="medium"}}
      </div>
      <button
        type="button"
        class="vc-feed-trigger__cta"
        {{on "click" this.openComposer}}
      >
        {{icon "pencil"}}
        <span class="vc-feed-trigger__cta-label">
          {{i18n "vc_feed.composer_cta"}}
        </span>
        <span class="vc-feed-trigger__cta-chip">
          {{icon "plus"}}
          {{i18n "vc_feed.composer_cta_chip"}}
        </span>
      </button>
    </div>

    <button
      type="button"
      class="vc-feed-fab"
      title={{i18n "vc_feed.composer_placeholder"}}
      {{on "click" this.openComposer}}
    >
      {{icon "plus"}}
    </button>
  </template>
}
