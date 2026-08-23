# frozen_string_literal: true

require "securerandom"

module Elliepass
  class DebugLogger
    class << self
      def trace_id
        "ep_#{SecureRandom.hex(5)}"
      end

      def log(event, data = {})
        return unless SiteSetting.elliepass_debug_logging

        details = data.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")

        Rails.logger.info("[ElliePass DEBUG] #{event} #{details}".strip)
      end
    end
  end
end
