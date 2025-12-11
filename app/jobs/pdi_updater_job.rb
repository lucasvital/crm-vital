# frozen_string_literal: true

class PdiUpdaterJob < ApplicationJob
  queue_as :default

  def perform(call_analysis_id)
    call_analysis = CallAnalysis.find_by(id: call_analysis_id)
    return unless call_analysis

    seller_pdi = SellerPdi.find_or_create_by(
      account_id: call_analysis.account_id,
      user_id: call_analysis.user_id
    )

    seller_pdi.update_from_analysis(call_analysis.analysis_result)
    seller_pdi.add_evolution_entry(call_analysis)
  end
end

