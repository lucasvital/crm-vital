class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :sender, polymorphic: true

  enum status: { pending: 0, sent: 1, cancelled: 2, failed: 3 }
  
  # Copiar os enums do Message model
  enum content_type: {
    text: 0,
    input_text: 1,
    input_textarea: 2,
    input_email: 3,
    input_select: 4,
    cards: 5,
    form: 6,
    article: 7,
    incoming_email: 8,
    input_csat: 9,
    integrations: 10,
    sticker: 11,
    voice_call: 12
  }
  
  enum message_type: { incoming: 0, outgoing: 1, activity: 2, template: 3 }

  validates :content, presence: true
  validates :scheduled_at, presence: true
  validate :scheduled_at_must_be_future, on: :create

  scope :due, -> { pending.where('scheduled_at <= ?', Time.current) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }

  private

  def scheduled_at_must_be_future
    return unless scheduled_at.present? && scheduled_at <= Time.current

    errors.add(:scheduled_at, 'must be in the future')
  end
end
