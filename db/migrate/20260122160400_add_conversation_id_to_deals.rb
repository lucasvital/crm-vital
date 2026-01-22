class AddConversationIdToDeals < ActiveRecord::Migration[7.0]
  def change
    add_reference :deals, :conversation, foreign_key: true, null: true, index: true
  end
end
