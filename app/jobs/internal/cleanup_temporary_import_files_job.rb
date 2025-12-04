class Internal::CleanupTemporaryImportFilesJob < ApplicationJob
  queue_as :housekeeping

  def perform
    import_dir = Rails.root.join('tmp', 'imports')
    return unless Dir.exist?(import_dir)

    cutoff_time = 24.hours.ago
    removed_count = 0

    Dir.glob(File.join(import_dir, '*.csv')).each do |file_path|
      next unless File.mtime(file_path) < cutoff_time

      File.delete(file_path)
      removed_count += 1
    rescue StandardError => e
      Rails.logger.error "Failed to delete temporary import file #{file_path}: #{e.message}"
      ChatwootExceptionTracker.new(e, account: nil).capture_exception
    end

    Rails.logger.info "Cleanup temporary import files: removed #{removed_count} file(s)"
  end
end

