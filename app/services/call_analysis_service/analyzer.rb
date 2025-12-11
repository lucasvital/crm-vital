# frozen_string_literal: true

require 'openai'

module CallAnalysisService
  class Analyzer
    attr_reader :transcript, :account, :user

  MAX_TOKENS = 120_000 # GPT-4o suporta até 128k tokens, deixando margem de segurança
  CHARS_PER_TOKEN_ESTIMATE = 4 # Estimativa conservadora

  def initialize(transcript:, account:, user:)
    @transcript = transcript
    @account = account
    @user = user
    @client = OpenAI::Client.new(
      access_token: ENV.fetch('OPENAI_API_KEY', nil),
      log_errors: Rails.env.development?,
      request_timeout: 300 # 5 minutos para transcrições longas
    )
  end

  def analyze
    # Verificar tamanho da transcrição e truncar se necessário
    processed_transcript = ensure_transcript_size(@transcript)
    
    crm_data = extract_crm_data(processed_transcript)
    performance_data = analyze_seller_performance(processed_transcript)
    pdi_data = consolidate_pdi(performance_data)

      {
        crm_extraction: crm_data,
        performance_analysis: performance_data,
        pdi_recommendations: pdi_data,
        summary: crm_data['summary'],
        next_steps: crm_data['next_steps'],
        objections: crm_data['objections'],
        competitors_mentioned: crm_data['competitors_mentioned'],
        seller_score: performance_data['overall_score'],
        pdi_points: pdi_data['improvement_areas']
      }
    rescue StandardError => e
      Rails.logger.error("CallAnalysis::AnalyzerService error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise StandardError, "Erro ao analisar transcrição: #{e.message}"
    end

  private

  def ensure_transcript_size(transcript)
    max_chars = MAX_TOKENS * CHARS_PER_TOKEN_ESTIMATE
    
    if transcript.length > max_chars
      Rails.logger.warn("Transcrição muito longa (#{transcript.length} chars), truncando para #{max_chars} chars")
      # Manter início e fim da transcrição, que geralmente contém informações importantes
      middle_cut = transcript.length - max_chars
      half_keep = max_chars / 2
      "#{transcript[0...half_keep]}\n\n... [#{middle_cut} caracteres omitidos] ...\n\n#{transcript[-half_keep..-1]}"
    else
      transcript
    end
  end

  def extract_crm_data(transcript)
    response = @client.chat(
      parameters: {
        model: model_name,
        messages: [
          { role: 'system', content: PromptBuilder.crm_extractor_prompt },
          { role: 'user', content: "Transcrição da reunião:\n\n#{transcript}" }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.3,
        max_tokens: 4096 # Limitar resposta
      }
    )

    parse_response(response)
  end

  def analyze_seller_performance(transcript)
    response = @client.chat(
      parameters: {
        model: model_name,
        messages: [
          { role: 'system', content: PromptBuilder.seller_performance_prompt },
          { role: 'user', content: "Transcrição da reunião:\n\n#{transcript}" }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.3,
        max_tokens: 4096 # Limitar resposta
      }
    )

    parse_response(response)
  end

    def consolidate_pdi(performance_data)
      previous_analyses = fetch_previous_analyses_summary

      response = @client.chat(
        parameters: {
          model: model_name,
          messages: [
            { role: 'system', content: PromptBuilder.pdi_consolidator_prompt(previous_analyses) },
            { role: 'user', content: "Análise de performance atual:\n\n#{performance_data.to_json}" }
          ],
          response_format: { type: 'json_object' },
          temperature: 0.5
        }
      )

      parse_response(response)
    end

    def fetch_previous_analyses_summary
      return nil unless @user

      recent_analyses = CallAnalysis
                        .where(user_id: @user.id, account_id: @account.id)
                        .order(created_at: :desc)
                        .limit(3)

      return nil if recent_analyses.empty?

      recent_analyses.map do |analysis|
        "Data: #{analysis.created_at.strftime('%d/%m/%Y')} | Score: #{analysis.seller_score} | " \
          "Principais pontos: #{analysis.pdi_points.first(2).join(', ')}"
      end.join("\n")
    end

    def parse_response(response)
      content = response.dig('choices', 0, 'message', 'content')
      JSON.parse(content)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse OpenAI response: #{content}")
      raise e
    end

    def model_name
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || 'gpt-4o'
    end
  end
end

