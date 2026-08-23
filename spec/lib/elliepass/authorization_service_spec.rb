# frozen_string_literal: true

require "rails_helper"

RSpec.describe Elliepass::AuthorizationService do
  fab!(:user)

  before do
    SiteSetting.elliepass_enabled = true
    SiteSetting.elliepass_authorization_cache_hours = 24

    Elliepass::IntegrationState.current.update!(
      policy_version: 6,
      guarded_actions: {
        "create_content" => true,
        "reply_content" => true,
      },
      verification_requirements: {},
    )

    Discourse.redis.scan_each(
      match: "elliepass:authorization:*"
    ) do |key|
      Discourse.redis.del(key)
    end
  end

  def state
    Elliepass::IntegrationState.current
  end

  it "allows an unguarded capability without calling the API" do
    state.update!(
      guarded_actions: {
        "create_content" => false,
        "reply_content" => true,
      },
    )

    expect(Elliepass::ApiClient)
      .not_to receive(:authorize_member)

    result =
      described_class.check(
        user,
        "create_content",
      )

    expect(result).to eq(
      allowed: true,
      policy_applies: false,
      reason: "not_guarded",
    )
  end

  it "caches an allowed result and reuses it" do
    expect(Elliepass::ApiClient)
      .to receive(:authorize_member)
      .once
      .and_return(
        {
          "allowed" => true,
          "policy_applies" => true,
          "reason" => "qualified",
          "policy_version" => 6,
          "valid_until" =>
            12.hours.from_now.utc.iso8601,
        },
      )

    first =
      described_class.check(
        user,
        "create_content",
      )

    second =
      described_class.check(
        user,
        "create_content",
      )

    expect(first[:allowed]).to eq(true)
    expect(second).to eq(first)

    key =
      [
        "elliepass",
        "authorization",
        "v6",
        "user#{user.id}",
        "create_content",
      ].join(":")

    ttl =
      Discourse.redis.ttl(key)

    expect(ttl).to be > 0
    expect(ttl).to be <= 12.hours.to_i
  end

  it "keeps a denied result cached until explicitly cleared" do
    expect(Elliepass::ApiClient)
      .to receive(:authorize_member)
      .once
      .and_return(
        {
          "allowed" => false,
          "policy_applies" => true,
          "reason" => "human_verification_required",
          "policy_version" => 6,
          "valid_until" => nil,
        },
      )

    first =
      described_class.check(
        user,
        "reply_content",
      )

    second =
      described_class.check(
        user,
        "reply_content",
      )

    expect(first[:allowed]).to eq(false)
    expect(second).to eq(first)

    key =
      [
        "elliepass",
        "authorization",
        "v6",
        "user#{user.id}",
        "reply_content",
      ].join(":")

    expect(
      Discourse.redis.ttl(key)
    ).to eq(-1)

    described_class.clear(
      user,
      "reply_content",
    )

    expect(
      Discourse.redis.exists?(key)
    ).to eq(false)
  end

  it "ignores an old cached decision after policy version changes" do
    expect(Elliepass::ApiClient)
      .to receive(:authorize_member)
      .twice
      .and_return(
        {
          "allowed" => true,
          "policy_applies" => true,
          "reason" => "qualified",
          "policy_version" => 6,
          "valid_until" =>
            24.hours.from_now.utc.iso8601,
        },
        {
          "allowed" => false,
          "policy_applies" => true,
          "reason" => "minimum_age",
          "policy_version" => 7,
          "valid_until" => nil,
        },
      )

    first =
      described_class.check(
        user,
        "create_content",
      )

    expect(first[:allowed]).to eq(true)

    state.update!(
      policy_version: 7,
    )

    second =
      described_class.check(
        user,
        "create_content",
      )

    expect(second[:allowed]).to eq(false)
    expect(second[:reason]).to eq(
      "minimum_age"
    )
  end
end