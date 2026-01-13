# == Schema Information
#
# Table name: pipeline_webhooks
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  field_mapping     :jsonb            not null
#  name              :string           not null
#  tag_config        :jsonb            not null
#  token             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  pipeline_id       :bigint           not null
#  pipeline_stage_id :bigint           not null
#
# Indexes
#
#  index_pipeline_webhooks_on_account_id                  (account_id)
#  index_pipeline_webhooks_on_account_id_and_pipeline_id  (account_id,pipeline_id)
#  index_pipeline_webhooks_on_pipeline_id                 (pipeline_id)
#  index_pipeline_webhooks_on_pipeline_id_and_name        (pipeline_id,name)
#  index_pipeline_webhooks_on_pipeline_stage_id           (pipeline_stage_id)
#  index_pipeline_webhooks_on_token                       (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (pipeline_id => pipelines.id)
#  fk_rails_...  (pipeline_stage_id => pipeline_stages.id)
#
class PipelineWebhook < ApplicationRecord
  belongs_to :pipeline
  belongs_to :account
  belongs_to :pipeline_stage

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  validates :pipeline_stage_id, presence: true
  validate :pipeline_stage_belongs_to_pipeline

  before_validation :generate_token, on: :create
  before_validation :ensure_json_defaults

  scope :active, -> { where(active: true) }

  def webhook_url
    Rails.application.routes.url_helpers.webhooks_pipeline_url(token)
  end

  def full_webhook_url
    # Usar o host configurado
    host = ENV['FRONTEND_URL'] || Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    protocol = host.include?('localhost') ? 'http' : 'https'
    "#{protocol}://#{host}/webhooks/pipelines/#{token}"
  end

  private

  def generate_token
    return if token.present?

    loop do
      self.token = SecureRandom.urlsafe_base64(32)
      break unless PipelineWebhook.exists?(token: token)
    end
  end

  def ensure_json_defaults
    self.field_mapping ||= {}
    self.tag_config ||= {}
  end

  def pipeline_stage_belongs_to_pipeline
    return if pipeline_stage_id.blank? || pipeline_id.blank?

    unless pipeline_stage&.pipeline_id == pipeline_id
      errors.add(:pipeline_stage_id, 'deve pertencer ao pipeline selecionado')
    end
  end
end

