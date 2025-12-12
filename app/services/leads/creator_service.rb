class Leads::CreatorService
  def initialize(account:, contact_params:, deal_params:, contact_labels: nil, deal_labels: nil)
    @account = account
    @contact_params = contact_params
    @deal_params = deal_params
    @contact_labels = contact_labels
    @deal_labels = deal_labels
    @errors = []
  end

  def perform
    ActiveRecord::Base.transaction do
      find_or_create_contact
      return { success: false, errors: @errors } if @errors.any?

      # Criar ContactInbox para WhatsApp
      create_contact_inboxes_for_whatsapp

      create_deal
      return { success: false, errors: @errors } if @errors.any?

      # Aplicar labels DEPOIS de salvar contato e deal
      apply_contact_labels if @contact_labels.present?
      apply_deal_labels if @deal_labels.present?

      # Recarregar para garantir que labels foram salvas
      @contact.reload if @contact.persisted?
      @deal.reload if @deal.persisted?

      Rails.logger.info "=== FINAL - Contact #{@contact.id} labels: #{@contact.label_list.inspect}"
      Rails.logger.info "=== FINAL - Deal #{@deal.id} labels: #{@deal.label_list.inspect}"

      { success: true, contact: @contact, deal: @deal }
    end
  rescue StandardError => e
    Rails.logger.error "=== ERROR in CreatorService: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, errors: [e.message] }
  end

  private

  def find_or_create_contact
    # Tentar encontrar contato existente por email ou telefone
    @contact = find_existing_contact
    
    if @contact
      # Atualizar informações do contato se fornecidas
      update_contact_if_needed
    else
      # Criar novo contato
      create_new_contact
    end
  end

  def find_existing_contact
    contact = nil
    
    if @contact_params[:email].present?
      contact = @account.contacts.find_by(email: @contact_params[:email])
    end
    
    if contact.nil? && @contact_params[:phone_number].present?
      formatted_phone = format_phone_number(@contact_params[:phone_number])
      contact = @account.contacts.find_by(phone_number: formatted_phone)
    end
    
    contact
  end

  def update_contact_if_needed
    # Atualizar apenas campos que não estão vazios
    update_attrs = {}
    update_attrs[:name] = @contact_params[:name] if @contact_params[:name].present?
    update_attrs[:email] = @contact_params[:email] if @contact_params[:email].present? && @contact.email.blank?
    update_attrs[:phone_number] = format_phone_number(@contact_params[:phone_number]) if @contact_params[:phone_number].present? && @contact.phone_number.blank?
    update_attrs[:additional_attributes] ||= {}
    update_attrs[:additional_attributes][:company_name] = @contact_params[:company_name] if @contact_params[:company_name].present?
    update_attrs[:additional_attributes][:city] = @contact_params[:city] if @contact_params[:city].present?
    update_attrs[:additional_attributes][:country] = @contact_params[:country] if @contact_params[:country].present?
    
    if update_attrs.any?
      unless @contact.update(update_attrs)
        @errors.concat(@contact.errors.full_messages)
      end
    end
  end

  def create_new_contact
    @contact = @account.contacts.new(
      name: @contact_params[:name],
      email: @contact_params[:email],
      phone_number: format_phone_number(@contact_params[:phone_number]),
      additional_attributes: {
        company_name: @contact_params[:company_name],
        city: @contact_params[:city],
        country: @contact_params[:country]
      }.compact
    )
    
    unless @contact.save
      @errors.concat(@contact.errors.full_messages)
    end
  end

  def create_deal
    @deal = @account.deals.new(
      contact: @contact,
      pipeline_id: @deal_params[:pipeline_id],
      pipeline_stage_id: @deal_params[:pipeline_stage_id],
      title: @deal_params[:title] || "Lead - #{@contact.name}",
      amount: @deal_params[:amount] || 0,
      currency: @deal_params[:currency] || 'BRL',
      close_date: @deal_params[:close_date],
      notes: @deal_params[:notes]
    )
    
    unless @deal.save
      @errors.concat(@deal.errors.full_messages)
    end
  end

  def format_phone_number(phone_number)
    return nil if phone_number.blank?
    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def apply_contact_labels
    labels = parse_labels(@contact_labels)
    Rails.logger.info "=== Applying contact labels: #{labels.inspect} to contact #{@contact.id}"
    if labels.any?
      # Sanitizar labels e garantir que existem
      sanitized_labels = labels.map { |l| sanitize_label_title(l) }
      ensure_labels_exist(labels)  # Cria com nome sanitizado
      
      @contact.add_labels(sanitized_labels)  # Aplica com nome sanitizado
      Rails.logger.info "=== Contact labels after apply: #{@contact.label_list.inspect}"
    end
  rescue StandardError => e
    Rails.logger.error "=== Error applying contact labels: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @errors << "Error applying contact labels: #{e.message}"
  end

  def apply_deal_labels
    labels = parse_labels(@deal_labels)
    Rails.logger.info "=== Applying deal labels: #{labels.inspect} to deal #{@deal.id}"
    if labels.any?
      # Sanitizar labels e garantir que existem
      sanitized_labels = labels.map { |l| sanitize_label_title(l) }
      ensure_labels_exist(labels)  # Cria com nome sanitizado
      
      @deal.add_labels(sanitized_labels)  # Aplica com nome sanitizado
      Rails.logger.info "=== Deal labels after apply: #{@deal.label_list.inspect}"
    end
  rescue StandardError => e
    Rails.logger.error "=== Error applying deal labels: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @errors << "Error applying deal labels: #{e.message}"
  end

  def ensure_labels_exist(label_names)
    label_names.each do |title|
      # Sanitizar título: remover/substituir caracteres inválidos
      # Label aceita apenas: letras unicode, números, hífen e underscore
      sanitized_title = sanitize_label_title(title)
      
      label = @account.labels.find_or_initialize_by(title: sanitized_title)
      if label.new_record?
        label.color = generate_random_color
        label.show_on_sidebar = true
        label.save!
        Rails.logger.info "=== Created new label: #{label.title} (#{label.color})"
      end
    end
  end

  def sanitize_label_title(title)
    # Substituir caracteres inválidos por underscore ou hífen
    sanitized = title.to_s
                     .gsub('/', '-')      # Barra vira hífen
                     .gsub(/[^\p{L}\p{N}\-_]/, '_')  # Outros caracteres inválidos viram underscore
                     .gsub(/_{2,}/, '_')  # Múltiplos underscores viram um só
                     .gsub(/-{2,}/, '-')  # Múltiplos hífens viram um só
                     .downcase
    
    Rails.logger.info "=== Sanitized label: '#{title}' -> '#{sanitized}'"
    sanitized
  end

  def generate_random_color
    # Gera cores vibrantes e legíveis
    colors = ['#1f93ff', '#22c55e', '#ef4444', '#f59e0b', '#8b5cf6', '#ec4899', '#06b6d4', '#10b981']
    colors.sample
  end

  def parse_labels(labels_input)
    return [] if labels_input.blank?
    
    # Se for array, retorna direto
    return labels_input if labels_input.is_a?(Array)
    
    # Se for string, separa por vírgula e limpa espaços
    labels_input.to_s.split(',').map(&:strip).reject(&:blank?)
  end

  def create_contact_inboxes_for_whatsapp
    return unless @contact.phone_number.present?
    
    # Buscar todos os inboxes de WhatsApp da conta
    whatsapp_inboxes = @account.inboxes.where(channel_type: 'Channel::Whatsapp')
    
    whatsapp_inboxes.each do |inbox|
      begin
        ContactInboxBuilder.new(
          contact: @contact,
          inbox: inbox
        ).perform
        
        Rails.logger.info "=== Created ContactInbox for contact #{@contact.id} in inbox #{inbox.id}"
      rescue StandardError => e
        Rails.logger.warn "=== Failed to create ContactInbox: #{e.message}"
        # Não interromper o processo se falhar
      end
    end
  end
end

