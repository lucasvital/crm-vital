# == Schema Information
#
# Table name: call_analyses
#
#  id                                    :bigint           not null, primary key
#  analysis_result                       :jsonb            not null
#  competitors_mentioned                 :jsonb
#  next_steps                            :jsonb
#  objections                            :jsonb
#  pdi_points                            :jsonb
#  processing_error                      :text
#  processing_status                     :string           default("completed"), not null
#  seller_score                          :decimal(5, 2)
#  summary                               :text
#  transcript                            :text             not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  account_id                            :bigint           not null
#  contact_id                            :bigint           not null
#  created_by_id(Quem inseriu a análise) :bigint           not null
#  deal_id                               :bigint
#  user_id(Vendedor analisado)           :bigint           not null
#
# Indexes
#
#  index_call_analyses_on_account_id                 (account_id)
#  index_call_analyses_on_account_id_and_contact_id  (account_id,contact_id)
#  index_call_analyses_on_account_id_and_user_id     (account_id,user_id)
#  index_call_analyses_on_contact_id                 (contact_id)
#  index_call_analyses_on_created_at                 (created_at)
#  index_call_analyses_on_created_by_id              (created_by_id)
#  index_call_analyses_on_deal_id                    (deal_id)
#  index_call_analyses_on_processing_status          (processing_status)
#  index_call_analyses_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (deal_id => deals.id)
#  fk_rails_...  (user_id => users.id)
#
class CallAnalysis < ApplicationRecord
  # Status do processamento da análise
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :user, inverse_of: :analyzed_calls
  belongs_to :created_by, class_name: 'User', inverse_of: :created_call_analyses
  belongs_to :deal, optional: true

  # Permite transcrições de até 500k caracteres (GPT-4o suporta ~128k tokens)
  validates :transcript, presence: true, length: { maximum: 500_000 }
  validates :account_id, presence: true
  validates :contact_id, presence: true
  validates :user_id, presence: true
  validates :created_by_id, presence: true

  after_create :update_seller_pdi, if: :completed?

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_contact, ->(contact_id) { where(contact_id: contact_id) }
  scope :for_deal, ->(deal_id) { where(deal_id: deal_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(processing_status: 'pending') }
  scope :processing, -> { where(processing_status: 'processing') }
  scope :completed, -> { where(processing_status: 'completed') }
  scope :failed, -> { where(processing_status: 'failed') }

  def pending?
    processing_status == 'pending'
  end

  def processing?
    processing_status == 'processing'
  end

  def completed?
    processing_status == 'completed'
  end

  def failed?
    processing_status == 'failed'
  end

  def in_progress?
    pending? || processing?
  end

  private

  def update_seller_pdi
    PdiUpdaterJob.perform_later(id)
  end
end

