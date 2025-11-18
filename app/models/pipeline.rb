# == Schema Information
#
# Table name: pipelines
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_pipelines_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :pipeline_stages, -> { order(position: :asc) }, dependent: :destroy
  has_many :deals, dependent: :destroy

  validates :name, presence: true
end


