class BackfillDealsFromLegacyConversations < ActiveRecord::Migration[7.0]
  def up
    say_with_time 'Backfilling deals from legacy conversations (label: deal)' do
      Account.find_each do |account|
        # Ensure a default pipeline exists (should already exist from previous migration)
        pipeline = account.pipelines.first || account.pipelines.create!(name: 'Padrão')
        stages_by_key = pipeline.pipeline_stages.index_by(&:key)
        # Ensure default stages
        %w[new qualified proposal won lost].each_with_index do |key, idx|
          stages_by_key[key] ||= pipeline.pipeline_stages.create!(key: key, name: default_name_for(key), position: idx + 1)
        end

        # Find conversations tagged with 'deal'
        conversations = account.conversations
        conversations.find_each do |conv|
          labels = (conv.label_list || conv.cached_label_list_array || []).map { |l| l.is_a?(String) ? l : (l.try(:title) || l.try(:name)) }.compact
          next unless labels.include?('deal')

          ca = conv.custom_attributes || {}
          key = (ca['deal_stage'].presence || 'new').to_s
          stage = stages_by_key[key] || stages_by_key['new']

          title = ca['deal_title'].presence || "Deal ##{conv.display_id}"
          amount = (ca['deal_amount'].presence || 0).to_f
          currency = (ca['deal_currency'].presence || 'BRL').to_s
          close_date = ca['deal_close_date'].presence
          notes = ca['deal_notes'].presence

          # Avoid creating duplicates with same title+contact in same pipeline
          next if account.deals.where(contact_id: conv.contact_id, pipeline_id: pipeline.id, title: title).exists?

          account.deals.create!(
            contact_id: conv.contact_id,
            pipeline_id: pipeline.id,
            pipeline_stage_id: stage.id,
            title: title,
            amount: amount,
            currency: currency,
            close_date: close_date,
            notes: notes
          )
        end
      end
    end
  end

  def down
    # no-op
  end

  private

  def default_name_for(key)
    {
      'new' => 'Novo',
      'qualified' => 'Qualificado',
      'proposal' => 'Proposta',
      'won' => 'Ganho',
      'lost' => 'Perdido'
    }[key] || key.humanize
  end
end


