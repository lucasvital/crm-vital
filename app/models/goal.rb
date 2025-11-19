class Goal < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User'

  ALLOWED_SCOPE_TYPES = %w[user team].freeze
  ALLOWED_METRICS = %w[count amount].freeze
  ALLOWED_STATUSES = %w[active archived].freeze

  validates :title, presence: true
  validates :scope_type, presence: true, inclusion: { in: ALLOWED_SCOPE_TYPES }
  validates :metric, presence: true, inclusion: { in: ALLOWED_METRICS }
  validates :status, inclusion: { in: ALLOWED_STATUSES }, allow_nil: true
  validates :start_date, :end_date, presence: true
  validate :validate_target_for_metric
  validate :validate_dates

  scope :active_between, lambda { |from_date, to_date|
    where('(start_date, end_date) OVERLAPS (?, ?)', from_date, to_date)
  }

  def pipelines_filter
    Array(pipeline_ids).presence
  end

  private

  def validate_target_for_metric
    case metric
    when 'count'
      errors.add(:target_number, 'é obrigatório') if target_number.blank?
    when 'amount'
      errors.add(:target_amount, 'é obrigatório') if target_amount.blank?
    end
  end

  def validate_dates
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, 'deve ser maior ou igual a início') if end_date < start_date
  end
end


