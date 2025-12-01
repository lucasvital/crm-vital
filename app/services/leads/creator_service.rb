class Leads::CreatorService
  def initialize(account:, contact_params:, deal_params:)
    @account = account
    @contact_params = contact_params
    @deal_params = deal_params
    @errors = []
  end

  def perform
    ActiveRecord::Base.transaction do
      find_or_create_contact
      return { success: false, errors: @errors } if @errors.any?

      create_deal
      return { success: false, errors: @errors } if @errors.any?

      { success: true, contact: @contact, deal: @deal }
    end
  rescue StandardError => e
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
end

