class LeadScoringJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    Conversations::LeadScoringService.new(conversation).perform
  end
end