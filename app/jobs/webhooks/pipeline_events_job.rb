class Webhooks::PipelineEventsJob < ApplicationJob
  queue_as :medium

  def perform(pipeline_webhook_id, payload)
    pipeline_webhook = PipelineWebhook.find_by(id: pipeline_webhook_id)
    
    unless pipeline_webhook
      Rails.logger.error "PipelineWebhook not found: #{pipeline_webhook_id}"
      return
    end

    Rails.logger.info "Processing pipeline webhook #{pipeline_webhook_id} with payload: #{payload.inspect}"
    
    result = Webhooks::PipelineProcessorService.new(pipeline_webhook, payload).process
    
    if result[:success]
      Rails.logger.info "Pipeline webhook #{pipeline_webhook_id} processed successfully. Contact: #{result[:contact]&.id}, Deal: #{result[:deal]&.id}"
    else
      Rails.logger.error "Pipeline webhook #{pipeline_webhook_id} processing failed: #{result[:errors]}"
    end
  rescue StandardError => e
    Rails.logger.error "Pipeline webhook job error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise para permitir retry do Sidekiq
  end
end

