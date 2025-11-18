class CreateDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :deals do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :pipeline, null: false, foreign_key: true, index: true
      t.references :pipeline_stage, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.decimal :amount, precision: 15, scale: 2, default: 0
      t.string :currency, limit: 8, default: 'BRL'
      t.date :close_date
      t.text :notes
      t.timestamps
    end
    add_index :deals, [:account_id, :pipeline_id]
    add_index :deals, [:account_id, :contact_id]
  end
end


