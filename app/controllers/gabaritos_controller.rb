# frozen_string_literal: true

class GabaritosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prova
  before_action :set_questao, only: %i[new create edit update destroy]
  before_action :set_gabarito, only: %i[edit update destroy]

  def index
    @questoes = @prova.questoes.includes(:gabarito).order(created_at: :asc)
  end

  def new
    if @questao.gabarito.present?
      redirect_to edit_prova_questao_gabarito_path(@prova, @questao)
      return
    end

    @gabarito = @questao.build_gabarito
  end

  def create
    @gabarito = @questao.build_gabarito(gabarito_params)
    @gabarito.prova = @prova

    if @gabarito.save
      redirect_to prova_gabarito_path(@prova), notice: "Gabarito salvo com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @gabarito.update(gabarito_params)
      redirect_to prova_gabarito_path(@prova), notice: "Gabarito atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @gabarito.destroy
    redirect_to prova_gabarito_path(@prova), notice: "Gabarito removido."
  end

  private

  def set_prova
    @prova = current_user.provas.find(params[:prova_id])
  end

  def set_questao
    @questao = @prova.questoes.find(params[:questao_id])
  end

  def set_gabarito
    @gabarito = @questao.gabarito
    return if @gabarito.present?

    redirect_to new_prova_questao_gabarito_path(@prova, @questao), alert: "Crie o gabarito desta questão primeiro."
    nil
  end

  def gabarito_params
    params.require(:gabarito).permit(:resposta_correta)
  end
end
