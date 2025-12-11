# == Schema Information
#
# Table name: deals
#
#  id                  :bigint           not null, primary key
#  amount              :decimal(15, 2)   default(0.0)
#  close_date          :date
#  currency            :string(8)        default("BRL")
#  notes               :text
#  title               :string           not null
#  won_amount_snapshot :decimal(12, 2)
#  won_at              :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  contact_id          :bigint           not null
#  pipeline_id         :bigint           not null
#  pipeline_stage_id   :bigint           not null
#  won_by_user_id      :bigint
#
# Indexes
#
#  index_deals_on_account_id                  (account_id)
#  index_deals_on_account_id_and_contact_id   (account_id,contact_id)
#  index_deals_on_account_id_and_pipeline_id  (account_id,pipeline_id)
#  index_deals_on_contact_id                  (contact_id)
#  index_deals_on_pipeline_id                 (pipeline_id)
#  index_deals_on_pipeline_stage_id           (pipeline_stage_id)
#  index_deals_on_won_at                      (won_at)
#  index_deals_on_won_by_user_id              (won_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (pipeline_id => pipelines.id)
#  fk_rails_...  (pipeline_stage_id => pipeline_stages.id)
#  fk_rails_...  (won_by_user_id => users.id)
#
class Deal < ApplicationRecord
  include Labelable

  belongs_to :account
  belongs_to :contact
  belongs_to :pipeline
  belongs_to :pipeline_stage
  belongs_to :won_by_user, class_name: 'User', optional: true

  validates :title, presence: true
  validates :currency, presence: true

  after_update_commit :sync_won_state_if_stage_changed

  private

  def sync_won_state_if_stage_changed
    return unless saved_change_to_pipeline_stage_id?

    new_stage = pipeline_stage
    was_stage_id, _ = saved_change_to_pipeline_stage_id
    previous_stage = was_stage_id.present? ? PipelineStage.find_by(id: was_stage_id) : nil

    if new_stage&.is_won?
      # mark won if not already
      updates = {}
      updates[:won_at] = Time.current if won_at.blank?
      if won_by_user_id.blank?
        updates[:won_by_user_id] = detect_latest_conversation_assignee_id
      end
      updates[:won_amount_snapshot] = amount if won_amount_snapshot.blank? && amount.present?
      update_columns(updates) if updates.any?
    elsif previous_stage&.is_won? && !new_stage&.is_won?
      # undo won state
      update_columns(
        won_at: nil,
        won_by_user_id: nil,
        won_amount_snapshot: nil
      )
    end
  end

  def detect_latest_conversation_assignee_id
    convo = Conversation.where(account_id: account_id, contact_id: contact_id)
                        .order(Arel.sql('COALESCE(last_activity_at, updated_at) DESC'))
                        .limit(1).first
    convo&.assignee_id
  end
end


