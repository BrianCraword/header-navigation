import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class VcFeedRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!this.siteSettings.vc_feed_enabled) {
      this.router.replaceWith("discovery.latest");
    }
  }

  // The feed claims its own canvas. Core constrains content to
  // --d-max-width (~1110px) and the left sidebar spends ~300px of it —
  // too narrow for stream + rail. A route-scoped body class widens the
  // wrap ONLY here (X does the same: the timeline ignores the site-wide
  // content width). Everything else on the site keeps core's layout.
  activate() {
    super.activate(...arguments);
    document.body.classList.add("vc-feed-active");
  }

  deactivate() {
    super.deactivate(...arguments);
    document.body.classList.remove("vc-feed-active");
  }

  titleToken() {
    return i18n("vc_feed.title");
  }
}
