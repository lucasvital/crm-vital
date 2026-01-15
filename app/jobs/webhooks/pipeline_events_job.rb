class Webhooks::PipelineEventsJob < ApplicationJob
  queue_as :medium

  def perform(pipeline_webhook_id, payload)
    Rails.logger.info "=" * 80
    Rails.logger.info "🔄 STARTING PipelineEventsJob"
    Rails.logger.info "   Webhook ID: #{pipeline_webhook_id}"
    Rails.logger.info "   Payload: #{payload.inspect}"
    Rails.logger.info "=" * 80
    
    pipeline_webhook = PipelineWebhook.find_by(id: pipeline_webhook_id)
    
    unless pipeline_webhook
      Rails.logger.error "❌ PipelineWebhook not found: #{pipeline_webhook_id}"
      return
    end

    Rails.logger.info "✅ Found webhook: #{pipeline_webhook.name} (ID: #{pipeline_webhook.id})"
    Rails.logger.info "   Pipeline: #{pipeline_webhook.pipeline.name}"
    Rails.logger.info "   Stage: #{pipeline_webhook.pipeline_stage.name}"
    Rails.logger.info "   Field Mapping: #{pipeline_webhook.field_mapping.inspect}"
    Rails.logger.info "   Tag Config: #{pipeline_webhook.tag_config.inspect}"
    
    Rails.logger.info "🔧 Starting PipelineProcessorService..."
    result = Webhooks::PipelineProcessorService.new(pipeline_webhook, payload).process
    
    if result[:success]
      Rails.logger.info "=" * 80
      Rails.logger.info "✅ SUCCESS - Pipeline webhook processed"
      Rails.logger.info "   Contact ID: #{result[:contact]&.id}"
      Rails.logger.info "   Contact Name: #{result[:contact]&.name}"
      Rails.logger.info "   Contact Email: #{result[:contact]&.email}"
      Rails.logger.info "   Contact Phone: #{result[:contact]&.phone_number}"
      Rails.logger.info "   Deal ID: #{result[:deal]&.id}"
      Rails.logger.info "   Deal Title: #{result[:deal]&.title}"
      Rails.logger.info "=" * 80
    else
      Rails.logger.error "=" * 80
      Rails.logger.error "❌ FAILED - Pipeline webhook processing"
      Rails.logger.error "   Errors: #{result[:errors]}"
      Rails.logger.error "=" * 80
    end
  rescue StandardError => e
    Rails.logger.error "=" * 80
    Rails.logger.error "💥 EXCEPTION in PipelineEventsJob"
    Rails.logger.error "   Error: #{e.message}"
    Rails.logger.error "   Class: #{e.class}"
    Rails.logger.error "   Backtrace:"
    e.backtrace.first(10).each { |line| Rails.logger.error "     #{line}" }
    Rails.logger.error "=" * 80
    raise # Re-raise para permitir retry do Sidekiq
  end
end

