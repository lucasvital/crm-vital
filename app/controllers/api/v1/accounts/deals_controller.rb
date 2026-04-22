class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  before_action :set_deal, only: [:update, :destroy]

  def index
    deals = current_account.deals.includes(:contact, :pipeline, :pipeline_stage, :labels, :assignee)
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    deals = deals.where('deals.created_at >= ?', params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
    deals = deals.where('deals.created_at <= ?', params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
    deals = deals.order(created_at: :desc)

    # Customizar JSON para incluir label_list do contato, assignee e conversation_id
    deals_json = deals.map do |deal|
      deal.as_json(
      only: [:id, :title, :amount, :currency, :close_date, :notes, :pipeline_id, :pipeline_stage_id, :assignee_id, :conversation_id, :created_at],
        methods: [:label_list],
      include: {
        pipeline_stage: { only: [:id, :name, :key, :position] }
      }
      ).merge(
        'contact' => {
          'id' => deal.contact.id,
          'name' => deal.contact.name,
          'email' => deal.contact.email,
          'phone_number' => deal.contact.phone_number,
          'label_list' => deal.contact.label_list,
          'custom_attributes' => deal.contact.custom_attributes || {}
        },
        'assignee' => deal.assignee.present? ? {
          'id' => deal.assignee.id,
          'name' => deal.assignee.name,
          'thumbnail' => deal.assignee.avatar_url
        } : nil
      )
    end

    render json: deals_json
  end

  def create
    deal = current_account.deals.new(deal_params)
    if deal.save
      render json: deal, status: :created
    else
      render json: { errors: deal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @deal.update(deal_params)
      render json: @deal
    else
      render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Erro ao atualizar deal #{@deal.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def destroy
    @deal.destroy
    head :ok
  end

  private

  def set_deal
    @deal = current_account.deals.find(params[:id])
  end

  def deal_params
    params.require(:deal).permit(:contact_id, :pipeline_id, :pipeline_stage_id, :title, :amount, :currency, :close_date, :notes, :assignee_id, :conversation_id)
  end
end


