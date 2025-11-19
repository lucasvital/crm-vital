class AddWonFieldsToDeals < ActiveRecord::Migration[7.0]
  def change
    add_column :deals, :won_at, :datetime
    add_reference :deals, :won_by_user, foreign_key: { to_table: :users }, index: true, null: true
    add_column :deals, :won_amount_snapshot, :decimal, precision: 12, scale: 2

    add_index :deals, :won_at
  end
end



