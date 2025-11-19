class Api::V1::Accounts::GoalsController < Api::V1::Accounts::BaseController
  before_action :set_goal, only: [:show, :update, :destroy, :progress]

  def index
    goals = current_account.goals.order(created_at: :desc)
    render json: goals.as_json
  end

  def show
    render json: @goal.as_json
  end

  def create
    @goal = current_account.goals.new(goal_params.merge(created_by_id: Current.user.id))
    if @goal.save
      render json: @goal.as_json
    else
      render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @goal.update(goal_params)
      render json: @goal.as_json
    else
      render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    head :no_content
  end

  def progress
    result = Goals::ProgressCalculator.new(@goal).call
    render json: result
  end

  private

  def set_goal
    @goal = current_account.goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(
      :title,
      :notes,
      :scope_type,
      :scope_id,
      :metric,
      :target_number,
      :target_amount,
      :start_date,
      :end_date,
      :status,
      pipeline_ids: []
    )
  end
end


