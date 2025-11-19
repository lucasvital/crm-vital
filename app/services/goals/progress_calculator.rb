module Goals
  class ProgressCalculator
    def initialize(goal)
      @goal = goal
    end

    def call
      scope_deals = won_deals_in_period
      scope_deals = filter_by_pipelines(scope_deals)
      scope_deals = filter_by_scope(scope_deals)

      total_value = compute_total(scope_deals)
      target_value = target_for_goal
      percentage = if target_value.to_f.positive?
                     ((total_value.to_f / target_value.to_f) * 100.0).round(2)
                   else
                     0.0
                   end

      {
        goal_id: @goal.id,
        metric: @goal.metric,
        total: total_value,
        target: target_value,
        percentage: percentage,
        series: time_series(scope_deals)
      }
    end

    private

    def won_deals_in_period
      Deal.where(account_id: @goal.account_id)
          .where.not(won_at: nil)
          .where('won_at >= ? AND won_at <= ?', @goal.start_date.beginning_of_day, @goal.end_date.end_of_day)
    end

    def filter_by_pipelines(scope)
      return scope if @goal.pipelines_filter.blank?
      scope.where(pipeline_id: @goal.pipelines_filter)
    end

    def filter_by_scope(scope)
      case @goal.scope_type
      when 'user'
        scope.where(won_by_user_id: @goal.scope_id)
      when 'team'
        user_ids = TeamMember.where(team_id: @goal.scope_id).pluck(:user_id)
        user_ids.present? ? scope.where(won_by_user_id: user_ids) : scope.none
      else
        scope
      end
    end

    def compute_total(scope)
      case @goal.metric
      when 'count'
        scope.count
      when 'amount'
        scope.sum(Arel.sql('COALESCE(won_amount_snapshot, amount)'))
      else
        0
      end
    end

    def target_for_goal
      case @goal.metric
      when 'count' then @goal.target_number
      when 'amount' then @goal.target_amount
      end
    end

    def time_series(scope)
      # MVP: evitar erros de SQL específicos por SGBD; retornamos vazio
      []
    end

    def aggregate_sql
      case @goal.metric
      when 'count' then 'COUNT(*)'
      when 'amount' then 'SUM(COALESCE(won_amount_snapshot, amount))'
      else 'COUNT(*)'
      end
    end

    def cast_numeric(val)
      return val.to_i if @goal.metric == 'count'
      val.to_f
    end
  end
end


