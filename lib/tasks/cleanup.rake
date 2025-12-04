namespace :cleanup do
  desc 'Remove temporary import files older than 24 hours'
  task import_files: :environment do
    import_dir = Rails.root.join('tmp', 'imports')
    return unless Dir.exist?(import_dir)

    cutoff_time = 24.hours.ago
    removed_count = 0

    Dir.glob(File.join(import_dir, '*.csv')).each do |file_path|
      if File.mtime(file_path) < cutoff_time
        File.delete(file_path)
        removed_count += 1
      end
    rescue StandardError => e
      Rails.logger.error "Failed to delete import file #{file_path}: #{e.message}"
    end

    Rails.logger.info "Removed #{removed_count} temporary import file(s)"
  end
end

