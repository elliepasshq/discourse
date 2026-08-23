# frozen_string_literal: true

module Elliepass
  class StatusService
    Result = Struct.new(:allowed, :reason, :raw, keyword_init: true)

    def self.check(user)
      response = ApiClient.member_status(user)

      Result.new(allowed: response["qualified"] == true, reason: response["reason"], raw: response)
    rescue ApiClient::Error => e
      Result.new(allowed: false, reason: "elliepass_unavailable", raw: { "error" => e.message })
    end
  end
end
