# == Schema Information
#
# Table name: deals
#
#  id                :bigint           not null, primary key
#  amount            :decimal(15, 2)   default(0.0)
#  close_date        :date
#  currency          :string(8)        default("BRL")
#  notes             :text
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  contact_id        :bigint           not null
#  pipeline_id       :bigint           not null
#  pipeline_stage_id :bigint           not null
#
# Indexes
#
#  index_deals_on_account_id                  (account_id)
#  index_deals_on_account_id_and_contact_id   (account_id,contact_id)
#  index_deals_on_account_id_and_pipeline_id  (account_id,pipeline_id)
#  index_deals_on_contact_id                  (contact_id)
#  index_deals_on_pipeline_id                 (pipeline_id)
#  index_deals_on_pipeline_stage_id           (pipeline_stage_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (pipeline_id => pipelines.id)
#  fk_rails_...  (pipeline_stage_id => pipeline_stages.id)
#
class Deal < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :pipeline
  belongs_to :pipeline_stage

  validates :title, presence: true
  validates :currency, presence: true
end


