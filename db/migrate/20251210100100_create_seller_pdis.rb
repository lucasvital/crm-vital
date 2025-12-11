# frozen_string_literal: true

class CreateSellerPdis < ActiveRecord::Migration[7.0]
  def change
    create_table :seller_pdis do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true, comment: 'Vendedor'

      t.jsonb :competencies, default: {}, null: false
      t.jsonb :improvement_areas, default: [], null: false
      t.jsonb :strengths, default: [], null: false
      t.jsonb :evolution_history, default: [], null: false

      t.timestamps
    end

    add_index :seller_pdis, [:account_id, :user_id], unique: true
  end
end

