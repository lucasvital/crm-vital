class Api::V1::Accounts::DealActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_deal_activity, only: [:update, :destroy]

  def index
    @deal_activities = if params[:pipeline_stage_id].present?
                         Current.account.deal_activities
                                .for_stage(params[:pipeline_stage_id])
                                .ordered
                       else
                         Current.account.deal_activities.ordered
                       end

    render json: @deal_activities
  end

  def create
    @deal_activity = Current.account.deal_activities.new(deal_activity_params)
    @deal_activity.save!
    render json: @deal_activity
  end

  def update
    @deal_activity.update!(deal_activity_params)
    render json: @deal_activity
  end

  def destroy
    @deal_activity.destroy!
    head :ok
  end

  def reorder
    params[:positions].each do |item|
      activity = Current.account.deal_activities.find(item[:id])
      activity.update!(position: item[:position])
    end

    head :ok
  end

  private

  def fetch_deal_activity
    @deal_activity = Current.account.deal_activities.find(params[:id])
  end

  def deal_activity_params
    params.require(:deal_activity).permit(
      :title,
      :description,
      :pipeline_stage_id,
      :move_to_stage_id,
      :position,
      messages: [:content]
    )
  end
end

