# frozen_string_literal: true
require "time"
require "json"

module Elliepass
  class AuthorizationService
    class << self
      def check(user, capability, trace_id: nil)
        state = Elliepass::IntegrationState.current
        unless guarded?(state, capability)
          return { allowed: true, policy_applies: false, reason: "not_guarded" }
        end

        durable_key = durable_cache_key(user, state.policy_version)

        location_key = location_cache_key(user, state.policy_version)

        durable = read_cache(durable_key)

        needs_location =
          state.verification_requirements["needs_current_location"] == true ||
            state.verification_requirements[:needs_current_location] == true

        location = needs_location ? read_cache(location_key) : { required: false, satisfied: true }

        if durable && location
          Elliepass::DebugLogger.log(
            "authorization_cache_hit",
            {
              trace: trace_id,
              user_id: user.id,
              capability: capability,
              policy_version: state.policy_version,
            },
          )

          return decision_from_snapshots(state, capability, durable, location)
        end

        Elliepass::DebugLogger.log(
          "authorization_api_required",
          {
            trace: trace_id,
            user_id: user.id,
            username: user.username,
            capability: capability,
            policy_version: state.policy_version,
          },
        )

        response = Elliepass::ApiClient.authorize_member(user, capability, trace_id: trace_id)

        durable = response["durable"]

        location = response["location"]

        durable_ttl = SiteSetting.elliepass_durable_cache_hours.hours

        location_ttl = SiteSetting.elliepass_location_cache_hours.hours

        write_snapshot_cache(durable_key, durable, max_ttl: durable_ttl) if durable.is_a?(Hash)

        write_snapshot_cache(location_key, location, max_ttl: location_ttl) if location.is_a?(Hash)

        result = {
          allowed: response["allowed"] == true,
          policy_applies: response["policy_applies"] == true,
          reason: response["reason"],
          durable_required: durable_required?(state),
          durable_satisfied: durable.is_a?(Hash) && durable["satisfied"] == true,
          durable_reason:
            durable.is_a?(Hash) && durable["satisfied"] != true ? durable["reason"] : nil,
          # Preserve ElliePass's per-requirement evaluation.
          # Discourse must display these results, not reproduce
          # ElliePass qualification logic locally.
          durable_requirements: durable.is_a?(Hash) ? (durable["requirements"] || {}) : {},
          location_required: location.is_a?(Hash) && location["required"] == true,
          location_satisfied: location.is_a?(Hash) && location["satisfied"] == true,
          location_reason:
            (
              if location.is_a?(Hash) && location["required"] == true &&
                   location["satisfied"] != true
                location["reason"]
              else
                nil
              end
            ),
        }

        Elliepass::DebugLogger.log(
          "authorization_response",
          {
            trace: trace_id,
            user_id: user.id,
            capability: capability,
            allowed: response["allowed"],
            policy_applies: response["policy_applies"],
            reason: response["reason"],
            policy_version: response["policy_version"],
            durable_requirements: durable.is_a?(Hash) ? (durable["requirements"] || {}) : {},
          },
        )

        result
      rescue Elliepass::ApiClient::Error => e
        Rails.logger.warn(
          "[ElliePass] authorization unavailable " \
            "user_id=#{user.id} " \
            "capability=#{capability}: #{e.class}",
        )

        { allowed: false, policy_applies: true, reason: "elliepass_unavailable" }
      end

      def clear(user, capability = nil)
        state = Elliepass::IntegrationState.current

        Discourse.redis.del(durable_cache_key(user, state.policy_version))

        Discourse.redis.del(location_cache_key(user, state.policy_version))

        nil
      end

      def clear_location(user)
        state = Elliepass::IntegrationState.current

        Discourse.redis.del(location_cache_key(user, state.policy_version))

        nil
      end

      private

      def guarded?(state, capability)
        state.guarded_actions[capability.to_s] == true
      end

      def durable_cache_key(user, policy_version)
        ["elliepass", "authorization", "durable", "v#{policy_version}", "user#{user.id}"].join(":")
      end

      def location_cache_key(user, policy_version)
        ["elliepass", "authorization", "location", "v#{policy_version}", "user#{user.id}"].join(":")
      end

      def read_cache(key)
        raw = Discourse.redis.get(key)

        return nil if raw.blank?

        JSON.parse(raw, symbolize_names: true)
      rescue JSON::ParserError
        Discourse.redis.del(key)

        nil
      end

      def write_cache(key, result, expires_in: nil)
        value = JSON.generate(result.merge(cached_at: Time.now.to_i))

        if expires_in
          Discourse.redis.setex(key, expires_in.to_i, value)
        else
          Discourse.redis.set(key, value)
        end
      end

      def write_snapshot_cache(key, snapshot, max_ttl:)
        ttl = max_ttl.to_i

        valid_until = snapshot["valid_until"] || snapshot[:valid_until]

        if valid_until.present?
          begin
            remaining = Time.parse(valid_until).utc - Time.now.utc

            ttl = [ttl, remaining.to_i].min
          rescue ArgumentError
            nil
          end
        end

        return if ttl <= 0

        write_cache(key, snapshot, expires_in: ttl)
      end

      def durable_required?(state)
        requirements = state.verification_requirements

        %w[needs_human needs_identity needs_age needs_id_verified_location].any? do |key|
          requirements[key] == true || requirements[key.to_sym] == true
        end
      end

      def decision_from_snapshots(state, capability, durable, location)
        unless guarded?(state, capability)
          return { allowed: true, policy_applies: false, reason: "not_guarded" }
        end

        durable_required = durable_required?(state)

        durable_satisfied = !durable_required || durable[:satisfied] == true

        location_required = location[:required] == true

        location_satisfied = !location_required || location[:satisfied] == true

        durable_reason =
          (durable[:reason] || "verification_required" if durable_required && !durable_satisfied)

        location_reason =
          if location_required && !location_satisfied
            location[:reason] || "current_location_required"
          end

        {
          allowed: durable_satisfied && location_satisfied,
          policy_applies: true,
          reason: location_reason || durable_reason || "qualified",
          durable_required: durable_required,
          durable_satisfied: durable_satisfied,
          durable_reason: durable_reason,
          # Cached durable snapshots contain the same authoritative
          # per-requirement results returned by ElliePass.
          durable_requirements: (durable[:requirements] || {}).deep_stringify_keys,
          location_required: location_required,
          location_satisfied: location_satisfied,
          location_reason: location_reason,
        }
      end
    end
  end
end
