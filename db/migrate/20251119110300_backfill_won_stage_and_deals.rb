class BackfillWonStageAndDeals < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    say_with_time 'Marking won stages per pipeline' do
      Pipeline.find_each do |pipeline|
        stages = pipeline.pipeline_stages.order(:position)
        won_stage = stages.find { |s| truthy_won_name?(s) } || stages.find(&:is_won)
        if won_stage
          won_stage.update_columns(is_won: true)
          # ensure uniqueness by clearing others
          stages.where.not(id: won_stage.id).update_all(is_won: false)
        else
          max_pos = stages.maximum(:position) || -1
          PipelineStage.create!(
            pipeline_id: pipeline.id,
            name: 'Ganho',
            position: max_pos + 1,
            is_won: true
          )
        end
      end
    end

    say_with_time 'Backfilling won_* fields in deals' do
      Deal.joins(:pipeline_stage).where(pipeline_stages: { is_won: true }).find_each do |deal|
        next if deal.won_at.present?

        won_at = deal.updated_at || deal.created_at
        won_by_user_id = latest_conversation_assignee_id(deal.account_id, deal.contact_id)
        won_amount_snapshot = deal.amount
        deal.update_columns(
          won_at: won_at,
          won_by_user_id: won_by_user_id,
          won_amount_snapshot: won_amount_snapshot
        )
      end
    end
  end

  def down
    # no-op: we don't revert flags or snapshots
  end

  private

  def truthy_won_name?(stage)
    name = (stage.name || '').downcase
    key = (stage.key || '').downcase
    name.include?('ganho') || name.include?('won') || key.include?('ganho') || key.include?('won')
  end

  def latest_conversation_assignee_id(account_id, contact_id)
    convo = Conversation.where(account_id: account_id, contact_id: contact_id)
                        .order(Arel.sql('COALESCE(last_activity_at, updated_at) DESC')).limit(1).first
    convo&.assignee_id
  end
end



