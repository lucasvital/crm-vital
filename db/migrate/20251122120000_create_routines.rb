class CreateRoutines < ActiveRecord::Migration[7.1]
  def change
    create_table :routines do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :weekday, null: false
      t.time :time_of_day, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :routines, %i[account_id weekday time_of_day]
  end
end


