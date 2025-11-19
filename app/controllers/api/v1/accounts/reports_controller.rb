class Api::V1::Accounts::ReportsController < Api::V1::Accounts::BaseController
  def deals_won
    from = parse_date(params[:from]) || 30.days.ago.to_date
    to = parse_date(params[:to]) || Date.current
    metric = params[:metric].presence_in(%w[count amount]) || 'count'
    group_by = params[:group_by].presence_in(%w[user team]) || 'user'
    pipeline_ids = Array(params[:pipeline_ids]).reject(&:blank?)

    scope = Deal.where(account_id: current_account.id).where.not(won_at: nil)
                .where('won_at >= ? AND won_at <= ?', from.beginning_of_day, to.end_of_day)
    scope = scope.where(pipeline_id: pipeline_ids) if pipeline_ids.present?

    data =
      case group_by
      when 'user'
        aggregate_by_user(scope, metric)
      when 'team'
        aggregate_by_team(scope, metric)
      end

    render json: { from: from, to: to, metric: metric, group_by: group_by, data: data }
  end

  private

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str) rescue nil
  end

  def aggregate_by_user(scope, metric)
    rows = case metric
           when 'count' then scope.group(:won_by_user_id).count
           when 'amount' then scope.group(:won_by_user_id).sum(Arel.sql('COALESCE(won_amount_snapshot, amount)'))
           end
    users = User.where(id: rows.keys).pluck(:id, :name).to_h
    rows.map { |user_id, value| { user_id: user_id, user_name: users[user_id], value: numeric(metric, value) } }
         .sort_by { |h| -h[:value] }
  end

  def aggregate_by_team(scope, metric)
    # map won_by_user_id -> teams
    user_to_teams = TeamMember.where(user_id: scope.select(:won_by_user_id).distinct.pluck(:won_by_user_id))
                              .group_by(&:user_id)
                              .transform_values { |recs| recs.map(&:team_id) }
    # accumulate values into team buckets
    buckets = Hash.new(0)
    scope.select(:won_by_user_id, aggregate_sql(metric)).group(:won_by_user_id).each do |row|
      value = row.try(:sum) || row.try(:count) || 0
      value = numeric(metric, value)
      Array(user_to_teams[row.won_by_user_id]).each { |team_id| buckets[team_id] += value }
    end
    teams = Team.where(id: buckets.keys).pluck(:id, :name).to_h
    buckets.map { |team_id, value| { team_id: team_id, team_name: teams[team_id], value: value } }
           .sort_by { |h| -h[:value] }
  end

  def aggregate_sql(metric)
    case metric
    when 'count' then 'COUNT(*) as count'
    when 'amount' then 'SUM(COALESCE(won_amount_snapshot, amount)) as sum'
    end
  end

  def numeric(metric, val)
    return val.to_i if metric == 'count'
    val.to_f
  end
end



