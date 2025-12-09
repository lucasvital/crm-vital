class Api::V1::Accounts::Integrations::HooksController < Api::V1::Accounts::BaseController
  before_action :fetch_hook, except: [:create, :process_event_with_env]
  before_action :check_authorization

  def create
    @hook = Current.account.hooks.create!(permitted_params)
  end

  def update
    @hook.update!(permitted_params.slice(:status, :settings))
  end

  def process_event
    response = @hook.process_event(params[:event])

    # for cases like an invalid event, or when conversation does not have enough messages
    # for a label suggestion, the response is nil
    if response.nil?
      render json: { message: nil }
    elsif response[:error]
      render json: { error: response[:error] }, status: :unprocessable_entity
    else
      render json: { message: response[:message] }
    end
  end

  def process_event_with_env
    # Usa ENV quando disponível, sem precisar de hook cadastrado
    return render json: { error: 'OpenAI API key not configured' }, status: :unprocessable_entity if ENV['OPENAI_API_KEY'].blank?

    # Cria um mock hook temporário para processar o evento
    mock_hook = OpenStruct.new(
      account: Current.account,
      settings: { 'api_key' => ENV['OPENAI_API_KEY'] },
      enabled?: true,
      app_id: 'openai'
    )

    # Processa apenas eventos permitidos que usam ENV (conversation_analysis)
    event_name = params[:event][:name] || params[:event]['name']
    return render json: { error: 'Event not allowed' }, status: :unprocessable_entity unless event_name == 'conversation_analysis'

    response = Integrations::Openai::ProcessorService.new(hook: mock_hook, event: params[:event]).perform

    if response.nil?
      render json: { message: nil }
    elsif response[:error]
      render json: { error: response[:error] }, status: :unprocessable_entity
    else
      render json: { message: response[:message] }
    end
  end

  def destroy
    @hook.destroy!
    head :ok
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find(params[:id])
  end

  def check_authorization
    authorize(:hook)
  end

  def permitted_params
    params.require(:hook).permit(:app_id, :inbox_id, :status, settings: {})
  end
end
