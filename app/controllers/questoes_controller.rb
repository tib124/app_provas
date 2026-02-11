# frozen_string_literal: true

class QuestoesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prova
  before_action :set_questao, only: %i[edit update destroy]

  def index
    @questoes = @prova.questoes.order(created_at: :asc)
  end

  def new
    @questao = @prova.questoes.new(tipo: :multipla_escolha, peso: 1.0)
  end

  def create
    @questao = @prova.questoes.new(questao_params)

    if @questao.save
      redirect_to prova_questoes_path(@prova), notice: "Questão criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @questao.update(questao_params)
      redirect_to prova_questoes_path(@prova), notice: "Questão atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @questao.destroy
    redirect_to prova_questoes_path(@prova), notice: "Questão removida."
  end

  private

  def set_prova
    @prova = current_user.provas.find(params[:prova_id])
  end

  def set_questao
    @questao = @prova.questoes.find(params[:id])
  end

  def questao_params
    params.require(:questao).permit(:tipo, :enunciado, :peso, :respostas, :resposta_colocada)
  end
end
