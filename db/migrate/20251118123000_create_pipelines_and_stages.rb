class CreatePipelinesAndStages < ActiveRecord::Migration[7.0]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :pipeline_stages do |t|
      t.references :pipeline, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :key, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :pipeline_stages, [:pipeline_id, :key], unique: true

    change_table :conversations, bulk: true do |t|
      t.bigint :deal_pipeline_id
      t.bigint :deal_pipeline_stage_id
    end
    add_foreign_key :conversations, :pipelines, column: :deal_pipeline_id
    add_foreign_key :conversations, :pipeline_stages, column: :deal_pipeline_stage_id
    add_index :conversations, :deal_pipeline_id
    add_index :conversations, :deal_pipeline_stage_id
  end
end


