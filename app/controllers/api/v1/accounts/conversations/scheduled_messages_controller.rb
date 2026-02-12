class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_scheduled_message, only: [:show, :update, :destroy]

  def index
    @scheduled_messages = @conversation.scheduled_messages
                                       .includes(:sender)
                                       .order(scheduled_at: :asc)
    render json: @scheduled_messages.as_json(
      include: {
        sender: { only: [:id, :name, :email] }
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to list scheduled messages: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    render json: @scheduled_message.as_json(
      include: {
        sender: { only: [:id, :name, :email] }
      }
    )
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.build(scheduled_message_params)
    @scheduled_message.account = Current.account
    @scheduled_message.inbox = @conversation.inbox
    @scheduled_message.sender = Current.user

    if @scheduled_message.save
      render json: @scheduled_message.as_json(
        include: {
          sender: { only: [:id, :name, :email] }
        }
      ), status: :created
    else
      render json: { errors: @scheduled_message.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create scheduled message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def update
    # Permite apenas cancelar (mudar status para cancelled)
    if params[:status] == 'cancelled'
      @scheduled_message.update!(status: :cancelled)
      render json: @scheduled_message.as_json(
        include: {
          sender: { only: [:id, :name, :email] }
        }
      )
    else
      render json: { error: 'Only cancellation is allowed' }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Failed to update scheduled message: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  def destroy
    @scheduled_message.destroy!
    head :no_content
  end

  private

  def set_scheduled_message
    @scheduled_message = @conversation.scheduled_messages.find(params[:id])
  end

  def scheduled_message_params
    params.require(:scheduled_message).permit(
      :content,
      :scheduled_at,
      :message_type,
      :content_type,
      :private,
      content_attributes: {},
      additional_attributes: {}
    )
  end
end
