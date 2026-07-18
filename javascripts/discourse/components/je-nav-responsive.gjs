import Component from "@glimmer/component";
import JeNav from "./je-nav/je-nav";
import JeNavMobile from "./je-nav-mobile/je-nav-mobile";

// Both components remain mounted at the outlet level, but only the component
// matching the tracked viewport renders its root element. This keeps viewport
// reads inside Ember's autotracking context and guarantees lifecycle cleanup
// when a resize crosses the 40rem breakpoint.
export default class JeNavResponsive extends Component {
  <template>
    <JeNav />
    <JeNavMobile />
  </template>
}
