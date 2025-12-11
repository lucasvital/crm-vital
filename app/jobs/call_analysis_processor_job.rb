# frozen_string_literal: true

class CallAnalysisProcessorJob < ApplicationJob
  queue_as :default

  def perform(call_analysis_id)
    call_analysis = CallAnalysis.find(call_analysis_id)
    return if call_analysis.processing_status == 'completed'

    call_analysis.update!(processing_status: 'processing')

    result = CallAnalysisService::Analyzer.new(
      transcript: call_analysis.transcript,
      account: call_analysis.account,
      user: call_analysis.user
    ).analyze

    call_analysis.update!(
      analysis_result: result,
      summary: result[:summary],
      next_steps: result[:next_steps],
      objections: result[:objections],
      competitors_mentioned: result[:competitors_mentioned],
      seller_score: result[:seller_score],
      pdi_points: result[:pdi_points],
      processing_status: 'completed',
      processing_error: nil
    )
  rescue StandardError => e
    Rails.logger.error("CallAnalysisProcessorJob error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    call_analysis&.update!(
      processing_status: 'failed',
      processing_error: e.message
    )
  end
end

