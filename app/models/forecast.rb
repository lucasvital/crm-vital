# == Schema Information
#
# Table name: forecasts
#
#  id               :bigint           not null, primary key
#  confidence_level :integer
#  key_insights     :jsonb            not null
#  metadata         :jsonb            not null
#  monthly_forecast :jsonb            not null
#  opportunities    :jsonb            not null
#  recommendations  :jsonb            not null
#  risks            :jsonb            not null
#  summary          :text
#  weekly_forecast  :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_forecasts_on_account_id              (account_id)
#  index_forecasts_on_account_id_and_user_id  (account_id,user_id)
#  index_forecasts_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Forecast < ApplicationRecord
  belongs_to :account
  belongs_to :user
end

