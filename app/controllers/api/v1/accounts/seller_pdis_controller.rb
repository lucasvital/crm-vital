# frozen_string_literal: true

class Api::V1::Accounts::SellerPdisController < Api::V1::Accounts::BaseController
  before_action :set_user

  def show
    authorize_access!

    @seller_pdi = SellerPdi.find_or_initialize_by(
      account_id: current_account.id,
      user_id: @user.id
    )

    # Se não existe PDI ainda, retornar estrutura vazia
    if @seller_pdi.new_record?
      render json: {
        id: nil,
        user: @user.as_json(only: [:id, :name, :email]),
        competencies: {},
        improvement_areas: [],
        strengths: [],
        evolution_history: [],
        analyses_count: 0
      }
      return
    end

    analyses_count = CallAnalysis.where(account_id: current_account.id, user_id: @user.id).count

    render json: @seller_pdi.as_json(
      except: [:account_id],
      include: {
        user: { only: [:id, :name, :email] }
      }
    ).merge(analyses_count: analyses_count)
  end

  private

  def set_user
    @user = if params[:user_id]
              current_account.users.find(params[:user_id])
            else
              Current.user
            end
  end

  def authorize_access!
    # Agents só podem acessar seu próprio PDI
    return if Current.account_user.administrator?
    return if @user.id == Current.user.id

    render json: { error: 'Acesso não autorizado' }, status: :forbidden
  end
end

