# frozen_string_literal: true

class ProvaCorrectionService
  def initialize(prova)
    @prova = prova
  end

  # Calcula a pontuação total da prova (usa resultado salvo no banco para dissertativas)
  def calculate_score
    questoes_com_respostas = @prova.questoes.joins(:gabarito).includes(:gabarito)

    questoes_com_respostas.sum do |questao|
      calcular_pontos_questao(questao)
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

  # Retorna detalhes de cada questão (sem chamar IA — usa resultado salvo)
  def get_details
    @prova.questoes.joins(:gabarito).includes(:gabarito).map do |questao|
      build_detail(questao)
    end
  end

  # Corrige APENAS as questões dissertativas com IA e salva no banco
  # Retorna quantidade de questões corrigidas
  def corrigir_dissertativas_com_ia!
    questoes_dissertativas = @prova.questoes.joins(:gabarito).includes(:gabarito)
                                  .where(tipo: "dissertativa")

    corrigidas = 0
    questoes_dissertativas.each do |questao|
      next if questao.resposta_colocada.blank?

      gabarito = questao.gabarito
      resultado = DissertativaGraderService.new(
        enunciado: questao.enunciado,
        resposta_aluno: questao.resposta_colocada,
        resposta_gabarito: gabarito.resposta_correta
      ).call

      gabarito.update!(
        avaliacao_ia: resultado[:avaliacao],
        justificativa_ia: resultado[:justificativa]
      )
      corrigidas += 1

      # Pausa entre chamadas para não estourar rate limit (30 RPM)
      sleep(2.2) if corrigidas < questoes_dissertativas.size
    end

    corrigidas
  end

  private

  def calcular_pontos_questao(questao)
    resposta_colocada = questao.resposta_colocada
    return 0.0 if resposta_colocada.blank?

    resposta_correta = questao.gabarito.resposta_correta

    if questao.tipo_dissertativa?
      # Usa resultado salvo no banco (se já foi corrigido com IA)
      calcular_pontos_dissertativa_salva(questao)
    else
      respostas_iguais?(resposta_correta, resposta_colocada) ? questao.peso.to_f : 0.0
    end
  end

  def calcular_pontos_dissertativa_salva(questao)
    avaliacao = questao.gabarito.avaliacao_ia

    case avaliacao
    when "total"
      questao.peso.to_f
    when "parcial"
      (questao.peso.to_f / 2.0).round(2)
    else
      # Se ainda não foi corrigida com IA, retorna 0
      0.0
    end
  end

  def build_detail(questao)
    resposta_correta = questao.gabarito.resposta_correta
    resposta_colocada = questao.resposta_colocada

    if questao.tipo_dissertativa?
      build_detail_dissertativa(questao, resposta_correta, resposta_colocada)
    else
      build_detail_multipla_escolha(questao, resposta_correta, resposta_colocada)
    end
  end

  def build_detail_multipla_escolha(questao, resposta_correta, resposta_colocada)
    correta = respostas_iguais?(resposta_correta, resposta_colocada) && resposta_colocada.present?

    {
      questao_id: questao.id,
      tipo: questao.tipo,
      resposta_correta: resposta_correta,
      resposta_colocada: resposta_colocada.presence || "—",
      peso: questao.peso,
      pontos: correta ? questao.peso.to_f : 0.0,
      correta: correta,
      avaliacao_ia: nil,
      justificativa_ia: nil
    }
  end

  def build_detail_dissertativa(questao, resposta_correta, resposta_colocada)
    gabarito = questao.gabarito
    avaliacao = gabarito.avaliacao_ia
    justificativa = gabarito.justificativa_ia

    if resposta_colocada.blank?
      return {
        questao_id: questao.id,
        tipo: questao.tipo,
        resposta_correta: resposta_correta,
        resposta_colocada: "—",
        peso: questao.peso,
        pontos: 0.0,
        correta: false,
        avaliacao_ia: "incorreta",
        justificativa_ia: "Resposta em branco."
      }
    end

    # Se ainda não foi corrigida com IA, marcar como pendente
    if avaliacao.blank?
      return {
        questao_id: questao.id,
        tipo: questao.tipo,
        resposta_correta: resposta_correta,
        resposta_colocada: resposta_colocada,
        peso: questao.peso,
        pontos: nil,
        correta: nil,
        avaliacao_ia: "pendente",
        justificativa_ia: "Aguardando correção com IA. Clique em '🤖 Corrigir com IA' para avaliar."
      }
    end

    pontos = case avaliacao
             when "total" then questao.peso.to_f
             when "parcial" then (questao.peso.to_f / 2.0).round(2)
             else 0.0
             end

    {
      questao_id: questao.id,
      tipo: questao.tipo,
      resposta_correta: resposta_correta,
      resposta_colocada: resposta_colocada,
      peso: questao.peso,
      pontos: pontos,
      correta: avaliacao == "total",
      avaliacao_ia: avaliacao,
      justificativa_ia: justificativa
    }
  end

  def respostas_iguais?(resposta_correta, resposta_colocada)
    return false if resposta_correta.blank? || resposta_colocada.blank?

    normalize(resposta_correta) == normalize(resposta_colocada)
  end

  def normalize(resposta)
    resposta.to_s.strip.downcase.gsub(/\s+/, ' ')
  end
end
