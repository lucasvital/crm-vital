class DataImport::ContactManager
  def initialize(account, column_mapping = nil)
    @account = account
    @column_mapping = column_mapping
  end

  def build_contact(params)
    contact = find_or_initialize_contact(params)
    update_contact_attributes(params, contact)
    contact
  end

  def build_contact_with_mapping(row)
    return build_contact(row) if @column_mapping.blank?

    mapped_params = apply_column_mapping(row)
    build_contact(mapped_params)
  end

  def find_or_initialize_contact(params)
    contact = find_existing_contact(params)
    contact_params = params.slice(:email, :identifier, :phone_number)
    contact_params[:phone_number] = format_phone_number(contact_params[:phone_number]) if contact_params[:phone_number].present?
    contact ||= @account.contacts.new(contact_params)
    contact
  end

  def find_existing_contact(params)
    contact = find_contact_by_identifier(params)
    contact ||= find_contact_by_email(params)
    contact ||= find_contact_by_phone_number(params)

    update_contact_with_merged_attributes(params, contact) if contact.present? && contact.valid?
    contact
  end

  def find_contact_by_identifier(params)
    return unless params[:identifier]

    @account.contacts.find_by(identifier: params[:identifier])
  end

  def find_contact_by_email(params)
    return unless params[:email]

    @account.contacts.from_email(params[:email])
  end

  def find_contact_by_phone_number(params)
    return unless params[:phone_number]

    @account.contacts.find_by(phone_number: format_phone_number(params[:phone_number]))
  end

  def format_phone_number(phone_number)
    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def update_contact_with_merged_attributes(params, contact)
    contact.identifier = params[:identifier] if params[:identifier].present?
    contact.email = params[:email] if params[:email].present?
    contact.phone_number = format_phone_number(params[:phone_number]) if params[:phone_number].present?
    update_contact_attributes(params, contact)
    contact.save # rubocop:disable Rails/SaveBang
  end

  private

  def apply_column_mapping(row)
    mapped = {}
    custom_attrs = {}

    # Ensure column_mapping has string keys to match CSV headers
    column_mapping = @column_mapping.is_a?(Hash) ? @column_mapping.stringify_keys : @column_mapping

    row.each do |original_column, value|
      next if value.blank?

      mapped_field = column_mapping[original_column.to_s]
      next if mapped_field.blank? || mapped_field == 'ignore'

      # Strip whitespace from values
      cleaned_value = value.to_s.strip

      # Standard fields
      if %w[name email phone_number identifier].include?(mapped_field)
        mapped[mapped_field.to_sym] = cleaned_value
      elsif %w[company city].include?(mapped_field)
        # Company and city go to additional_attributes, will be handled in update_contact_attributes
        mapped[mapped_field.to_sym] = cleaned_value
      else
        # Custom attributes
        custom_attrs[mapped_field] = cleaned_value
      end
    end

    mapped.merge(custom_attrs)
  end

  def update_contact_attributes(params, contact)
    contact.name = params[:name] if params[:name].present?
    contact.additional_attributes ||= {}
    contact.additional_attributes[:company] = params[:company] if params[:company].present?
    contact.additional_attributes[:city] = params[:city] if params[:city].present?
    contact.assign_attributes(custom_attributes: contact.custom_attributes.merge(params.except(:identifier, :email, :name, :phone_number, :company, :city)))
  end
end
