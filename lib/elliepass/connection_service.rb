# frozen_string_literal: true

require "json"
require "time"

module Elliepass
  class ConnectionService
    STATUS_KEY = "elliepass:connection_status"

    Result = Struct.new(:status, :message, :response, keyword_init: true)

    def self.connect
      new.connect
    end

    def self.status
      raw = Discourse.redis.get(STATUS_KEY)

      if raw.blank?
        return(
          {
            "status" => "not_checked",
            "message" => nil,
            "last_checked_at" => nil,
            "last_success_at" => nil,
          }
        )
      end

      JSON.parse(raw)
    rescue JSON::ParserError
      { "status" => "unknown" }
    end

    def connect
      unless configured?
        return(
          record(
            status: :not_configured,
            message: "ElliePass is not fully configured.",
            response: nil,
          )
        )
      end

      response = ApiClient.connect

      PolicyStateService.store_connect_response(response)

      safe_response = response.except("push_token")

      record(
        status: :connected,
        message: "Connected to ElliePass.",
        response: safe_response,
        success: true,
      )
    rescue ApiClient::Error => e
      record(status: :failed, message: e.message, response: nil)
    rescue StandardError => e
      Rails.logger.error("[ElliePass] connection failed: #{e.class}: #{e.message}")

      record(status: :failed, message: "Unable to connect to ElliePass.", response: nil)
    end

    private

    def record(status:, message:, response:, success: false)
      previous = self.class.status

      data = {
        "status" => status.to_s,
        "message" => message,
        "last_checked_at" => Time.now.utc.iso8601,
        "last_success_at" => success ? Time.now.utc.iso8601 : previous["last_success_at"],
      }

      Discourse.redis.set(STATUS_KEY, JSON.generate(data))

      Result.new(status: status, message: message, response: response)
    end

    def configured?
      SiteSetting.elliepass_enabled && SiteSetting.elliepass_api_url.present? &&
        SiteSetting.elliepass_community_key.present? &&
        SiteSetting.elliepass_community_secret.present?
    end
  end
end
