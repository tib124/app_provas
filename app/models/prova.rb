# frozen_string_literal: true

class Prova < ApplicationRecord
  belongs_to :usuario, class_name: "User"
  belongs_to :aluno,
             foreign_key: :aluno_ra,
             primary_key: :ra,
             optional: true,
             inverse_of: :provas

  has_many :gabaritos, dependent: :destroy, inverse_of: :prova
  has_many :questoes, dependent: :destroy, inverse_of: :prova

  accepts_nested_attributes_for :questoes, allow_destroy: true, reject_if: :all_blank

  validates :titulo, presence: true
  validates :aluno, presence: true, on: :create
  validate :precisa_ter_pelo_menos_uma_questao, on: :create
  validate :aluno_deve_pertencer_ao_mesmo_usuario

  private

  def precisa_ter_pelo_menos_uma_questao
    return if questoes.reject(&:marked_for_destruction?).any?

    errors.add(:base, "Adicione pelo menos uma questão.")
  end

  def aluno_deve_pertencer_ao_mesmo_usuario
    return if aluno.blank? || usuario_id.blank?
    return if aluno.usuario_id == usuario_id

    errors.add(:aluno, "deve pertencer ao mesmo usuário")
  end
end
