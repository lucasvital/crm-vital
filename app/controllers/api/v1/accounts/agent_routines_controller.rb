class Api::V1::Accounts::AgentRoutinesController < Api::V1::Accounts::BaseController
  def index
    routines = current_account.routines.active

    weekday_filter = parsed_weekday_param
    routines = routines.where(weekday: weekday_filter) if weekday_filter

    routines = routines.order(:time_of_day)

    render json: { payload: serialize_collection(routines) }
  end

  private

  def parsed_weekday_param
    weekday_param = params[:weekday]

    # Se for 'today' ou vazio, usa o dia atual
    return account_today_weekday if weekday_param == 'today' || weekday_param.blank?

    # Se for uma string válida do enum (monday, tuesday, etc)
    return weekday_param if Routine.weekdays.key?(weekday_param)

    # Se for um número, retorna se for válido
    integer_value = Integer(weekday_param, exception: false)
    return Routine.weekdays.key(integer_value) if integer_value && Routine.weekdays.value?(integer_value)

    # Fallback: dia atual
    account_today_weekday
  end

  def account_today_weekday
    Time.zone.today.strftime('%A').downcase
  end

  def serialize_collection(routines)
    routines.map { |routine| serialize_resource(routine) }
  end

  def serialize_resource(routine)
    completed = current_user.routine_completions.exists?(
      routine_id: routine.id,
      completed_date: Date.current
    )

    {
      id: routine.id,
      title: routine.title,
      description: routine.description,
      weekday: routine.weekday,
      time_of_day: routine.time_of_day.strftime('%H:%M'),
      active: routine.active,
      completed: completed
    }
  end
end
