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
      render json: {
        columns: result[:columns],
        preview_rows: result[:preview_rows],
        total_rows: result[:total_rows]
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def import_process
    result = Leads::ImportService.new(current_account).process_import(
      file: params[:file],
      column_mapping: params[:column_mapping]&.to_unsafe_h || {},
      pipeline_id: params[:pipeline_id],
      pipeline_stage_id: params[:pipeline_stage_id]
    )

    if result[:success]
      render json: {
        success_count: result[:success_count],
        error_count: result[:error_count],
        errors: result[:errors]
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.require(:lead).permit(:name, :email, :phone_number, :company_name, :city, :country)
  end

  def deal_params
    params.require(:lead).permit(:title, :amount, :currency, :close_date, :notes, :pipeline_id, :pipeline_stage_id)
  end
end

