# frozen_string_literal: true

require "faraday"
require "json"

class DissertativaGraderService
  GROQ_MODEL = "llama-3.3-70b-versatile"
  GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

  # Avalia uma resposta dissertativa usando Groq (Llama 3.3 70B)
  # Retorna: { avaliacao: "total"|"parcial"|"incorreta", justificativa: "..." }
  def initialize(enunciado:, resposta_aluno:, resposta_gabarito:)
    @enunciado = enunciado
    @resposta_aluno = resposta_aluno
    @resposta_gabarito = resposta_gabarito
  end

  def call
    return resultado_vazio if @resposta_aluno.blank?
    return fallback_sem_api unless api_key_presente?

    avaliar_com_ia
  rescue Faraday::Error, JSON::ParserError, StandardError => e
    Rails.logger.error("[DissertativaGrader] Erro ao chamar IA: #{e.message}")
    fallback_comparacao_simples
  end

  private

  def api_key_presente?
    api_key.present?
  end

  def api_key
    @api_key ||= ENV["GROQ_API_KEY"].presence ||
                 (Rails.application.config.respond_to?(:groq_api_key) && Rails.application.config.groq_api_key)
  end

  def avaliar_com_ia
    conn = Faraday.new do |f|
      f.options.timeout = 15
      f.options.open_timeout = 5
    end

    response = conn.post(GROQ_URL) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = build_request_body.to_json
    end

    if response.success?
      return parse_response(response.body)
    end

    Rails.logger.error("[DissertativaGrader] Groq retornou #{response.status}: #{response.body[0..300]}")
    fallback_comparacao_simples
  end

  def build_request_body
    {
      model: GROQ_MODEL,
      messages: [
        {
          role: "system",
          content: "Você é um professor avaliando questões dissertativas. Responda SEMPRE exatamente neste formato (duas linhas):\nAVALIACAO: total\nJUSTIFICATIVA: explicação curta\n\nSubstitua 'total' por 'parcial' ou 'incorreta' conforme a avaliação."
        },
        {
          role: "user",
          content: build_prompt
        }
      ],
      temperature: 0.1,
      max_tokens: 150
    }
  end

  def build_prompt
    <<~PROMPT
      ENUNCIADO: #{@enunciado}
      GABARITO (resposta esperada): #{@resposta_gabarito}
      RESPOSTA DO ALUNO: #{@resposta_aluno}

      Critérios:
      - TOTAL: resposta correta e equivalente ao gabarito (não precisa ser idêntica).
      - PARCIAL: parcialmente correta, incompleta ou com algum erro conceitual.
      - INCORRETA: completamente errada ou sem relação com o gabarito.
    PROMPT
  end

  def parse_response(body)
    data = JSON.parse(body)
    text = data.dig("choices", 0, "message", "content").to_s.strip

    avaliacao = extrair_avaliacao(text)
    justificativa = extrair_justificativa(text)

    {
      avaliacao: avaliacao,
      justificativa: justificativa
    }
  end

  def extrair_avaliacao(text)
    match = text.match(/AVALIACAO:\s*(total|parcial|incorreta)/i)
    return match[1].downcase if match

    texto_lower = text.downcase
    if texto_lower.include?("total")
      "total"
    elsif texto_lower.include?("parcial")
      "parcial"
    else
      "incorreta"
    end
  end

  def extrair_justificativa(text)
    match = text.match(/JUSTIFICATIVA:\s*(.+)/i)
    return match[1].strip if match

    text.truncate(150)
  end

  # --- Fallbacks ---

  def resultado_vazio
    {
      avaliacao: "incorreta",
      justificativa: "Resposta em branco."
    }
  end

  def fallback_sem_api
    Rails.logger.warn("[DissertativaGrader] GROQ_API_KEY não configurada. Usando comparação simples.")
    fallback_comparacao_simples
  end

  def fallback_comparacao_simples
    normalizada_aluno = normalize(@resposta_aluno)
    normalizada_gabarito = normalize(@resposta_gabarito)

    if normalizada_aluno == normalizada_gabarito
      { avaliacao: "total", justificativa: "Resposta idêntica ao gabarito." }
    elsif palavras_em_comum_percentual(normalizada_aluno, normalizada_gabarito) >= 0.5
      { avaliacao: "parcial", justificativa: "Resposta parcialmente similar ao gabarito (configure GROQ_API_KEY para avaliação com IA)." }
    else
      { avaliacao: "incorreta", justificativa: "Resposta diferente do gabarito (configure GROQ_API_KEY para avaliação com IA)." }
    end
  end

  def normalize(text)
    text.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def palavras_em_comum_percentual(texto1, texto2)
    palavras1 = texto1.split.to_set
    palavras2 = texto2.split.to_set

    return 0.0 if palavras2.empty?

    (palavras1 & palavras2).size.to_f / palavras2.size
  end
end
