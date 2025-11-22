# == Schema Information
#
# Table name: routine_completions
#
#  id             :bigint           not null, primary key
#  completed_date :date             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  routine_id     :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_routine_completions_on_routine_id  (routine_id)
#  index_routine_completions_on_user_id     (user_id)
#  index_routine_completions_unique         (user_id,routine_id,completed_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (routine_id => routines.id)
#  fk_rails_...  (user_id => users.id)
#
class RoutineCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :routine

  validates :user_id, presence: true
  validates :routine_id, presence: true
  validates :completed_date, presence: true
  validates :user_id, uniqueness: { scope: [:routine_id, :completed_date] }

  scope :for_user, ->(user) { where(user: user) }
  scope :for_date, ->(date) { where(completed_date: date) }
  scope :today, -> { for_date(Time.zone.today) }
end
