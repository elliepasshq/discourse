import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import moment from "moment";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const CREDENTIAL_SETTINGS = [
  "elliepass_api_url",
  "elliepass_community_key",
  "elliepass_community_secret",
];

export default class ElliepassConnectionStatus extends Component {
  @service adminPluginNavManager;
  @service adminSiteSettingStore;
  @service currentUser;

  @tracked connection;
  @tracked loading = true;
  @tracked testing = false;
  @tracked feedback;
  @tracked requestFailed = false;

  refreshTimer;

  constructor() {
    super(...arguments);
    if (this.shouldShow) {
      this.loadStatus();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.refreshTimer);
  }

  get shouldShow() {
    return this.adminPluginNavManager.currentPlugin?.id === "elliepass";
  }

  get credentialSettings() {
    return CREDENTIAL_SETTINGS.map((name) =>
      this.adminSiteSettingStore.get(name)
    ).filter(Boolean);
  }

  get savedCredentials() {
    return this.credentialSettings
      .map((setting) => setting.value ?? "")
      .join("\u0000");
  }

  get credentialsSaving() {
    return this.credentialSettings.some((setting) => setting.isSaving);
  }

  get status() {
    return this.connection?.status || "not_checked";
  }

  get isConnected() {
    return this.status === "connected";
  }

  get isFailed() {
    return ["failed", "unknown"].includes(this.status);
  }

  get isNotConfigured() {
    return this.status === "not_configured";
  }

  get statusClass() {
    if (this.isConnected) {
      return "alert-success";
    }

    if (this.isFailed || this.requestFailed) {
      return "alert-error";
    }

    return "alert-info";
  }

  get statusIcon() {
    if (this.isConnected) {
      return "check";
    }

    if (this.isFailed || this.requestFailed) {
      return "xmark";
    }
  }

  get statusLabel() {
    if (this.requestFailed) {
      return i18n("elliepass.admin.connection.status_unavailable");
    }

    return i18n(`elliepass.admin.connection.statuses.${this.status}`);
  }

  get statusMessage() {
    if (this.isNotConfigured) {
      return i18n("elliepass.admin.connection.not_configured_help");
    }

    return this.connection?.message;
  }

  get testDisabled() {
    return this.loading || this.isNotConfigured;
  }

  @action
  formatTimestamp(value) {
    if (!value) {
      return null;
    }

    const timezone =
      this.currentUser?.user_option?.timezone || moment.tz.guess() || "UTC";

    return moment.tz(value, timezone).format("MMMM D, YYYY [at] h:mm A z");
  }

  @action
  async loadStatus() {
    this.loading = true;

    try {
      this.connection = await ajax("/elliepass/admin/connection");
      this.requestFailed = false;
    } catch {
      this.requestFailed = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  credentialsSaved() {
    if (this.credentialsSaving) {
      return;
    }

    cancel(this.refreshTimer);
    this.refreshTimer = later(this, this.loadStatus, 1500);
  }

  @action
  async testConnection() {
    this.testing = true;
    this.feedback = null;

    try {
      await ajax("/elliepass/admin/connection/test", { type: "POST" });
    } catch {
      // The canonical GET below supplies the authoritative result, including
      // failure details persisted by ConnectionService.
    }

    await this.loadStatus();
    this.feedback = this.isConnected ? "success" : "failed";
    this.testing = false;
  }

  <template>
    {{#if this.shouldShow}}
      <section
        class="elliepass-connection"
        {{didUpdate
          this.credentialsSaved
          this.savedCredentials
          this.credentialsSaving
        }}
      >
        <DPageSubheader @titleLabel={{i18n "elliepass.admin.connection.title"}} />

        <DConditionalLoadingSpinner @condition={{this.loading}}>
          <div class="alert {{this.statusClass}}">
            {{#if this.statusIcon}}
              {{dIcon this.statusIcon}}
            {{/if}}
            <strong>{{this.statusLabel}}</strong>

            {{#if this.statusMessage}}
              <p>{{this.statusMessage}}</p>
            {{/if}}
          </div>

          {{#if this.connection.last_checked_at}}
            <p>
              <strong>{{i18n "elliepass.admin.connection.last_checked_at"}}:</strong>
              {{this.formatTimestamp this.connection.last_checked_at}}
            </p>
          {{/if}}

          {{#if this.connection.last_success_at}}
            <p>
              <strong>{{i18n "elliepass.admin.connection.last_success_at"}}:</strong>
              {{this.formatTimestamp this.connection.last_success_at}}
            </p>
          {{/if}}

          {{#if this.feedback}}
            {{#if this.isConnected}}
              <p class="alert alert-success">
                {{i18n "elliepass.admin.connection.test_success"}}
              </p>
            {{else}}
              <p class="alert alert-error">
                {{i18n "elliepass.admin.connection.test_failed"}}
              </p>
            {{/if}}
          {{/if}}

          <DButton
            @action={{this.testConnection}}
            @disabled={{this.testDisabled}}
            @icon="arrows-rotate"
            @isLoading={{this.testing}}
            @label="elliepass.admin.connection.test"
            class="btn-primary"
            data-test-elliepass-test-connection
          />
        </DConditionalLoadingSpinner>
      </section>
    {{/if}}
  </template>
}
