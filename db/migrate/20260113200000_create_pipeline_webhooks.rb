class CreatePipelineWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :pipeline_webhooks do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :active, default: true, null: false
      t.references :pipeline_stage, null: false, foreign_key: true
      t.jsonb :field_mapping, default: {}, null: false
      t.jsonb :tag_config, default: {}, null: false
      t.timestamps
    end

    add_index :pipeline_webhooks, :token, unique: true
    add_index :pipeline_webhooks, [:pipeline_id, :name]
    add_index :pipeline_webhooks, [:account_id, :pipeline_id]
  end
end

