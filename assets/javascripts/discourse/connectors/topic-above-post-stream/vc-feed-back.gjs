import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The road home (X's back affordance, extended to the classic view):
// topics living in the wall's categories get a "<- Feed" link above the
// post stream. Injected via a documented plugin outlet — Tier 1; the
// topic page itself is untouched.
export default class VcFeedBack extends Component {
  @service siteSettings;

  get show() {
    if (!this.siteSettings.vc_feed_enabled) {
      return false;
    }
    const ids = (this.siteSettings.vc_feed_categories || "")
      .split("|")
      .map((v) => parseInt(v, 10));
    return ids.includes(this.args.outletArgs?.model?.category_id);
  }

  <template>
    {{#if this.show}}
      <a class="vc-feed-back" href="/feed">
        {{icon "arrow-left"}}
        {{i18n "vc_feed.back_to_feed"}}
      </a>
    {{/if}}
  </template>
}
