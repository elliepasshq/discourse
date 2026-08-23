# frozen_string_literal: true

module Elliepass
  class IntegrationState < ActiveRecord::Base
    self.table_name = "elliepass_integration_states"

    def self.current
      first_or_create!(policy_version: 0, guarded_actions: {}, verification_requirements: {})
    end
  end
end

# == Schema Information
#
# Table name: elliepass_integration_states
#
#  id                        :bigint           not null, primary key
#  guarded_actions           :jsonb            not null
#  policy_synced_at          :datetime
#  policy_version            :integer          default(0), not null
#  push_token_hash           :string
#  verification_requirements :jsonb            not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
