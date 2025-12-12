class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  before_action :set_deal, only: [:update, :destroy]

  def index
    deals = current_account.deals.includes(:contact, :pipeline, :pipeline_stage, :labels)
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    
    # Customizar JSON para incluir label_list do contato
    deals_json = deals.map do |deal|
      deal.as_json(
      only: [:id, :title, :amount, :currency, :close_date, :notes, :pipeline_id],
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
          'label_list' => deal.contact.label_list
        }
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
    params.require(:deal).permit(:contact_id, :pipeline_id, :pipeline_stage_id, :title, :amount, :currency, :close_date, :notes)
  end
end


