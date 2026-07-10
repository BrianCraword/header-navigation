import RouteTemplate from "ember-route-template";
import VcFeedRail from "../components/vc-feed/rail";
import VcFeedSurface from "../components/vc-feed/surface";

export default RouteTemplate(
  <template>
    <div class="vc-feed-page">
      <div class="vc-feed-page__stream">
        <VcFeedSurface />
      </div>
      <VcFeedRail />
    </div>
  </template>
);
