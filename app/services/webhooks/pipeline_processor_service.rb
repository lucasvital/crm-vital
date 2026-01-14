class Webhooks::PipelineProcessorService
  def initialize(pipeline_webhook, payload)
    @webhook = pipeline_webhook
    @payload = payload
    @account = pipeline_webhook.account
    @pipeline = pipeline_webhook.pipeline
    @pipeline_stage = pipeline_webhook.pipeline_stage
  end

  def process
    # 1. Mapear campos do payload
    contact_params = map_contact_fields
    deal_params = map_deal_fields
    
    # 2. Criar lead via Leads::CreatorService
    result = Leads::CreatorService.new(
      account: @account,
      contact_params: contact_params,
      deal_params: deal_params,
      contact_labels: extract_labels,
      deal_labels: extract_labels
    ).perform
    
    # 3. Log e retorno
    if result[:success]
      Rails.logger.info "Pipeline Webhook #{@webhook.id} processed successfully"
      Rails.logger.info "Contact: #{result[:contact].id}, Deal: #{result[:deal].id}"
    else
      Rails.logger.error "Pipeline Webhook #{@webhook.id} failed: #{result[:errors]}"
    end
    
    result
  rescue StandardError => e
    Rails.logger.error "PipelineProcessorService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, errors: [e.message] }
  end

  private

  def map_contact_fields
    mapping = @webhook.field_mapping || {}
    
    {
      name: extract_field(mapping['name']),
      email: extract_field(mapping['email']),
      phone_number: extract_field(mapping['phone_number']),
      company_name: extract_field(mapping['company_name']),
      city: extract_field(mapping['city']),
      country: extract_field(mapping['country'])
    }.compact
  end

  def map_deal_fields
    mapping = @webhook.field_mapping || {}
    
    {
      pipeline_id: @pipeline.id,
      pipeline_stage_id: @pipeline_stage.id,
      title: extract_field(mapping['title']) || "Lead via #{@webhook.name}",
      amount: extract_field(mapping['amount'])&.to_f || 0.0,
      currency: 'BRL',
      close_date: parse_date(extract_field(mapping['close_date'])),
      notes: extract_field(mapping['notes'])
    }.compact
  end

  def extract_labels
    labels_config = @webhook.tag_config || {}
    labels_config['labels'] || []
  end

  def extract_field(field_path)
    return nil if field_path.blank?
    
    # Suporta notação de ponto para campos aninhados (ex: "lead.name", "data.email")
    keys = field_path.to_s.split('.')
    value = @payload
    
    keys.each do |key|
      value = value.is_a?(Hash) ? (value[key] || value[key.to_sym]) : nil
      break if value.nil?
    end
    
    value.presence
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Tentar vários formatos de data
    [
      '%Y-%m-%d',
      '%d/%m/%Y',
      '%m/%d/%Y',
      '%Y/%m/%d'
    ].each do |format|
      begin
        return Date.strptime(date_string.to_s, format)
      rescue ArgumentError, TypeError
        next
      end
    end
    
    # Tentar parse genérico
    begin
      Date.parse(date_string.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end

