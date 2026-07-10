import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

// ── Program card (§14 lifecycle, one renderer for all v1 types) ──────
//
// Deliberately generic: headline + context line + optional meter + CTA.
// Type-specific richness (scene art, live standings) belongs to later
// phases; v1 proves the interleaving rhythm. Unknown types never reach
// this component — the surface filters them (forward compatibility).
const TYPE_ICONS = {
  campaign_scene: "book-bible",
  trivia_contest: "trophy",
};

export default class VcFeedProgramCard extends Component {
  get card() {
    return this.args.card;
  }

  get cardIcon() {
    return TYPE_ICONS[this.card.type] || "star";
  }

  get headline() {
    const p = this.card.payload || {};
    if (this.card.type === "campaign_scene") {
      return p.season_title || p.run_name;
    }
    return p.name;
  }

  get contextLine() {
    const p = this.card.payload || {};
    if (this.card.type === "campaign_scene") {
      if (p.walked) {
        return i18n("vc_feed.cards.campaign_walked", {
          walked: p.scenes_walked,
          count: p.scene_count,
        });
      }
      return i18n("vc_feed.cards.campaign_open", {
        walked: p.scenes_walked,
        count: p.scene_count,
      });
    }
    if (p.status === "completed") {
      return i18n("vc_feed.cards.trivia_completed");
    }
    return p.entered
      ? i18n("vc_feed.cards.trivia_entered", { day: p.day })
      : i18n("vc_feed.cards.trivia_open", { day: p.day });
  }

  get meterPercent() {
    const p = this.card.payload || {};
    if (this.card.type === "campaign_scene" && p.light_level != null) {
      return Math.max(0, Math.min(100, p.light_level));
    }
    return null;
  }

  @action
  dismiss() {
    this.args.onDismiss?.(this.card);
  }

  <template>
    <article
      class="vc-feed-program-card vc-feed-program-card--{{this.card.type}} is-{{this.card.state}}"
    >
      <div class="vc-feed-program-card__icon">{{icon this.cardIcon}}</div>

      <div class="vc-feed-program-card__main">
        <div class="vc-feed-program-card__headline">{{this.headline}}</div>
        <div class="vc-feed-program-card__context">{{this.contextLine}}</div>

        {{#if this.meterPercent}}
          <div class="vc-feed-program-card__meter">
            <div
              class="vc-feed-program-card__meter-fill"
              style="width: {{this.meterPercent}}%"
            ></div>
          </div>
        {{/if}}

        <a class="btn btn-primary vc-feed-program-card__cta" href={{this.card.cta.href}}>
          {{this.card.cta.label}}
        </a>
      </div>

      {{#if this.card.dismissible}}
        <button
          type="button"
          class="vc-feed-program-card__dismiss"
          title={{i18n "vc_feed.cards.dismiss"}}
          {{on "click" this.dismiss}}
        >
          {{icon "xmark"}}
        </button>
      {{/if}}
    </article>
  </template>
}
