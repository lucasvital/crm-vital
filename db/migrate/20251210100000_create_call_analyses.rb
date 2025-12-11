# frozen_string_literal: true

class CreateCallAnalyses < ActiveRecord::Migration[7.0]
  def change
    create_table :call_analyses do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true, comment: 'Vendedor analisado'
      t.references :created_by, null: false, foreign_key: { to_table: :users }, index: true, comment: 'Quem inseriu a análise'
      t.references :deal, null: true, foreign_key: true, index: true

      t.text :transcript, null: false
      t.jsonb :analysis_result, default: {}, null: false
      t.text :summary
      t.jsonb :next_steps, default: []
      t.jsonb :objections, default: []
      t.jsonb :competitors_mentioned, default: []
      t.decimal :seller_score, precision: 5, scale: 2
      t.jsonb :pdi_points, default: []

      t.timestamps
    end

    add_index :call_analyses, [:account_id, :user_id]
    add_index :call_analyses, [:account_id, :contact_id]
    add_index :call_analyses, :created_at
  end
end

