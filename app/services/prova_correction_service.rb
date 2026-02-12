# frozen_string_literal: true

class ProvaCorrectionService
  def initialize(prova)
    @prova = prova
  end

  # Calcula a pontuação total da prova
  def calculate_score
    questoes_com_respostas = @prova.questoes.joins(:gabarito).where.not(resposta_colocada: [nil, ''])

    questoes_com_respostas.sum do |questao|
      resposta_correta = questao.gabarito.resposta_correta
      resposta_colocada = questao.resposta_colocada

      if respostas_iguais?(resposta_correta, resposta_colocada)
        questao.peso.to_f
      else
        0.0
      end
    end
  end

  # Calcula a pontuação máxima possível
  def calculate_max_score
    @prova.questoes.joins(:gabarito).sum('questoes.peso').to_f
  end

  # Calcula a porcentagem
  def calculate_percentage
    max_score = calculate_max_score
    return 0.0 if max_score.zero?

    (calculate_score / max_score * 100).round(2)
  end

  # Retorna detalhes de cada questão
  def get_details
    @prova.questoes.joins(:gabarito).map do |questao|
      resposta_correta = questao.gabarito.resposta_correta
      resposta_colocada = questao.resposta_colocada
      correta = respostas_iguais?(resposta_correta, resposta_colocada) && resposta_colocada.present?

      {
        questao_id: questao.id,
        resposta_correta: resposta_correta,
        resposta_colocada: resposta_colocada.presence || "—",
        peso: questao.peso,
        pontos: correta ? questao.peso.to_f : 0.0,
        correta: correta
      }
    end
  end

  private

  def respostas_iguais?(resposta_correta, resposta_colocada)
    return false if resposta_correta.blank? || resposta_colocada.blank?

    # Normaliza as respostas: remove espaços extras e converte para minúsculas
    normalize(resposta_correta) == normalize(resposta_colocada)
  end

  def normalize(resposta)
    resposta.to_s.strip.downcase.gsub(/\s+/, ' ')
  end
end
