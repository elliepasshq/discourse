# frozen_string_literal: true

module Jobs
  class ElliepassConnect < ::Jobs::Base
    STARTUP_LOCK_KEY = "elliepass:startup_connect"

    def execute(args)
      if args["startup"]
        acquired = Discourse.redis.set(STARTUP_LOCK_KEY, "1", nx: true, ex: 60)

        return unless acquired
      end

      result = Elliepass::ConnectionService.connect

      if result.status == :connected
        Elliepass::DebugLogger.log("connection_success")
      elsif result.status == :not_configured
        Elliepass::DebugLogger.log("connection_skipped_not_configured")
      else
        Rails.logger.warn("[ElliePass] connection failed: #{result.message}")
      end
    rescue StandardError => e
      Rails.logger.error("[ElliePass] connection job failed: #{e.class}: #{e.message}")
    end
  end
end
