# frozen_string_literal: true

module Elliepass
  class PostingEnforcer
    class << self
      def call(manager)
        return nil unless SiteSetting.elliepass_enabled

        user = manager.user
        return nil unless user

        # Never lock admins/moderators out.
        return nil if user.staff?

        trace_id = Elliepass::DebugLogger.trace_id

        capability = capability_for(manager)

        Elliepass::DebugLogger.log(
          "posting_attempt",
          {
            trace: trace_id,
            user_id: user.id,
            username: user.username,
            capability: capability,
            topic_id: manager.args[:topic_id],
            archetype: manager.args[:archetype],
          },
        )

        return nil unless capability

        authorization = Elliepass::AuthorizationService.check(user, capability, trace_id: trace_id)

        if authorization[:allowed]
          Elliepass::DebugLogger.log(
            "posting_decision",
            {
              trace: trace_id,
              decision: "ALLOW",
              capability: capability,
              reason: authorization[:reason],
            },
          )

          return nil
        end

        Elliepass::DebugLogger.log(
          "posting_decision",
          {
            trace: trace_id,
            decision: "DENY",
            capability: capability,
            reason: authorization[:reason],
          },
        )

        failed_result(authorization)
      end

      private

      def capability_for(manager)
        topic_id = manager.args[:topic_id]

        if topic_id.present?
          topic = Topic.find_by(id: topic_id)

          # Let Discourse produce its normal missing-topic error.
          return nil unless topic

          return "reply_private_message" if topic.archetype == Archetype.private_message

          return "reply_content"
        end

        return "create_private_message" if manager.args[:archetype] == Archetype.private_message

        "create_content"
      end

      def failed_result(authorization)
        result = NewPostResult.new(:elliepass, false)

        if authorization[:reason] == "elliepass_unavailable"
          result.errors.add(:base, I18n.t("elliepass.posting.unavailable"))

          return result
        end

        # Generic marker telling the browser this is an
        # ElliePass requirements checklist response.
        result.errors.add(:base, I18n.t("elliepass.posting.checklist"))

        requirements = authorization[:durable_requirements] || {}

        requirements.each do |type, requirement|
          requirement = requirement.symbolize_keys

          next unless requirement[:required] == true

          status =
            if requirement[:satisfied] == true
              "met"
            elsif requirement[:actionable] == false
              "blocked"
            else
              "needed"
            end

          case type.to_s
          when "human"
            add_checklist_error(result, "human", status)
          when "identity"
            add_checklist_error(result, "identity", status)
          when "age"
            minimum_age = requirement[:minimum_age].to_i

            add_checklist_error(result, "age", status, minimum_age: minimum_age)
          when "id_verified_location"
            add_checklist_error(result, "id_location", status)
          end
        end

        if authorization[:location_required]
          status = authorization[:location_satisfied] ? "met" : "needed"

          add_checklist_error(result, "current_location", status)
        end

        result
      end

      def add_checklist_error(result, requirement, status, **options)
        key =
          "elliepass.posting.checklist_" \
            "#{requirement}_#{status}"

        result.errors.add(:base, I18n.t(key, **options))
      end
    end
  end
end
