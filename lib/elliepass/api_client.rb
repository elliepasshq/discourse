# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Elliepass
  class ApiClient
    class Error < StandardError; end

    def self.connect
        new.connect
    end

    def self.member_status(user)
        new.member_status(user)
    end

    def self.authorize_member(user, capability, trace_id: nil)
      new.authorize_member(
        user,
        capability,
        trace_id: trace_id,
      )
    end

    def self.start_verification(user, return_url: nil)
        new.start_verification(user, return_url: return_url)
    end


    def member_status(user)
        post(
            "/api/v1/community/member/status",
            {
            external_user_id: user.id.to_s,
            external_username: user.username,
            },
        )
    end  

    def authorize_member(user, capability, trace_id: nil)
      post(
        "/api/v1/community/member/authorize",
        {
          external_user_id: user.id.to_s,
          external_username: user.username,
          capability: capability,
        },
        trace_id: trace_id,
      )
    end

    def initialize
        @base_url = SiteSetting.elliepass_api_url.to_s.sub(%r{/$}, "")
        @community_key = SiteSetting.elliepass_community_key
        @community_secret = SiteSetting.elliepass_community_secret
    end

    def connect
        post(
            "/api/v1/community/connect",
            {
            community_key: @community_key,
            secret: @community_secret,
            integration_version: "0.1.0",
            },
        )
    end
   
    def start_verification(user, return_url: nil)
        body = {
            external_user_id: user.id.to_s,
            external_username: user.username,
        }

        body[:return_url] = return_url if return_url.present?

        post(
            "/api/v1/community/member/verification/start",
            body,
        )
    end
    
    private

    def post(path, body, trace_id: nil)
      uri = URI.parse("#{@base_url}#{path}")

      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request["X-ElliePass-Community-Key"] = @community_key
      request["X-ElliePass-Secret"] = @community_secret
      request["X-ElliePass-Trace-Id"] = trace_id if trace_id.present?
      request.body = JSON.generate(body)

      response =
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 5,
          read_timeout: 10,
        ) do |http|
          http.request(request)
        end

      parsed =
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          {}
        end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "ElliePass API returned HTTP #{response.code}: #{response.body}"
      end

      parsed
    rescue Timeout::Error, SocketError, Errno::ECONNREFUSED => e
      raise Error, "Unable to reach ElliePass API: #{e.message}"
    end

  end
end