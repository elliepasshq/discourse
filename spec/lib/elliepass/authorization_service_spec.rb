# frozen_string_literal: true

require "rails_helper"

RSpec.describe Elliepass::AuthorizationService do
  fab!(:user)

  before do
    SiteSetting.elliepass_enabled = true
    SiteSetting.elliepass_durable_cache_hours = 24
    SiteSetting.elliepass_location_cache_hours = 24

    Elliepass::IntegrationState.current.update!(
      policy_version: 6,
      guarded_actions: {
        "create_content" => true,
        "reply_content" => true,
      },
      verification_requirements: {
        "needs_human" => true,
        "needs_current_location" => false,
      },
    )

    Discourse.redis.scan_each(match: "elliepass:authorization:*") { |key| Discourse.redis.del(key) }
  end

  def state
    Elliepass::IntegrationState.current
  end

  it "allows an unguarded capability without calling the API" do
    state.update!(guarded_actions: { "create_content" => false, "reply_content" => true })

    allow(Elliepass::ApiClient).to receive(:authorize_member)

    result = described_class.check(user, "create_content")

    expect(Elliepass::ApiClient).not_to have_received(:authorize_member)

    expect(result).to eq(allowed: true, policy_applies: false, reason: "not_guarded")
  end

  it "caches a durable snapshot and reuses it" do
    allow(Elliepass::ApiClient).to receive(:authorize_member).and_return(
      {
        "allowed" => true,
        "policy_applies" => true,
        "reason" => "qualified",
        "policy_version" => 6,
        "durable" => {
          "satisfied" => true,
          "reason" => nil,
          "requirements" => {
            "human" => {
              "required" => true,
              "satisfied" => true,
            },
          },
          "valid_until" => 12.hours.from_now.utc.iso8601,
        },
        "location" => {
          "required" => false,
          "satisfied" => true,
          "reason" => nil,
          "valid_until" => nil,
        },
      },
    )

    first = described_class.check(user, "create_content")
    second = described_class.check(user, "create_content")

    expect(Elliepass::ApiClient).to have_received(:authorize_member).once

    expect(first[:allowed]).to eq(true)
    expect(second).to eq(first)

    key = ["elliepass", "authorization", "durable", "v6", "user#{user.id}"].join(":")

    ttl = Discourse.redis.ttl(key)

    expect(ttl).to be > 0
    expect(ttl).to be <= 12.hours.to_i
  end

  it "caches a denied durable snapshot and reuses it" do
    allow(Elliepass::ApiClient).to receive(:authorize_member).and_return(
      {
        "allowed" => false,
        "policy_applies" => true,
        "reason" => "human_verification_required",
        "policy_version" => 6,
        "durable" => {
          "satisfied" => false,
          "reason" => "human_verification_required",
          "requirements" => {
            "human" => {
              "required" => true,
              "satisfied" => false,
            },
          },
          "valid_until" => 24.hours.from_now.utc.iso8601,
        },
        "location" => {
          "required" => false,
          "satisfied" => true,
          "reason" => nil,
          "valid_until" => nil,
        },
      },
    )

    first = described_class.check(user, "reply_content")
    second = described_class.check(user, "reply_content")

    expect(Elliepass::ApiClient).to have_received(:authorize_member).once

    expect(first[:allowed]).to eq(false)
    expect(first[:reason]).to eq("human_verification_required")
    expect(second).to eq(first)

    described_class.clear(user, "reply_content")

    third = described_class.check(user, "reply_content")

    expect(Elliepass::ApiClient).to have_received(:authorize_member).twice
    expect(third[:allowed]).to eq(false)
  end

  it "ignores cached snapshots after the policy version changes" do
    allow(Elliepass::ApiClient).to receive(:authorize_member).and_return(
      {
        "allowed" => true,
        "policy_applies" => true,
        "reason" => "qualified",
        "policy_version" => 6,
        "durable" => {
          "satisfied" => true,
          "reason" => nil,
          "requirements" => {
          },
          "valid_until" => 24.hours.from_now.utc.iso8601,
        },
        "location" => {
          "required" => false,
          "satisfied" => true,
          "reason" => nil,
          "valid_until" => nil,
        },
      },
      {
        "allowed" => false,
        "policy_applies" => true,
        "reason" => "minimum_age",
        "policy_version" => 7,
        "durable" => {
          "satisfied" => false,
          "reason" => "minimum_age",
          "requirements" => {
            "age" => {
              "required" => true,
              "satisfied" => false,
            },
          },
          "valid_until" => 24.hours.from_now.utc.iso8601,
        },
        "location" => {
          "required" => false,
          "satisfied" => true,
          "reason" => nil,
          "valid_until" => nil,
        },
      },
    )

    first = described_class.check(user, "create_content")

    expect(first[:allowed]).to eq(true)

    state.update!(
      policy_version: 7,
      verification_requirements: {
        "needs_age" => true,
        "needs_current_location" => false,
      },
    )

    second = described_class.check(user, "create_content")

    expect(Elliepass::ApiClient).to have_received(:authorize_member).twice
    expect(second[:allowed]).to eq(false)
    expect(second[:reason]).to eq("minimum_age")
  end
end
