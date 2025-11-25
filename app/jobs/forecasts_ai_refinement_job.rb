class ForecastsAiRefinementJob < ApplicationJob
  queue_as :default

  def perform(forecast_id, prompt)
    forecast = Forecast.find_by(id: forecast_id)
    return unless forecast

    ai_content = Forecasts::GenerateService.new.call_refine(prompt)
    return if ai_content.blank?

    parsed = JSON.parse(ai_content) rescue nil
    return unless parsed

    weekly = parsed['weekly_forecast'] || forecast.weekly_forecast || []
    monthly = parsed['monthly_forecast'] || forecast.monthly_forecast || []

    forecast.update(
      weekly_forecast: weekly,
      monthly_forecast: monthly,
      risks: parsed['risks'] || forecast.risks || [],
      opportunities: parsed['opportunities'] || forecast.opportunities || [],
      confidence_level: parsed['confidence_level'] || forecast.confidence_level || 70,
      key_insights: parsed['key_insights'] || forecast.key_insights || [],
      recommendations: parsed['recommendations'] || forecast.recommendations || [],
      summary: parsed['summary'] || forecast.summary,
      metadata: (forecast.metadata || {}).merge(ai_status: 'ai_refined')
    )
  rescue StandardError
    # swallow errors in background job
  end
end

