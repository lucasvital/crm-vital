class CreateScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :sender, polymorphic: true, null: false
      t.text :content, null: false
      t.integer :content_type, default: 0
      t.integer :message_type, default: 1  # outgoing
      t.boolean :private, default: false
      t.jsonb :content_attributes, default: {}
      t.jsonb :additional_attributes, default: {}
      t.datetime :scheduled_at, null: false
      t.integer :status, default: 0  # 0=pending, 1=sent, 2=cancelled, 3=failed
      t.text :error_message

      t.timestamps
    end

    add_index :scheduled_messages, [:scheduled_at, :status]
    add_index :scheduled_messages, :conversation_id
  end
end
