class Conversations::AnalysisService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    hook = find_or_create_mock_hook
    return { error: 'OpenAI integration not configured', error_code: 401 } unless hook

    event = {
      'name' => 'conversation_analysis',
      'data' => { 'conversation_display_id' => @conversation.display_id, 'content' => '' }
    }

    response = Integrations::Openai::ProcessorService.new(hook: hook, event: event).conversation_analysis_message

    if response.is_a?(Hash) && response[:error]
      response
    else
      { message: response.is_a?(Hash) ? response[:message] : response }
    end
  end

  private

  def find_or_create_mock_hook
    # Se tem ENV configurada, cria um mock hook temporário
    if ENV['OPENAI_API_KEY'].present?
      return OpenStruct.new(
        account: @conversation.account,
        settings: { 'api_key' => ENV['OPENAI_API_KEY'] },
        enabled?: true
      )
    end

    # Senão, busca o hook real configurado
    hook = Integrations::Hook.find_by(account_id: @conversation.account_id, app_id: 'openai')
    hook if hook&.enabled?
  end
end

