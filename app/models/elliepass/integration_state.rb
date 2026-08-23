# frozen_string_literal: true

module Elliepass
  class IntegrationState < ActiveRecord::Base
    self.table_name =
      "elliepass_integration_states"

    def self.current
      first_or_create!(
        policy_version: 0,
        guarded_actions: {},
        verification_requirements: {},
      )
    end
  end
end