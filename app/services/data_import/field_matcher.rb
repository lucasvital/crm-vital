class DataImport::FieldMatcher
  FIELD_PATTERNS = {
    name: ['name', 'nome', 'full name', 'fullname', 'nome completo', 'contact name'],
    email: ['email', 'e-mail', 'mail', 'correo', 'correio'],
    phone_number: ['phone', 'telephone', 'telefone', 'tel', 'celular', 'cell', 'mobile', 'whatsapp', 'phone number', 'phone_number'],
    identifier: ['id', 'identifier', 'identificador', 'contact id', 'external id', 'external_id'],
    company: ['company', 'empresa', 'organization', 'organizacao', 'compania'],
    city: ['city', 'cidade', 'location', 'localidade']
  }.freeze

  def initialize(columns)
    @columns = columns
  end

  def suggest_mapping
    mapping = {}
    
    @columns.each do |column|
      normalized_column = normalize_string(column)
      matched_field = find_best_match(normalized_column)
      
      mapping[column] = matched_field if matched_field
    end
    
    mapping
  end

  private

  def normalize_string(str)
    return '' if str.blank?
    
    # Remove accents and convert to lowercase
    str.downcase
       .unicode_normalize(:nfkd)
       .gsub(/[^\x00-\x7F]/, '')
       .gsub(/[^a-z0-9\s]/, '')
       .strip
  end

  def find_best_match(normalized_column)
    FIELD_PATTERNS.each do |field, patterns|
      patterns.each do |pattern|
        normalized_pattern = normalize_string(pattern)
        
        # Exact match
        return field.to_s if normalized_column == normalized_pattern
        
        # Contains match
        return field.to_s if normalized_column.include?(normalized_pattern) || normalized_pattern.include?(normalized_column)
      end
    end
    
    nil
  end
end

