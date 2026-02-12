class SendScheduledMessageJob < ApplicationJob
  queue_as :high

  def perform(scheduled_message_id)
    scheduled_message = ScheduledMessage.find(scheduled_message_id)
    return unless scheduled_message.pending?

    conversation = scheduled_message.conversation
    user = scheduled_message.sender

    message_params = {
      content: scheduled_message.content,
      message_type: scheduled_message.message_type,
      content_type: scheduled_message.content_type,
      private: scheduled_message.private,
      content_attributes: scheduled_message.content_attributes,
      additional_attributes: scheduled_message.additional_attributes
    }

    Messages::MessageBuilder.new(user, conversation, message_params).perform
    
    scheduled_message.update!(status: :sent)
  rescue StandardError => e
    scheduled_message.update!(status: :failed, error_message: e.message)
    Rails.logger.error "Failed to send scheduled message #{scheduled_message_id}: #{e.message}"
    ChatwootExceptionTracker.new(e, account: scheduled_message.account).capture_exception
  end
end
