import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// Decorate the native button; core retains its actions, badges and account tab.
export default class JeNotificationBell extends Component {
  get enabled() {
    return (
      settings.je_nav_notification_bell_enabled && settings.je_nav_you_enabled
    );
  }

  <template>
    {{#if this.enabled}}
      <span aria-hidden="true" class="je-notification-bell">{{dIcon
          "bell"
        }}</span>
    {{/if}}
  </template>
}
