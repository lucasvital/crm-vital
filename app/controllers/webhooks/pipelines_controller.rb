class Webhooks::PipelinesController < ActionController::API
  def process_payload
    pipeline_webhook = PipelineWebhook.find_by(token: params[:token])

    if pipeline_webhook.blank?
      Rails.logger.warn("Pipeline webhook not found for token: #{params[:token]}")
      render json: { error: 'Webhook not found' }, status: :not_found
      return
    end

    unless pipeline_webhook.active?
      Rails.logger.warn("Pipeline webhook inactive: #{pipeline_webhook.id}")
      render json: { error: 'Webhook is inactive' }, status: :unprocessable_entity
      return
    end

    # Enfileirar processamento assíncrono
    Webhooks::PipelineEventsJob.perform_later(pipeline_webhook.id, request_payload)
    
    head :ok
  rescue StandardError => e
    Rails.logger.error "Pipeline webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  private

  def request_payload
    # Capturar todo o payload JSON ou form data
    if request.content_type&.include?('application/json')
      JSON.parse(request.body.read)
    else
      params.except(:token, :controller, :action).to_unsafe_hash
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse JSON payload: #{e.message}"
    {}
  end
end

