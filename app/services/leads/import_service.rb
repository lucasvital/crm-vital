class Leads::ImportService
  MAX_PREVIEW_ROWS = 5
  MAX_IMPORT_ROWS = 1000

  def initialize(account)
    @account = account
  end

  def preview_csv(file)
    csv_data = read_csv_file(file)
    return { success: false, error: 'Invalid CSV file' } unless csv_data

    csv = CSV.parse(csv_data, headers: true)
    
    {
      success: true,
      columns: csv.headers || [],
      preview_rows: csv.first(MAX_PREVIEW_ROWS).map(&:to_h),
      total_rows: csv.count
    }
  rescue CSV::MalformedCSVError => e
    { success: false, error: "Malformed CSV: #{e.message}" }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def process_import(file:, column_mapping:, pipeline_id:, pipeline_stage_id:)
    csv_data = read_csv_file(file)
    return { success: false, error: 'Invalid CSV file' } unless csv_data

    csv = CSV.parse(csv_data, headers: true)
    
    if csv.count > MAX_IMPORT_ROWS
      return { success: false, error: "CSV has too many rows. Maximum is #{MAX_IMPORT_ROWS}" }
    end

    success_count = 0
    error_count = 0
    errors = []

    csv.each_with_index do |row, index|
      row_number = index + 2 # +2 because index is 0-based and we skip header
      
      # Mapear colunas para campos
      mapped_data = map_row_data(row, column_mapping)
      
      # Validar dados obrigatórios
      validation_error = validate_required_fields(mapped_data)
      if validation_error
        error_count += 1
        errors << { row: row_number, error: validation_error }
        next
      end

      # Criar lead
      result = create_lead(mapped_data, pipeline_id, pipeline_stage_id)
      
      if result[:success]
        success_count += 1
      else
        error_count += 1
        errors << { row: row_number, error: result[:errors].join(', ') }
      end
    end

    {
      success: true,
      success_count: success_count,
      error_count: error_count,
      errors: errors
    }
  rescue CSV::MalformedCSVError => e
    { success: false, error: "Malformed CSV: #{e.message}" }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def read_csv_file(file)
    if file.is_a?(String)
      # File path
      return nil unless File.exist?(file)
      data = File.read(file)
    elsif file.respond_to?(:read)
      # Uploaded file object
      data = file.read
      file.rewind if file.respond_to?(:rewind)
    elsif file.respond_to?(:tempfile)
      # ActionDispatch::Http::UploadedFile
      data = file.tempfile.read
      file.tempfile.rewind
    else
      return nil
    end

    # Ensure UTF-8 encoding
    utf8_data = data.force_encoding('UTF-8')
    utf8_data.valid_encoding? ? utf8_data : utf8_data.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')
  end

  def map_row_data(row, column_mapping)
    mapped = {}
    
    column_mapping.each do |csv_column, system_field|
      next if system_field.blank? || system_field == 'skip'
      value = row[csv_column]
      mapped[system_field] = value if value.present?
    end
    
    mapped
  end

  def validate_required_fields(data)
    return 'Name is required' if data['contact_name'].blank?
    return 'Email is required' if data['contact_email'].blank?
    return 'Phone is required' if data['contact_phone'].blank?
    nil
  end

  def create_lead(mapped_data, pipeline_id, pipeline_stage_id)
    contact_params = {
      name: mapped_data['contact_name'],
      email: mapped_data['contact_email'],
      phone_number: mapped_data['contact_phone'],
      company_name: mapped_data['contact_company'],
      city: mapped_data['contact_city'],
      country: mapped_data['contact_country']
    }.compact

    deal_params = {
      title: mapped_data['deal_title'] || "Lead - #{mapped_data['contact_name']}",
      amount: mapped_data['deal_amount']&.to_f || 0,
      currency: mapped_data['deal_currency'] || 'BRL',
      close_date: parse_date(mapped_data['deal_close_date']),
      notes: mapped_data['deal_notes'],
      pipeline_id: pipeline_id,
      pipeline_stage_id: pipeline_stage_id
    }.compact

    # Extrair labels
    contact_labels = mapped_data['contact_labels']
    deal_labels = mapped_data['deal_labels']
    
    # Se não há deal_labels mas há contact_labels, usar as mesmas para o deal
    deal_labels = contact_labels if deal_labels.blank? && contact_labels.present?

    Rails.logger.info "=== Import: contact_labels = #{contact_labels.inspect}"
    Rails.logger.info "=== Import: deal_labels = #{deal_labels.inspect}"
    Rails.logger.info "=== Import: mapped_data keys = #{mapped_data.keys.inspect}"

    Leads::CreatorService.new(
      account: @account,
      contact_params: contact_params,
      deal_params: deal_params,
      contact_labels: contact_labels,
      deal_labels: deal_labels
    ).perform
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    Date.parse(date_string.to_s)
  rescue ArgumentError
    nil
  end
end

