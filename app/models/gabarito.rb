class Gabarito < ApplicationRecord
  belongs_to :prova
  belongs_to :questao, optional: true

  before_validation :sync_from_questao, if: -> { questao.present? }

  enum :tipo,
       {
         multipla_escolha: "multipla_escolha",
         dissertativa: "dissertativa"
       },
       prefix: true

  validates :tipo, presence: true
  validates :enunciado, presence: true
  validates :resposta_correta, presence: true
  validates :peso,
            presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }

  validates :questao, presence: true, on: :create
  validate :questao_deve_pertencer_a_prova

  private

  def sync_from_questao
    self.prova_id ||= questao.prova_id
    self.tipo = questao.tipo
    self.enunciado = questao.enunciado
    self.peso = questao.peso
  end

  def questao_deve_pertencer_a_prova
    return if questao.blank? || prova_id.blank?
    return if questao.prova_id == prova_id

    errors.add(:questao, "não pertence a esta prova")
  end
end
