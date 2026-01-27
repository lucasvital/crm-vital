class AddExistingLeadConfigToPipelineWebhooks < ActiveRecord::Migration[7.0]
  def change
    add_column :pipeline_webhooks, :existing_lead_action, :string, default: 'create_new', null: false
    add_reference :pipeline_webhooks, :existing_lead_stage, foreign_key: { to_table: :pipeline_stages }, null: true
    add_index :pipeline_webhooks, :existing_lead_action
  end
end
