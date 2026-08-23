# frozen_string_literal: true

module ::Elliepass
  class PolicyController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token

    def update
      policy =
        params
          .require(:policy)
          .permit(:policy_version, guarded_actions: {}, verification_requirements: {})
          .to_h

      state = PolicyStateService.apply_push(policy, bearer_token)

      render json: { status: "success", policy_version: state.policy_version }
    rescue PolicyStateService::AuthenticationError
      render json: { status: "error", message: "Unauthorized." }, status: :unauthorized
    rescue PolicyStateService::StalePolicyError
      render json: {
               status: "error",
               message: "Stale policy version.",
               policy_version: IntegrationState.current.policy_version,
             },
             status: :conflict
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { status: "error", message: e.message }, status: :unprocessable_entity
    rescue PolicyStateService::PolicyConflictError
      render json: {
               status: "error",
               message: "Policy version conflict.",
               policy_version: IntegrationState.current.policy_version,
             },
             status: :conflict
    end

    private

    def bearer_token
      header = request.headers["Authorization"].to_s

      return nil unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip.presence
    end
  end
end
