# frozen_string_literal: true
# name: elliepass
# about: ElliePass verification integration for Discourse communities
# version: 1.0.0
# authors: ElliePass
# required_version: 3.0.0

enabled_site_setting :elliepass_enabled
register_svg_icon "arrows-rotate"

add_admin_route "elliepass.admin_navigation", "elliepass", use_new_show_route: true

module ::Elliepass
  PLUGIN_NAME = "elliepass"
end

require_relative "lib/elliepass/debug_logger"
require_relative "lib/elliepass/api_client"
require_relative "lib/elliepass/status_service"
require_relative "lib/elliepass/connection_service"
require_relative "lib/elliepass/engine"
require_relative "lib/elliepass/authorization_service"
require_relative "lib/elliepass/posting_enforcer"
require_relative "lib/elliepass/policy_state_service"

after_initialize do
  connection_settings = %i[
    elliepass_enabled
    elliepass_api_url
    elliepass_community_key
    elliepass_community_secret
  ]

  on(:site_setting_changed) do |name, _old_value, _new_value|
    next if connection_settings.exclude?(name.to_sym)

    Jobs.enqueue(:elliepass_connect)
  end

  NewPostManager.add_handler(100) { |manager| Elliepass::PostingEnforcer.call(manager) }

  Jobs.enqueue_in(10.seconds, :elliepass_connect, startup: true) if SiteSetting.elliepass_enabled
end
