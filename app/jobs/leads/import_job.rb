# frozen_string_literal: true

class Leads::ImportJob < ApplicationJob
  queue_as :low

  LEADS_IMPORT_STATUS_TTL = 24.hours

  def perform(import_id, account_id, column_mapping, pipeline_id, pipeline_stage_id)
    job_id = self.job_id
    status_key = format(::Redis::RedisKeys::LEADS_IMPORT_STATUS, job_id: job_id)
    file_key = format(::Redis::RedisKeys::LEADS_IMPORT_FILE, import_id: import_id)

    # Em produção o Sidekiq roda em outro processo/container; o CSV vem do Redis (gravado pelo controller)
    csv_content = Redis::Alfred.get(file_key)
    unless csv_content.present?
      write_status(status_key, status: 'failed', error_message: 'Invalid CSV file')
      return
    end
    csv_consumed = true

    account = Account.find(account_id)
    column_mapping = column_mapping.to_h.with_indifferent_access if column_mapping.respond_to?(:to_h)

    write_status(status_key, status: 'running', total_rows: 0, processed_rows: 0, success_count: 0, error_count: 0, errors: [])

    on_progress = proc do |processed_rows, total_rows, success_count, error_count|
      write_status(
        status_key,
        status: 'running',
        total_rows: total_rows,
        processed_rows: processed_rows,
        success_count: success_count,
        error_count: error_count,
        errors: []
      )
    end

    temp_file = Tempfile.create(['leads_import', '.csv'])
    temp_file.binmode
    temp_file.write(csv_content)
    temp_file.rewind
    temp_file.close

    result = Leads::ImportService.new(account).process_import(
      file: temp_file.path,
      column_mapping: column_mapping,
      pipeline_id: pipeline_id,
      pipeline_stage_id: pipeline_stage_id,
      on_progress: on_progress
    )

    unless result[:success]
      write_status(status_key, status: 'failed', error_message: result[:error].to_s)
      return
    end

    write_status(
      status_key,
      status: 'completed',
      total_rows: result[:success_count].to_i + result[:error_count].to_i,
      processed_rows: result[:success_count].to_i + result[:error_count].to_i,
      success_count: result[:success_count],
      error_count: result[:error_count],
      errors: result[:errors] || []
    )
  rescue StandardError => e
    Rails.logger.error "Leads::ImportJob failed: #{e.class} #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    write_status(
      status_key,
      status: 'failed',
      error_message: e.message.presence || e.class.name
    )
  ensure
    if defined?(temp_file) && temp_file
      temp_file.close
      FileUtils.rm_f(temp_file.path)
    end
    Redis::Alfred.delete(file_key) if file_key && defined?(csv_consumed) && csv_consumed
  end

  private

  def write_status(key, payload)
    value = payload.to_json
    Redis::Alfred.setex(key, value, LEADS_IMPORT_STATUS_TTL)
  end
end
