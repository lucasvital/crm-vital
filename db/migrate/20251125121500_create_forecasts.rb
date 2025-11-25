class CreateForecasts < ActiveRecord::Migration[7.1]
  def change
    create_table :forecasts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :weekly_forecast, null: false, default: []
      t.jsonb :monthly_forecast, null: false, default: []
      t.jsonb :risks, null: false, default: []
      t.jsonb :opportunities, null: false, default: []
      t.integer :confidence_level
      t.jsonb :key_insights, null: false, default: []
      t.jsonb :recommendations, null: false, default: []
      t.text :summary
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :forecasts, [:account_id, :user_id]
  end
end

