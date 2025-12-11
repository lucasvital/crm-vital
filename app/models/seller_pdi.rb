# == Schema Information
#
# Table name: seller_pdis
#
#  id                  :bigint           not null, primary key
#  competencies        :jsonb            not null
#  evolution_history   :jsonb            not null
#  improvement_areas   :jsonb            not null
#  strengths           :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  user_id(Vendedor)   :bigint           not null
#
# Indexes
#
#  index_seller_pdis_on_account_id              (account_id)
#  index_seller_pdis_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_seller_pdis_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class SellerPdi < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :account_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :account_id }

  # Adiciona novo ponto ao histórico de evolução
  def add_evolution_entry(call_analysis)
    new_entry = {
      date: Time.current.to_date.to_s,
      call_analysis_id: call_analysis.id,
      score: call_analysis.seller_score,
      key_improvements: call_analysis.pdi_points.first(3)
    }

    self.evolution_history = (evolution_history || []) << new_entry
    save
  end

  # Atualiza competências baseado em nova análise
  def update_from_analysis(analysis_result)
    update_competencies(analysis_result['competencies']) if analysis_result['competencies']
    update_improvement_areas(analysis_result['improvement_areas']) if analysis_result['improvement_areas']
    update_strengths(analysis_result['strengths']) if analysis_result['strengths']
  end

  private

  def update_competencies(new_competencies)
    current = competencies || {}
    new_competencies.each do |competency, score|
      current[competency] = {
        current_score: score,
        last_updated: Time.current.to_s,
        history: (current.dig(competency, 'history') || []) << { score: score, date: Time.current.to_date.to_s }
      }
    end
    self.competencies = current
  end

  def update_improvement_areas(new_areas)
    self.improvement_areas = new_areas
  end

  def update_strengths(new_strengths)
    self.strengths = new_strengths
  end
end

