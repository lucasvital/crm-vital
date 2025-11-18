class BackfillDefaultPipeline < ActiveRecord::Migration[7.0]
  def up
    # Create default pipeline per account with standard stages
    stages = [
      { key: 'new', name: 'Novo', position: 1 },
      { key: 'qualified', name: 'Qualificado', position: 2 },
      { key: 'proposal', name: 'Proposta', position: 3 },
      { key: 'won', name: 'Ganho', position: 4 },
      { key: 'lost', name: 'Perdido', position: 5 }
    ]

    Account.find_each do |account|
      pipeline = account.pipelines.create!(name: 'Padrão')
      created = stages.map { |s| [s[:key], pipeline.pipeline_stages.create!(s)] }.to_h

      # Map existing conversations labeled as deal to default pipeline + stage using custom_attributes.deal_stage
      account.conversations.find_each do |conv|
        ca = conv.custom_attributes || {}
        next unless (conv.label_list || conv.cached_label_list_array || []).map { |l| l.is_a?(String) ? l : l.try(:title) || l.try(:name) }.compact.include?('deal')
        key = (ca['deal_stage'].presence || 'new').to_s
        stage = created[key] || created['new']
        conv.update_columns(deal_pipeline_id: pipeline.id, deal_pipeline_stage_id: stage.id) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def down
    # noop: keep data
  end
end


