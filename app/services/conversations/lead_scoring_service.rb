class Conversations::LeadScoringService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    hook = Integrations::Hook.find_by(account_id: @conversation.account_id, app_id: 'openai')
    return unless hook&.enabled?

    event = {
      'name' => 'lead_scoring',
      'data' => { 'conversation_display_id' => @conversation.display_id, 'content' => '' }
    }
    response = Integrations::Openai::ProcessorService.new(hook: hook, event: event).lead_scoring_message
    content = response.is_a?(Hash) ? response[:message] || response['message'] : response
    parsed = parse_json(content)
    return unless parsed

    persist_results(parsed)
  end

  private

  def parse_json(response)
    body = JSON.parse(response.to_s) rescue nil
    return nil unless body.is_a?(Hash)
    body
  end

  def persist_results(data)
    score = data['score'].to_i
    qualified = !!data['qualified']
    reasons = Array(data['reasons']).map(&:to_s)

    attrs = @conversation.custom_attributes || {}
    @conversation.update!(custom_attributes: attrs.merge({
      'lead_score' => score,
      'lead_qualified' => qualified,
      'lead_reasons' => reasons,
      'lead_scored_at' => Time.current.utc
    }))

    apply_labels_for_score(score, qualified)
  end

  def apply_labels_for_score(score, qualified)
    label_score = "Score #{score}"
    status_label = qualified ? 'Lead: Qualificado' : 'Lead: Não qualificado'

    labels = @conversation.label_list || []
    updated = (labels + [label_score, status_label]).uniq
    @conversation.update_labels(updated)
  end
end