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

    apply_labels_for_score(qualified)
    apply_priority_for_score(score)
    create_private_note(score, reasons) if qualified
  end

  def apply_labels_for_score(qualified)
    status_label = qualified ? 'lead-qualificado' : 'lead-nao-qualificado'

    ensure_account_label(status_label, qualified ? '#22c55e' : '#ef4444', 'Status de qualificação do lead')

    labels = @conversation.label_list || []
    updated = (labels + [status_label]).uniq
    @conversation.update_labels(updated)
  end

  def ensure_account_label(title, color, description)
    label = @conversation.account.labels.find_or_initialize_by(title: title)
    label.color ||= color
    label.description ||= description
    label.show_on_sidebar = true if label.show_on_sidebar.nil?
    label.save! if label.new_record? || label.changed?
  end

  def apply_priority_for_score(score)
    desired = if score >= 85
                'urgent'
              elsif score >= 70
                'high'
              elsif score >= 50
                'medium'
              elsif score >= 40
                'low'
              else
                nil
              end

    return if desired.nil?

    @conversation.toggle_priority(desired)
  end

  def create_private_note(score, reasons)
    content = "Lead qualificado — Score: #{score}. Motivos: #{reasons.join(', ')}."
    Messages::MessageBuilder.new(
      nil,
      @conversation.reload,
      { content: content, private: true, message_type: 'outgoing', content_attributes: { lead_scoring: true } }
    ).perform
  end
end