class Api::V1::Accounts::ForecastsController < Api::V1::Accounts::BaseController
  def history
    records = Forecast.where(account_id: current_account.id, user_id: current_user.id).order(created_at: :desc).limit(10)
    render json: records
  end

  def latest
    record = Forecast.where(account_id: current_account.id, user_id: current_user.id).order(created_at: :desc).limit(1).first
    return render json: {} unless record
    render json: {
      weekly_forecast: record.weekly_forecast,
      monthly_forecast: record.monthly_forecast,
      risks: record.risks,
      opportunities: record.opportunities,
      confidence_level: record.confidence_level,
      key_insights: record.key_insights,
      recommendations: record.recommendations,
      summary: record.summary,
      metadata: record.metadata,
      id: record.id,
      created_at: record.created_at
    }
  end

  def show
    record = Forecast.find_by(id: params[:id], account_id: current_account.id)
    return render json: { error: 'Previsão não encontrada' }, status: :not_found unless record
    render json: {
      weekly_forecast: record.weekly_forecast,
      monthly_forecast: record.monthly_forecast,
      risks: record.risks,
      opportunities: record.opportunities,
      confidence_level: record.confidence_level,
      key_insights: record.key_insights,
      recommendations: record.recommendations,
      summary: record.summary,
      metadata: record.metadata
    }
  end

  def generate
    last = Forecast.where(account_id: current_account.id, user_id: current_user.id).order(created_at: :desc).limit(1).first
    if last && last.created_at >= 7.days.ago
      next_allowed = (last.created_at + 7.days).iso8601
      return render json: { error: 'Você só pode gerar uma previsão por semana.', next_allowed_at: next_allowed }, status: :too_many_requests
    end

    deals = current_account.deals.includes(:contact, :pipeline, :pipeline_stage).order(created_at: :desc)
    return render json: { error: 'Nenhum negócio encontrado. Adicione negócios ao pipeline para gerar previsões.' }, status: :bad_request if deals.empty?

    total_value = deals.sum { |d| d.amount.to_f }
    avg_value = deals.size > 0 ? total_value / deals.size : 0.0
    stage_groups = deals.group_by { |d| d.pipeline_stage&.name.to_s }
    won_value = deals.select { |d| d.won_at.present? }.sum { |d| (d.won_amount_snapshot || d.amount).to_f }
    active_value = deals.reject { |d| d.won_at.present? }.sum { |d| d.amount.to_f }

    stage_lines = stage_groups.map do |name, items|
      sum = items.sum { |d| d.amount.to_f }
      "- #{name}: #{items.size} negócios (R$ #{sum.round(2)})"
    end.join("\n")

    prompt = "Você é um especialista em previsão de vendas. Analise o pipeline atual e gere uma previsão detalhada.\n\n" \
      "DADOS DO PIPELINE ATUAL:\n" \
      "Total de Negócios: #{deals.size}\n" \
      "Valor Total do Pipeline: R$ #{total_value.round(2)}\n" \
      "Valor Médio por Negócio: R$ #{avg_value.round(2)}\n" \
      "Valor Ganho: R$ #{won_value.round(2)}\n" \
      "Valor Ativo no Pipeline: R$ #{active_value.round(2)}\n\n" \
      "Negócios por Estágio:\n#{stage_lines}\n\n" \
      "TAREFA:\nGere uma previsão de vendas completa e realista com base nesses dados. Todos os textos devem estar em PORTUGUÊS.\n\n" \
      "Considere:\n1. Taxa de progressão dos negócios entre estágios\n2. Velocidade do pipeline (tempo médio de fechamento)\n3. Fatores sazonais típicos do mercado\n4. Potencial de conversão dos contatos\n\n" \
      "IMPORTANTE:\n- As previsões devem ser realistas e baseadas nos dados fornecidos\n- O cenário conservador deve ser ~70% do esperado\n- O cenário otimista deve ser ~130% do esperado\n- Considere que negócios em estágios avançados têm maior probabilidade de fechar\n- Use insights específicos baseados nos dados fornecidos"

    ai_content = Forecasts::GenerateService.new.call(prompt)

    parsed = nil
    if ai_content.present?
      begin
        parsed = JSON.parse(ai_content)
      rescue JSON::ParserError
        parsed = nil
      end
    end

    weekly = parsed&.dig('weekly_forecast') || []
    monthly = parsed&.dig('monthly_forecast') || []
    if weekly.empty?
      base = (active_value > 0 ? active_value : total_value) / 4.0
      weekly = Array.new(4) { |i| { week: "Semana #{i + 1}", expected_revenue: base, conservative_revenue: base * 0.7, optimistic_revenue: base * 1.3, expected_deals_closed: (deals.size / 12.0).ceil } }
    end
    if monthly.empty?
      base_m = (active_value > 0 ? active_value : total_value) / 3.0
      monthly = Array.new(3) { |i| { month: "Mês #{i + 1}", expected_revenue: base_m, conservative_revenue: base_m * 0.7, optimistic_revenue: base_m * 1.3, expected_deals_closed: (deals.size / 4.0).ceil } }
    end

    record = Forecast.create!(
      account_id: current_account.id,
      user_id: current_user.id,
      weekly_forecast: weekly,
      monthly_forecast: monthly,
      risks: parsed&.dig('risks') || [],
      opportunities: parsed&.dig('opportunities') || [],
      confidence_level: parsed&.dig('confidence_level') || 70,
      key_insights: parsed&.dig('key_insights') || [],
      recommendations: parsed&.dig('recommendations') || [],
      summary: parsed&.dig('summary') || 'Previsão básica gerada.',
      metadata: {
        generated_at: Time.current.iso8601,
        total_deals: deals.size,
        total_pipeline_value: total_value,
        average_deal_value: avg_value,
        ai_status: parsed.present? ? 'ai_success' : 'fallback_basic'
      }
    )

    render json: {
      weekly_forecast: record.weekly_forecast,
      monthly_forecast: record.monthly_forecast,
      risks: record.risks,
      opportunities: record.opportunities,
      confidence_level: record.confidence_level,
      key_insights: record.key_insights,
      recommendations: record.recommendations,
      summary: record.summary,
      metadata: record.metadata
    }
  end

  def metrics
    deals = current_account.deals
    total_value = deals.sum { |d| d.amount.to_f }
    won_value = deals.select { |d| d.won_at.present? }.sum { |d| (d.won_amount_snapshot || d.amount).to_f }
    active_value = deals.reject { |d| d.won_at.present? }.sum { |d| d.amount.to_f }
    render json: {
      total_deals: deals.size,
      total_pipeline_value: total_value,
      won_deals_value: won_value,
      active_pipeline_value: active_value,
      deals_by_stage: deals.group_by { |d| d.pipeline_stage&.name.to_s }.transform_values(&:size)
    }
  end
end
