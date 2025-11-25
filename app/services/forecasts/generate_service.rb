class Forecasts::GenerateService
  def initialize
    api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value || ENV['OPENAI_API_KEY']
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    @client = OpenAI::Client.new(access_token: api_key, uri_base: endpoint.presence || 'https://api.openai.com/', log_errors: Rails.env.development?)
  end

  def call(prompt)
    response = @client.chat(parameters: { model: 'gpt-4o-mini', response_format: { type: 'json_object' }, messages: [
      { role: 'system', content: 'Você é um especialista em previsão de vendas e análise de pipeline. Sempre responda em formato JSON estruturado conforme solicitado, com todos os textos em português brasileiro.' },
      { role: 'user', content: prompt }
    ], temperature: 0.5, max_tokens: 2000 })
    response.dig('choices', 0, 'message', 'content')
  end
end

