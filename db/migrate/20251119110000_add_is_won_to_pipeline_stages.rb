class AddIsWonToPipelineStages < ActiveRecord::Migration[7.0]
  def change
    add_column :pipeline_stages, :is_won, :boolean, null: false, default: false
    add_index :pipeline_stages, [:pipeline_id, :is_won], name: 'idx_pipeline_stages_pipeline_won'
  end
end



