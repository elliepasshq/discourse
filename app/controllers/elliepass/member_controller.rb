# frozen_string_literal: true

module ::Elliepass
  class MemberController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def invalidate
      PolicyStateService.authenticate_push_token(bearer_token)

      external_user_id = params.require(:external_user_id).to_s

      user = User.find_by(id: external_user_id)

      if user.nil?
        render json: { status: "not_found" }, status: :not_found

        return
      end

      AuthorizationService.clear(user)

      DebugLogger.log(
        "authorization_cache_invalidated",
        { user_id: user.id, username: user.username },
      )

      render json: { status: "success" }
    rescue PolicyStateService::AuthenticationError
      render json: { status: "error", message: "Unauthorized." }, status: :unauthorized
    rescue ActionController::ParameterMissing => e
      render json: { status: "error", message: e.message }, status: :unprocessable_entity
    end

    private

    def bearer_token
      header = request.headers["Authorization"].to_s

      return nil unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip.presence
    end
  end
end
