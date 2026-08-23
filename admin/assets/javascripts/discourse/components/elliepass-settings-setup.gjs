import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const FALLBACK_COMMUNITY_ADMIN_URL = "https://elliepass.com/signin?destination=community";

export default class ElliepassSettingsSetup extends Component {
  @service adminPluginNavManager;
  @service adminSiteSettingStore;

  get shouldShow() {
    return this.adminPluginNavManager.currentPlugin?.id === "elliepass";
  }

  get communityAdminUrl() {
    const setting = this.adminSiteSettingStore.get("elliepass_api_url");
    const baseUrl = setting?.buffered?.get("value") ?? setting?.value;

    if (!baseUrl) {
      return FALLBACK_COMMUNITY_ADMIN_URL;
    }

    try {
      const url = new URL(baseUrl);
      url.pathname = "/signin";
      url.search = "?destination=community";
      url.hash = "";
      return url.toString();
    } catch {
      return FALLBACK_COMMUNITY_ADMIN_URL;
    }
  }

  <template>
    {{#if this.shouldShow}}
      <div class="alert alert-info">
        <h3>
          {{i18n "elliepass.admin.settings_setup.title"}}
        </h3>

        <p>
          {{i18n "elliepass.admin.settings_setup.description"}}
        </p>

        <DButton
          @href={{this.communityAdminUrl}}
          @label="elliepass.admin.settings_setup.cta"
          class="btn-default"
          target="_blank"
          rel="noopener noreferrer"
        />
      </div>
    {{/if}}
  </template>
}
