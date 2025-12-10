class DataImport::CsvAnalyzer
  def initialize(file)
    @file = file
  end

  def analyze
    data = read_file_with_encoding
    csv = CSV.parse(data, headers: true)
    
    return [] if csv.headers.blank?
    
    csv.headers.compact.map(&:strip)
  end

  private

  def read_file_with_encoding
    # Handle both file upload and string
    data = if @file.respond_to?(:read)
             content = @file.read
             @file.rewind if @file.respond_to?(:rewind) # Important for subsequent reads
             content
           elsif @file.is_a?(String)
             @file
           else
             raise ArgumentError, 'Invalid file type'
           end
    
    utf8_data = data.force_encoding('UTF-8')
    utf8_data.valid_encoding? ? utf8_data : utf8_data.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')
  end
end

