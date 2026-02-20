class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :set_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = current_account.pipelines.includes(:pipeline_stages).order(:id)
    render json: @pipelines.as_json(include: { pipeline_stages: { only: [:id, :name, :key, :position, :is_won] } })
  end

  def show
    render json: @pipeline.as_json(include: { pipeline_stages: { only: [:id, :name, :key, :position, :is_won] } })
  end

  def create
    @pipeline = current_account.pipelines.new(pipeline_params)
    if @pipeline.save
      render json: @pipeline, status: :created
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @pipeline.update(pipeline_params)
      render json: @pipeline
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @pipeline.deals.exists?
      render json: { error: 'Não é possível remover pipeline com negócios vinculados' }, status: :unprocessable_entity
      return
    end

    # Deletar stages sem callbacks para pular a validação de won
    @pipeline.pipeline_stages.delete_all
    @pipeline.destroy

    head :ok
  end

  private

  def set_pipeline
    @pipeline = current_account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name)
  end
end


