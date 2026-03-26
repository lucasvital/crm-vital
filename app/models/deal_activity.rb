# == Schema Information
#
# Table name: deal_activities
#
#  id                :bigint           not null, primary key
#  description       :text
#  messages          :jsonb
#  position          :integer          default(0)
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  pipeline_stage_id :bigint           not null
#
# Indexes
#
#  index_deal_activities_on_account_id                        (account_id)
#  index_deal_activities_on_account_id_and_pipeline_stage_id  (account_id,pipeline_stage_id)
#  index_deal_activities_on_messages                          (messages) USING gin
#  index_deal_activities_on_pipeline_stage_id                 (pipeline_stage_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (pipeline_stage_id => pipeline_stages.id)
#

class DealActivity < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline_stage
  belongs_to :move_to_stage, class_name: 'PipelineStage', optional: true

  validates :account, :pipeline_stage, :title, presence: true
  validates :messages, presence: true
  validate :validate_messages_format

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :for_stage, ->(stage_id) { where(pipeline_stage_id: stage_id) }

  private

  def validate_messages_format
    return if messages.blank?

    unless messages.is_a?(Array)
      errors.add(:messages, 'deve ser um array')
      return
    end

    messages.each_with_index do |msg, index|
      unless msg.is_a?(Hash)
        errors.add(:messages, "item #{index + 1} deve ser um objeto")
        next
      end

      if msg['content'].blank?
        errors.add(:messages, "item #{index + 1} deve ter um conteúdo")
      end
    end
  end
end

