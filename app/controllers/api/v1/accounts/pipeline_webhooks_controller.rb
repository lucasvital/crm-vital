class Api::V1::Accounts::PipelineWebhooksController < Api::V1::Accounts::BaseController
  before_action :set_pipeline
  before_action :set_webhook, only: [:show, :update, :destroy]

  def index
    @webhooks = @pipeline.pipeline_webhooks.includes(:pipeline_stage, :existing_lead_stage).order(created_at: :desc)
    render json: @webhooks.as_json(
      include: {
        pipeline_stage: { only: [:id, :name, :key, :position] },
        existing_lead_stage: { only: [:id, :name, :key, :position] }
      },
      methods: [:full_webhook_url]
    )
  end

  def show
    render json: @webhook.as_json(
      include: {
        pipeline_stage: { only: [:id, :name, :key, :position] },
        existing_lead_stage: { only: [:id, :name, :key, :position] }
      },
      methods: [:full_webhook_url]
    )
  end

  def create
    @webhook = @pipeline.pipeline_webhooks.new(webhook_params)
    @webhook.account = current_account

    if @webhook.save
      render json: @webhook.as_json(
        include: {
          pipeline_stage: { only: [:id, :name, :key, :position] },
          existing_lead_stage: { only: [:id, :name, :key, :position] }
        },
        methods: [:full_webhook_url]
      ), status: :created
    else
      render json: { errors: @webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @webhook.update(webhook_params)
      render json: @webhook.as_json(
        include: {
          pipeline_stage: { only: [:id, :name, :key, :position] },
          existing_lead_stage: { only: [:id, :name, :key, :position] }
        },
        methods: [:full_webhook_url]
      )
    else
      render json: { errors: @webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook.destroy
    head :ok
  end

  private

  def set_pipeline
    @pipeline = current_account.pipelines.find(params[:pipeline_id])
  end

  def set_webhook
    @webhook = @pipeline.pipeline_webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(
      :name,
      :pipeline_stage_id,
      :active,
      :existing_lead_action,
      :existing_lead_stage_id,
      field_mapping: {},
      tag_config: {}
    )
  end
end

