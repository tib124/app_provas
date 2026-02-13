# frozen_string_literal: true

class ProvasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prova, only: %i[show edit update destroy corrigir_ia]
  before_action :load_alunos, only: %i[new edit create update]
  rescue_from ActiveRecord::RecordNotFound, with: :prova_not_found

  def index
    @provas = current_user.provas.order(data_criacao: :desc, created_at: :desc)
  end

  def show
  end

  def corrigir_ia
    correction = ProvaCorrectionService.new(@prova)

    tem_dissertativas = @prova.questoes.joins(:gabarito).where(tipo: "dissertativa").exists?

    unless tem_dissertativas
      redirect_to prova_path(@prova), alert: "Esta prova não possui questões dissertativas."
      return
    end

    begin
      qtd = correction.corrigir_dissertativas_com_ia!
      redirect_to prova_path(@prova), notice: "✅ #{qtd} questão(ões) dissertativa(s) corrigida(s) com IA!"
    rescue StandardError => e
      redirect_to prova_path(@prova), alert: "Erro ao corrigir com IA: #{e.message}"
    end
  end

  def edit
  end

  def new
    @prova = current_user.provas.new(data_criacao: Date.current)
    @prova.questoes.build(tipo: :multipla_escolha, peso: 1.0)
  end

  def create
    @prova = current_user.provas.new(prova_params)
    @prova.data_criacao ||= Date.current

    if @prova.save
      redirect_to prova_path(@prova), notice: "Prova criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @prova.update(prova_params)
      redirect_to prova_path(@prova), notice: "Prova atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prova.destroy
    redirect_to provas_path, notice: "Prova removida."
  end

  def import
    @alunos = current_user.alunos.order(nome: :asc)
  end

  def process_import
    csv_file = params[:csv_file]

    if csv_file.blank?
      redirect_to provas_path, alert: "Por favor, selecione um arquivo CSV."
      return
    end

    begin
      result = ProvaImportService.new(current_user, csv_file).call

      if result[:success]
        redirect_to provas_path, notice: result[:message]
      else
        redirect_to import_provas_path, alert: result[:message]
      end
    rescue ArgumentError => e
      redirect_to import_provas_path, alert: e.message
    rescue StandardError => e
      redirect_to import_provas_path, alert: "Erro inesperado ao importar CSV: #{e.message}"
    end
  end

  private

  def set_prova
    @prova = current_user.provas.find_by!(slug: params[:id])
  end

  def prova_not_found
    redirect_to provas_path, alert: "Prova não encontrada."
  end

  def prova_params
    params.require(:prova).permit(
      :titulo,
      :data_criacao,
      :aluno_ra,
      questoes_attributes: %i[id tipo enunciado peso respostas resposta_colocada _destroy]
    )
  end

  def load_alunos
    @alunos = current_user.alunos.order(nome: :asc)
  end
end
