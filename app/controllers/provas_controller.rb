# frozen_string_literal: true

class ProvasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prova, only: %i[show edit update destroy]
  before_action :load_alunos, only: %i[new edit create update]
  rescue_from ActiveRecord::RecordNotFound, with: :prova_not_found

  def index
    @provas = current_user.provas.order(data_criacao: :desc, created_at: :desc)
  end

  def show
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

  private

  def set_prova
    @prova = current_user.provas.find(params[:id])
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
