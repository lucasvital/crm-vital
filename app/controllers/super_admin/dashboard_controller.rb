class SuperAdmin::DashboardController < SuperAdmin::ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
    @data = Conversation.unscoped.group_by_day(:created_at, range: 30.days.ago..2.seconds.ago).count.to_a
    @accounts_count = number_with_delimiter(Account.count)
    @users_count = number_with_delimiter(User.count)
    @inboxes_count = number_with_delimiter(Inbox.count)
    @conversations_count = number_with_delimiter(Conversation.count)

    # Company size distribution from Account.custom_attributes->>'company_size'
    size_counts = Account
                    .where("custom_attributes ? 'company_size'")
                    .group("custom_attributes->>'company_size'")
                    .count
    @company_size_data = size_counts.map { |k, v| [k, v] }

    # Industry distribution from Account.custom_attributes->>'industry'
    industry_counts = Account
                        .where("custom_attributes ? 'industry'")
                        .group("custom_attributes->>'industry'")
                        .count
    @industry_data = industry_counts.map { |k, v| [k, v] }
  end
end
