# frozen_string_literal: true

class CreateElliepassIntegrationState < ActiveRecord::Migration[7.0]
  def change
    create_table :elliepass_integration_states do |t|
      t.integer :policy_version, null: false, default: 0

      t.jsonb :guarded_actions, null: false, default: {}

      t.jsonb :verification_requirements, null: false, default: {}

      t.string :push_token_hash

      t.datetime :policy_synced_at

      t.timestamps
    end
  end
end
