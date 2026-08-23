# frozen_string_literal: true

module ::Elliepass
  class PolicyController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def update
        policy =
            params.require(:policy).permit(
            :policy_version,
            guarded_actions: {},
            verification_requirements: {},
            ).to_h

        state =
            PolicyStateService.apply_push(
            policy,
            bearer_token,
            )

        render json: {
            status: "success",
            policy_version: state.policy_version,
        }
    rescue PolicyStateService::AuthenticationError
        render json: {
            status: "error",
            message: "Unauthorized.",
        }, status: 401
    rescue PolicyStateService::StalePolicyError
        render json: {
            status: "error",
            message: "Stale policy version.",
            policy_version:
            IntegrationState.current.policy_version,
        }, status: 409
    rescue ActionController::ParameterMissing, ArgumentError => e
        render json: {
            status: "error",
            message: e.message,
        }, status: 422
    rescue PolicyStateService::PolicyConflictError
        render json: {
            status: "error",
            message: "Policy version conflict.",
            policy_version:
            IntegrationState.current.policy_version,
        }, status: 409
    end

    private

    def bearer_token
      header =
        request.headers["Authorization"].to_s

      return nil unless header.start_with?(
        "Bearer "
      )

      header.delete_prefix(
        "Bearer "
      ).strip.presence
    end
  end
end
