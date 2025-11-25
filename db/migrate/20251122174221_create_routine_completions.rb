class CreateRoutineCompletions < ActiveRecord::Migration[7.1]
  def change
    create_table :routine_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :routine, null: false, foreign_key: true
      t.date :completed_date, null: false

      t.timestamps
    end

    add_index :routine_completions, [:user_id, :routine_id, :completed_date], unique: true, name: 'index_routine_completions_unique'
  end
end
