# frozen_string_literal: true

class Questao < ApplicationRecord
  belongs_to :prova

  has_one :gabarito, dependent: :destroy, inverse_of: :questao

  enum :tipo,
       {
         multipla_escolha: "multipla_escolha",
         dissertativa: "dissertativa"
       },
       prefix: true

  validates :tipo, presence: true
  validates :enunciado, presence: true
  validates :peso,
            presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }

  validate :respostas_apenas_para_multipla_escolha
  validate :resposta_colocada_valida_para_multipla_escolha

  before_validation :normalize_respostas_for_tipo

  def alternativa_labels
    return [] unless tipo_multipla_escolha?

    respostas
      .to_s
      .lines
      .map(&:strip)
      .filter_map do |line|
        m = line.match(/\A([A-Za-z])\s*(?:\-|\)|\.|\])\s*/)
        m ? m[1].upcase : nil
      end
      .uniq
  end

  private

  def normalize_respostas_for_tipo
    if tipo_dissertativa?
      self.respostas = nil if respostas.present?
    end
  end

  def respostas_apenas_para_multipla_escolha
    if tipo_dissertativa? && respostas.present?
      errors.add(:respostas, "não pode ser preenchido para questão dissertativa")
    end

    if tipo_multipla_escolha? && respostas.to_s.strip.blank?
      errors.add(:respostas, "precisa ser preenchido para múltipla escolha")
    end
  end

  def resposta_colocada_valida_para_multipla_escolha
    return unless tipo_multipla_escolha?
    return if resposta_colocada.to_s.strip.blank?

    labels = alternativa_labels
    return if labels.empty?

    normalized = resposta_colocada.to_s.strip.upcase
    return if labels.include?(normalized)

    errors.add(:resposta_colocada, "deve ser uma das alternativas: #{labels.join(", ")}")
  end
end
