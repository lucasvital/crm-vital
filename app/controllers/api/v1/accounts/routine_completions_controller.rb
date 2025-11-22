class Api::V1::Accounts::RoutineCompletionsController < Api::V1::Accounts::BaseController
  def create
    completion = current_user.routine_completions.find_or_initialize_by(
      routine_id: params[:routine_id],
      completed_date: Date.current
    )

    if completion.persisted?
      render json: { message: 'Already completed' }, status: :ok
    elsif completion.save
      render json: { message: 'Routine marked as completed' }, status: :created
    else
      render json: { errors: completion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    completion = current_user.routine_completions.find_by(
      routine_id: params[:routine_id],
      completed_date: Date.current
    )

    if completion&.destroy
      render json: { message: 'Completion removed' }, status: :ok
    else
      render json: { errors: ['Completion not found'] }, status: :not_found
    end
  end
end
