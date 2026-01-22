class AddAssigneeToDeals < ActiveRecord::Migration[7.0]
  def change
    add_reference :deals, :assignee, foreign_key: { to_table: :users }, null: true, index: true
  end
end
