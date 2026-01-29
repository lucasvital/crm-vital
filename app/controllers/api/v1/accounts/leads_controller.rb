class Api::V1::Accounts::LeadsController < Api::V1::Accounts::BaseController
  def create
    result = Leads::CreatorService.new(
      account: current_account,
      contact_params: contact_params,
      deal_params: deal_params
    ).perform

    if result[:success]
      render json: {
        contact: result[:contact].as_json(only: [:id, :name, :email, :phone_number]),
        deal: result[:deal].as_json(
          only: [:id, :title, :amount, :currency, :close_date, :notes, :pipeline_id],
          include: {
            pipeline_stage: { only: [:id, :name, :key, :position] }
          }
        )
      }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  def import_upload
    unless params[:file].present?
      render json: { error: 'File is required' }, status: :unprocessable_entity
      return
    end

    result = Leads::ImportService.new(current_account).preview_csv(params[:file])
    
    if result[:success]
      # Salvar arquivo temporariamente com ID único
      import_id = SecureRandom.hex(16)
      temp_file_path = Rails.root.join('tmp', 'imports', "#{import_id}.csv")
      FileUtils.mkdir_p(File.dirname(temp_file_path))
      
      # Copiar arquivo para pasta temporária
      if params[:file].respond_to?(:tempfile)
        FileUtils.cp(params[:file].tempfile.path, temp_file_path)
      elsif params[:file].respond_to?(:path)
        FileUtils.cp(params[:file].path, temp_file_path)
      end
      
      render json: {
        import_id: import_id,
        columns: result[:columns],
        preview_rows: result[:preview_rows],
        total_rows: result[:total_rows]
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def import_process
    import_id = params[:import_id]
    unless import_id.present?
      render json: { error: 'Import ID is required' }, status: :unprocessable_entity
      return
    end

    temp_file_path = Rails.root.join('tmp', 'imports', "#{import_id}.csv")
    unless File.exist?(temp_file_path)
      render json: { error: 'Invalid CSV file' }, status: :unprocessable_entity
      return
    end

    job = Leads::ImportJob.perform_later(
      import_id,
      current_account.id,
      params[:column_mapping]&.to_unsafe_h || {},
      params[:pipeline_id],
      params[:pipeline_stage_id]
    )

    render json: { job_id: job.job_id }
  end

  def import_status
    job_id = params[:job_id]
    unless job_id.present?
      render json: { status: 'pending' }, status: :ok
      return
    end

    status_key = format(Redis::RedisKeys::LEADS_IMPORT_STATUS, job_id: job_id)
    raw = Redis::Alfred.get(status_key)

    if raw.blank?
      render json: { status: 'pending' }, status: :ok
      return
    end

    payload = JSON.parse(raw)
    render json: payload, status: :ok
  rescue JSON::ParserError
    render json: { status: 'pending' }, status: :ok
  end

  private

  def contact_params
    params.require(:lead).permit(:name, :email, :phone_number, :company_name, :city, :country)
  end

  def deal_params
    params.require(:lead).permit(:title, :amount, :currency, :close_date, :notes, :pipeline_id, :pipeline_stage_id)
  end
end

