class Gabarito < ApplicationRecord
  belongs_to :prova
  belongs_to :questao

  delegate :tipo, :enunciado, :peso, to: :questao

  validates :resposta_correta, presence: true

  validates :questao, presence: true, on: :create
  validate :questao_deve_pertencer_a_prova

  private

  def questao_deve_pertencer_a_prova
    return if questao.blank? || prova_id.blank?
    return if questao.prova_id == prova_id

    errors.add(:questao, "não pertence a esta prova")
  end
end
