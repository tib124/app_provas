# frozen_string_literal: true

class AlunosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_aluno, only: %i[edit update destroy]

  def index
    @alunos = current_user.alunos.order(nome: :asc)
  end

  def new
    @aluno = current_user.alunos.new
  end

  def create
    @aluno = current_user.alunos.new(aluno_params_create)

    if @aluno.save
      redirect_to alunos_path, notice: "Aluno cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @aluno.update(aluno_params_update)
      redirect_to alunos_path, notice: "Aluno atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @aluno.destroy
    redirect_to alunos_path, notice: "Aluno removido."
  end

  private

  def set_aluno
    @aluno = current_user.alunos.find_by!(ra: params[:id])
  end

  def aluno_params_create
    params.require(:aluno).permit(:ra, :nome, :email)
  end

  def aluno_params_update
    params.require(:aluno).permit(:nome, :email)
  end
end
