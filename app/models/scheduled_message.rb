class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :sender, polymorphic: true

  enum status: { pending: 0, sent: 1, cancelled: 2, failed: 3 }
  enum content_type: Message.content_types
  enum message_type: Message.message_types

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
