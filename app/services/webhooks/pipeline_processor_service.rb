class Webhooks::PipelineProcessorService
  def initialize(pipeline_webhook, payload)
    @webhook = pipeline_webhook
    @payload = payload
    @account = pipeline_webhook.account
    @pipeline = pipeline_webhook.pipeline
    @pipeline_stage = pipeline_webhook.pipeline_stage
  end

  def process
    Rails.logger.info "📦 PipelineProcessorService - Starting"
    Rails.logger.info "   Payload received: #{@payload.inspect}"
    
    # 1. Mapear campos do payload
    Rails.logger.info "🔍 Step 1: Mapping contact fields..."
    contact_params = map_contact_fields
    Rails.logger.info "   Contact params: #{contact_params.inspect}"
    
    Rails.logger.info "🔍 Step 2: Mapping deal fields..."
    deal_params = map_deal_fields
    Rails.logger.info "   Deal params: #{deal_params.inspect}"
    
    Rails.logger.info "🔍 Step 3: Mapping custom attributes..."
    custom_attrs = map_custom_attributes
    Rails.logger.info "   Custom attributes: #{custom_attrs.inspect}"
    
    Rails.logger.info "🔍 Step 4: Extracting labels..."
    labels = extract_labels
    Rails.logger.info "   Labels: #{labels.inspect}"

    Rails.logger.info "🔍 Step 5: Building existing lead config..."
    existing_lead_config = build_existing_lead_config
    Rails.logger.info "   Existing lead config: #{existing_lead_config.inspect}"

    # 2. Criar lead via Leads::CreatorService
    Rails.logger.info "🚀 Step 6: Creating/updating lead via CreatorService..."
    result = Leads::CreatorService.new(
      account: @account,
      contact_params: contact_params,
      deal_params: deal_params,
      contact_labels: labels,
      deal_labels: labels,
      custom_attributes: custom_attrs,
      existing_lead_config: existing_lead_config
    ).perform
    
    # 3. Log e retorno
    if result[:success]
      Rails.logger.info "✅ Pipeline Webhook #{@webhook.id} processed successfully"
      Rails.logger.info "   Contact: #{result[:contact].id}, Deal: #{result[:deal].id}"
    else
      Rails.logger.error "❌ Pipeline Webhook #{@webhook.id} failed: #{result[:errors]}"
    end
    
    result
  rescue StandardError => e
    Rails.logger.error "💥 PipelineProcessorService EXCEPTION"
    Rails.logger.error "   Error: #{e.message}"
    Rails.logger.error "   Class: #{e.class}"
    Rails.logger.error "   Backtrace:"
    e.backtrace.first(10).each { |line| Rails.logger.error "     #{line}" }
    { success: false, errors: [e.message] }
  end

  private

  def map_contact_fields
    mapping = @webhook.field_mapping || {}
    
    {
      name: extract_field(mapping['name']),
      email: extract_field(mapping['email']),
      phone_number: normalize_phone_number(extract_field(mapping['phone_number'])),
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

  def map_custom_attributes
    mapping = @webhook.field_mapping || {}
    custom_mapping = mapping['custom_attributes'] || {}
    
    result = {}
    custom_mapping.each do |attribute_key, field_path|
      value = extract_field(field_path)
      result[attribute_key] = value if value.present?
    end
    
    Rails.logger.info "Mapped custom attributes: #{result.inspect}"
    result
  end

  def extract_labels
    labels_config = @webhook.tag_config || {}
    labels_config['labels'] || []
  end

  def build_existing_lead_config
    {
      action: @webhook.existing_lead_action || 'create_new',
      stage_id: @webhook.existing_lead_stage_id
    }
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
    
    extracted_value = value.presence
    Rails.logger.debug "   📌 extract_field('#{field_path}') => #{extracted_value.inspect}"
    extracted_value
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

  def normalize_phone_number(phone)
    return nil if phone.blank?
    
    # Remove todos os caracteres especiais (espaços, parênteses, hífens, pontos)
    # Mantém apenas números e o sinal de +
    cleaned = phone.to_s.gsub(/[^\d\+]/, '')
    
    # Se não começar com +, adiciona o +
    cleaned = "+#{cleaned}" unless cleaned.start_with?('+')
    
    # Log para debug
    Rails.logger.info "   📞 Normalized phone: '#{phone}' -> '#{cleaned}'" if phone != cleaned
    
    cleaned
  end
end

