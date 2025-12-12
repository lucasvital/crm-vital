class CreateDealActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_activities do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :pipeline_stage, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.text :description
      t.integer :position, default: 0
      t.jsonb :messages, default: []

      t.timestamps
    end

    add_index :deal_activities, [:account_id, :pipeline_stage_id]
    add_index :deal_activities, :messages, using: :gin
  end
end

