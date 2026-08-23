# frozen_string_literal: true

require "digest"

module Elliepass
  class PolicyStateService
    class AuthenticationError < StandardError
    end
    class StalePolicyError < StandardError
    end
    class PolicyConflictError < StandardError
    end

    class << self
      def store_connect_response(response)
        policy = response["policy"] || {}
        push_token = response["push_token"]

        raise ArgumentError, "Missing ElliePass policy" if policy.blank?
        raise ArgumentError, "Missing ElliePass push token" if push_token.blank?

        state = IntegrationState.current

        state.update!(
          policy_version: policy["policy_version"].to_i,
          guarded_actions: policy["guarded_actions"] || {},
          verification_requirements: policy["verification_requirements"] || {},
          push_token_hash: Digest::SHA256.hexdigest(push_token),
          policy_synced_at: Time.current,
        )

        DebugLogger.log(
          "policy_initial_sync",
          { policy_version: state.policy_version, guarded_actions: state.guarded_actions },
        )

        state
      end

      def apply_push(policy, push_token)
        state = IntegrationState.current

        authenticate_push_token!(state, push_token)

        incoming_version = policy["policy_version"].to_i

        raise ArgumentError, "Missing policy version" if incoming_version <= 0

        current_version = state.policy_version.to_i

        if incoming_version < current_version
          raise StalePolicyError,
                "Policy version #{incoming_version} is older than #{current_version}"
        end

        if incoming_version == current_version
          same_policy =
            state.guarded_actions == (policy["guarded_actions"] || {}) &&
              state.verification_requirements == (policy["verification_requirements"] || {})

          raise PolicyConflictError, "Same policy version has different contents" unless same_policy

          return state
        end

        state.update!(
          policy_version: incoming_version,
          guarded_actions: policy["guarded_actions"] || {},
          verification_requirements: policy["verification_requirements"] || {},
          policy_synced_at: Time.current,
        )

        DebugLogger.log(
          "policy_push_applied",
          { policy_version: state.policy_version, guarded_actions: state.guarded_actions },
        )

        state
      end

      def authenticate_push_token(push_token)
        state = IntegrationState.current

        authenticate_push_token!(state, push_token)

        true
      end

      private

      def authenticate_push_token!(state, push_token)
        raise AuthenticationError, "Missing push token" if push_token.blank?

        stored_hash = state.push_token_hash.to_s

        raise AuthenticationError, "Push token is not configured" if stored_hash.blank?

        supplied_hash = Digest::SHA256.hexdigest(push_token)

        unless ActiveSupport::SecurityUtils.secure_compare(supplied_hash, stored_hash)
          raise AuthenticationError, "Invalid push token"
        end
      end
    end
  end
end
