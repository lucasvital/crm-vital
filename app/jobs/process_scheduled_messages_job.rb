class ProcessScheduledMessagesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledMessage.due.find_each(batch_size: 50) do |scheduled_message|
      SendScheduledMessageJob.perform_later(scheduled_message.id)
    end
  end
end
