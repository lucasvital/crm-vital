class Api::V1::Accounts::PipelineStagesController < Api::V1::Accounts::BaseController
  before_action :set_pipeline
  before_action :set_stage, only: [:update, :destroy]

  def index
    render json: @pipeline.pipeline_stages.order(:position)
  end

  def create
    stage = @pipeline.pipeline_stages.new(stage_params)
    stage.position = (@pipeline.pipeline_stages.maximum(:position) || 0) + 1 if stage.position.blank?
    if stage.save
      render json: stage, status: :created
    else
      render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    PipelineStage.transaction do
      if ActiveModel::Type::Boolean.new.cast(stage_update_params[:is_won])
        @pipeline.pipeline_stages.where(is_won: true).where.not(id: @stage.id)
                 .update_all(is_won: false) # rubocop:disable Rails/SkipsModelValidations
      end

      if @stage.update(stage_update_params)
        render json: @stage
      else
        render json: { errors: @stage.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def destroy
    @stage.destroy
    head :ok
  end

  def reorder
    # expects: params[:order] = [{id: 1, position: 1}, ...]
    order = params[:order] || []
    PipelineStage.transaction do
      order.each do |s|
        @pipeline.pipeline_stages.where(id: s[:id] || s['id']).update_all(position: s[:position] || s['position']) # rubocop:disable Rails/SkipsModelValidations
      end
    end
    head :ok
  end

  private

  def set_pipeline
    @pipeline = current_account.pipelines.find(params[:pipeline_id])
  end

  def set_stage
    @stage = @pipeline.pipeline_stages.find(params[:id])
  end

  def stage_params
    params.require(:stage).permit(:name, :position, :is_won)
  end

  def stage_update_params
    # We intentionally do not allow updating :key to avoid breaking references
    params.require(:stage).permit(:name, :position, :is_won)
  end
end


