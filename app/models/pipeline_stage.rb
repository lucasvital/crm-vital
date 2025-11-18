# == Schema Information
#
# Table name: pipeline_stages
#
#  id          :bigint           not null, primary key
#  key         :string           not null
#  name        :string           not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  pipeline_id :bigint           not null
#
# Indexes
#
#  index_pipeline_stages_on_pipeline_id          (pipeline_id)
#  index_pipeline_stages_on_pipeline_id_and_key  (pipeline_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (pipeline_id => pipelines.id)
#
class PipelineStage < ApplicationRecord
  belongs_to :pipeline
  has_many :deals, dependent: :nullify

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { scope: :pipeline_id }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_validation :ensure_key, on: :create

  private

  def ensure_key
    return if key.present?
    base = (name.presence || 'stage').to_s.parameterize(separator: '_')
    self.key = unique_key_for(base)
  end

  def unique_key_for(base)
    candidate = base
    suffix = 2
    while PipelineStage.where(pipeline_id: pipeline_id, key: candidate).exists?
      candidate = "#{base}_#{suffix}"
      suffix += 1
    end
    candidate
  end
end


