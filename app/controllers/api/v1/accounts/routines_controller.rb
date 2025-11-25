class Api::V1::Accounts::RoutinesController < Api::V1::Accounts::BaseController
  before_action :set_routine, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    routines = current_account.routines
    routines = apply_filters(routines)

    render json: { payload: serialize_collection(routines) }
  end

  def show
    render json: { payload: serialize_resource(@routine) }
  end

  def create
    routine = current_account.routines.new(routine_params)

    if routine.save
      render json: { payload: serialize_resource(routine) }, status: :created
    else
      render json: { errors: routine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @routine.update(routine_params)
      render json: { payload: serialize_resource(@routine) }
    else
      render json: { errors: @routine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @routine.destroy!
    head :no_content
  end

  private

  def set_routine
    @routine = current_account.routines.find(params[:id])
  end

  def routine_params
    params.require(:routine).permit(:title, :description, :weekday, :time_of_day, :active)
  end

  def apply_filters(scope)
    weekday_param = params[:weekday]
    return scope.order(:weekday, :time_of_day) if weekday_param.blank?

    weekday_value = parse_weekday_param(weekday_param)
    return scope.none unless weekday_value

    scope.for_weekday(weekday_value).order(:time_of_day)
  end

  def parse_weekday_param(value)
    return Routine.weekdays[account_today_weekday] if value == 'today'

    if Routine.weekdays.key?(value)
      return Routine.weekdays[value]
    end

    integer_value = Integer(value, exception: false)
    return integer_value if integer_value && Routine.weekdays.value?(integer_value)

    nil
  end

  def account_today_weekday
    Time.zone.today.strftime('%A').downcase
  end

  def serialize_collection(routines)
    routines.map { |routine| serialize_resource(routine) }
  end

  def serialize_resource(routine)
    {
      id: routine.id,
      title: routine.title,
      description: routine.description,
      weekday: routine.weekday,
      time_of_day: routine.time_of_day.strftime('%H:%M'),
      active: routine.active
    }
  end
end


