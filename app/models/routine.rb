# == Schema Information
#
# Table name: routines
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  time_of_day :time             not null
#  title       :string           not null
#  weekday     :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_routines_on_account_id                              (account_id)
#  index_routines_on_account_id_and_weekday_and_time_of_day  (account_id,weekday,time_of_day)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Routine < ApplicationRecord
  belongs_to :account
  has_many :routine_completions, dependent: :destroy

  enum weekday: {
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5
  }

  validates :account_id, presence: true
  validates :title, presence: true
  validates :weekday, presence: true, inclusion: { in: weekdays.keys }
  validates :time_of_day, presence: true

  scope :for_weekday, ->(weekday_value) { where(weekday: weekday_value) }
  scope :active, -> { where(active: true) }
end
