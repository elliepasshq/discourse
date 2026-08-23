# frozen_string_literal: true

module ::Elliepass
  class AdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    skip_before_action :check_xhr
    before_action :ensure_admin
    def show
      connection = ConnectionService.status

      status = ERB::Util.html_escape(connection["status"].to_s.humanize)
      message = ERB::Util.html_escape(connection["message"].to_s)
      format_time =
        lambda do |value|
          next "Never" if value.blank?

          time_zone =
            current_user&.user_option&.timezone.presence || SiteSetting.default_timezone.presence ||
              "UTC"

          Time.parse(value).in_time_zone(time_zone).strftime("%B %-d, %Y at %-I:%M %p %Z")
        end

      last_checked = ERB::Util.html_escape(format_time.call(connection["last_checked_at"]))

      last_success = ERB::Util.html_escape(format_time.call(connection["last_success_at"]))

      render html: <<~HTML.html_safe
        <div style="max-width:800px;margin:40px auto;font-family:sans-serif;">
          <h1>ElliePass Connection</h1>

          <p><strong>Status:</strong> #{status}</p>
          <p><strong>Message:</strong> #{message}</p>
          <p><strong>Last checked:</strong> #{last_checked}</p>
          <p><strong>Last successful connection:</strong> #{last_success}</p>

          <form action="/elliepass/admin/connection/test" method="post">
            <input
              type="hidden"
              name="authenticity_token"
              value="#{form_authenticity_token}"
            >

            <button
              type="submit"
              style="padding:8px 14px;cursor:pointer;"
            >
              Test Connection
            </button>
          </form>

          <p style="margin-top:24px;">
            Connection credentials are configured in
            <strong>Admin → Plugins → ElliePass → Settings</strong>.
          </p>
        </div>
      HTML
    end

    def status
      render json: ConnectionService.status
    end

    def test_connection
      ConnectionService.connect

      redirect_to "/elliepass/admin"
    end
  end
end
