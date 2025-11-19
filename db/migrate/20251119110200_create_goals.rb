class CreateGoals < ActiveRecord::Migration[7.0]
  def change
    create_table :goals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string :scope_type, null: false # 'user' | 'team'
      t.bigint :scope_id, null: false

      t.string :metric, null: false # 'count' | 'amount'
      t.integer :target_number
      t.decimal :target_amount, precision: 12, scale: 2

      t.date :start_date, null: false
      t.date :end_date, null: false

      t.integer :pipeline_ids, array: true, default: []

      t.string :title, null: false
      t.text :notes
      t.string :status, null: false, default: 'active' # 'active' | 'archived'

      t.timestamps
    end

    add_index :goals, [:account_id, :scope_type, :scope_id], name: 'idx_goals_account_scope'
    add_index :goals, :pipeline_ids, using: :gin
  end
end



