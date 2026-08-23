# frozen_string_literal: true

module ::Elliepass
  class VerificationController < ::ApplicationController
    LOCATION_FAILURE_REASONS = %w[
      current_location_required
      current_location_unavailable
      current_location_expired
      current_location_country_mismatch
      current_location_region_mismatch
      id_verified_location_required
    ].freeze

    requires_plugin PLUGIN_NAME
    requires_login

    layout "no_ember"

    skip_before_action :check_xhr, only: [:start, :complete]

    def start
      remember_return_path
      # Clear only the current-location authorization snapshot before
      # starting ElliePass verification.
      #
      # ElliePass may capture a fresh current location early in the flow,
      # before Human/Identity/Age verification finishes. If the member
      # abandons the flow after location is captured, the normal completion
      # callback will never run to clear Discourse's caches.
      #
      # Clearing the location snapshot here ensures the next guarded action
      # re-reads the authoritative current-location state from ElliePass.
      #
      # Do NOT clear the durable snapshot here. Existing Human, Identity,
      # Age, and ID-verified-location results remain valid and reusable.
      AuthorizationService.clear_location(
        current_user,
      )
      
      return_url =
        "#{Discourse.base_url}/elliepass/verify/complete"

      result =
        ApiClient.start_verification(
          current_user,
          return_url: return_url,
        )

      if result["qualified"] == true
        AuthorizationService.clear(
          current_user,
        )

        redirect_back_to_community
        return
      end

      url =
        result["checkout_url"].presence ||
          result["verification_url"].presence

      if url.present?
        redirect_to url, allow_other_host: true
        return
      end

      Rails.logger.error(
        "[ElliePass] Verification start failed " \
        "user_id=#{current_user.id} " \
        "reason=#{result["reason"].inspect}"
      )

      render_error_page
    rescue ApiClient::Error => e
      Rails.logger.error(
        "[ElliePass] Verification API error " \
        "user_id=#{current_user&.id} " \
        "error=#{e.message.inspect}"
      )

      render_error_page
    end

    def complete
      AuthorizationService.clear(
        current_user,
      )

      DebugLogger.log(
        "authorization_cache_cleared_after_verification",
        {
          user_id: current_user.id,
          username: current_user.username,
        },
      )

      result =
        params[:elliepass_result].to_s

      reason =
        params[:elliepass_reason].to_s

      if result == "location_failed" &&
        LOCATION_FAILURE_REASONS.include?(reason)
        redirect_back_to_community(
          elliepass_result: "location_failed",
          elliepass_reason: reason,
        )

        return
      end

      redirect_back_to_community
    end

    private

    def remember_return_path
      requested_path =
        params[:return_to].to_s

      return if requested_path.blank?

      session[:elliepass_return_path] =
        safe_return_path(requested_path)
    end

    def safe_return_path(path)
      return "/" unless path.start_with?("/")
      return "/" if path.start_with?("//")
      return "/" if path.include?("\n") || path.include?("\r")

      path
    end

    def community_return_path
      safe_return_path(
        session[:elliepass_return_path].presence || "/"
      )
    end

    def redirect_back_to_community(
      result_params = {}
    )
      path =
        community_return_path

      session.delete(
        :elliepass_return_path
      )

      if result_params.present?
        path =
          append_result_params(
            path,
            result_params,
          )
      end

      redirect_to path
    end

    def append_result_params(
      path,
      result_params
    )
      path_without_fragment,
        fragment =
          path.split("#", 2)

      separator =
        path_without_fragment.include?("?") ?
          "&" :
          "?"

      query =
        Rack::Utils.build_query(
          result_params
        )

      result =
        "#{path_without_fragment}#{separator}#{query}"

      if fragment.present?
        result =
          "#{result}##{fragment}"
      end

      result
    end

    def render_error_page
      @elliepass_return_path =
        community_return_path

      render(
        template: "elliepass/verification/error",
        status: :service_unavailable,
      )
    end
  end
end