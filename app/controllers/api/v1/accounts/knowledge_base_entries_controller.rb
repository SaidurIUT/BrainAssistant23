class Api::V1::Accounts::KnowledgeBaseEntriesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_entry, except: [:index, :create]
  before_action :check_authorization

  def index
    @entries = Current.account.knowledge_base_entries.order(created_at: :asc)
    render json: @entries
  end

  def show
    render json: @entry
  end

  def create
    @entry = Current.account.knowledge_base_entries.create!(permitted_params)
    render json: @entry, status: :created
  end

  def update
    @entry.update!(permitted_params)
    render json: @entry
  end

  def destroy
    @entry.destroy!
    head :ok
  end

  private

  def fetch_entry
    @entry = Current.account.knowledge_base_entries.find(params[:id])
  end

  def permitted_params
    params.require(:knowledge_base_entry).permit(:level, :description)
  end
end
