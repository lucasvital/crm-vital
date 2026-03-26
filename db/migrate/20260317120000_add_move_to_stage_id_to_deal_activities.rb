class AddMoveToStageIdToDealActivities < ActiveRecord::Migration[7.0]
  def change
    add_reference :deal_activities, :move_to_stage, null: true,
                  foreign_key: { to_table: :pipeline_stages }, index: true
  end
end
