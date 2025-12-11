# frozen_string_literal: true

class Api::V1::Accounts::CallAnalysesController < Api::V1::Accounts::BaseController
  before_action :set_call_analysis, only: [:show, :update, :destroy]

  # Limite para processamento síncrono (20k chars = ~5k tokens)
  SYNC_PROCESSING_LIMIT = 20_000

  def index
    @call_analyses = current_account.call_analyses
                                    .includes(:contact, :user, :created_by, :deal)
                                    .order(created_at: :desc)

    @call_analyses = @call_analyses.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    @call_analyses = @call_analyses.where(user_id: params[:user_id]) if params[:user_id].present?
    @call_analyses = @call_analyses.where(deal_id: params[:deal_id]) if params[:deal_id].present?

    # Permissões: agents veem apenas suas próprias análises
    @call_analyses = @call_analyses.where(user_id: Current.user.id) unless Current.account_user.administrator?

    render json: @call_analyses.as_json(
      only: [:id, :summary, :seller_score, :processing_status, :created_at, :updated_at],
      include: {
        contact: { only: [:id, :name, :email] },
        user: { only: [:id, :name, :email] },
        created_by: { only: [:id, :name] },
        deal: { only: [:id, :title] }
      }
    )
  end

  def show
    authorize_access!

    render json: @call_analysis.as_json(
      except: [:account_id],
      methods: [:in_progress?],
      include: {
        contact: { only: [:id, :name, :email, :phone_number] },
        user: { only: [:id, :name, :email] },
        created_by: { only: [:id, :name] },
        deal: { only: [:id, :title, :amount, :pipeline_stage_id] }
      }
    )
  end

  def create
    transcript = call_analysis_params[:transcript]
    contact = current_account.contacts.find(call_analysis_params[:contact_id])

    # Determinar o user_id (vendedor analisado)
    analyzed_user_id = if Current.account_user.administrator? && call_analysis_params[:user_id].present?
                         call_analysis_params[:user_id]
                       else
                         Current.user.id
                       end

    analyzed_user = current_account.users.find(analyzed_user_id)

    # Decidir se processa síncrono ou assíncrono baseado no tamanho
    process_async = transcript.length > SYNC_PROCESSING_LIMIT

    if process_async
      # Criar registro pendente e processar em background
      @call_analysis = current_account.call_analyses.new(
        transcript: transcript,
        contact: contact,
        user: analyzed_user,
        created_by: Current.user,
        deal_id: call_analysis_params[:deal_id],
        analysis_result: {},
        processing_status: 'pending'
      )

      if @call_analysis.save
        CallAnalysisProcessorJob.perform_later(@call_analysis.id)
        render json: @call_analysis.as_json(
          include: {
            contact: { only: [:id, :name] },
            user: { only: [:id, :name] }
          }
        ), status: :accepted
      else
        render json: { errors: @call_analysis.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Processamento síncrono para transcrições curtas
      analyzer = CallAnalysisService::Analyzer.new(
        transcript: transcript,
        account: current_account,
        user: analyzed_user
      )

      analysis_result = analyzer.analyze

      @call_analysis = current_account.call_analyses.new(
        transcript: transcript,
        contact: contact,
        user: analyzed_user,
        created_by: Current.user,
        deal_id: call_analysis_params[:deal_id],
        analysis_result: analysis_result,
        summary: analysis_result[:summary],
        next_steps: analysis_result[:next_steps],
        objections: analysis_result[:objections],
        competitors_mentioned: analysis_result[:competitors_mentioned],
        seller_score: analysis_result[:seller_score],
        pdi_points: analysis_result[:pdi_points],
        processing_status: 'completed'
      )

      if @call_analysis.save
        render json: @call_analysis.as_json(
          include: {
            contact: { only: [:id, :name] },
            user: { only: [:id, :name] }
          }
        ), status: :created
      else
        render json: { errors: @call_analysis.errors.full_messages }, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    Rails.logger.error("CallAnalysesController#create error: #{e.message}")
    render json: { error: 'Erro ao processar análise. Tente novamente.' }, status: :internal_server_error
  end

  def update
    authorize_access!

    if @call_analysis.update(update_params)
      render json: @call_analysis
    else
      render json: { errors: @call_analysis.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_access!

    @call_analysis.destroy
    head :ok
  end

  private

  def set_call_analysis
    @call_analysis = current_account.call_analyses.find(params[:id])
  end

  def authorize_access!
    # Agents só podem acessar suas próprias análises
    return if Current.account_user.administrator?
    return if @call_analysis.user_id == Current.user.id

    render json: { error: 'Acesso não autorizado' }, status: :forbidden
  end

  def call_analysis_params
    params.require(:call_analysis).permit(:transcript, :contact_id, :user_id, :deal_id)
  end

  def update_params
    params.require(:call_analysis).permit(:summary)
  end
end

