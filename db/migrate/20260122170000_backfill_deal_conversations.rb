class BackfillDealConversations < ActiveRecord::Migration[7.0]
  def up
    # Usar SQL direto para performance em grandes volumes
    execute <<-SQL
      UPDATE deals
      SET conversation_id = (
        SELECT conversations.id
        FROM conversations
        WHERE conversations.account_id = deals.account_id
          AND conversations.contact_id = deals.contact_id
          AND conversations.created_at <= deals.created_at
        ORDER BY conversations.created_at DESC
        LIMIT 1
      )
      WHERE deals.conversation_id IS NULL
        AND deals.contact_id IS NOT NULL;
    SQL

    # Log resultado
    updated_count = Deal.where.not(conversation_id: nil).count
    total_count = Deal.count
    puts "✓ Backfill completed: #{updated_count}/#{total_count} deals now have conversation associations"
  end

  def down
    # Não fazer nada no rollback - não queremos remover as associações
    # que podem ter sido criadas legitimamente após a migration
    puts "⚠ Rollback skipped - conversation_id associations preserved"
  end
end

