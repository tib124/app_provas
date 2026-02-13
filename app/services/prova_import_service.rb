# frozen_string_literal: true

require 'csv'

class ProvaImportService
  REQUIRED_HEADERS = %w[prova_titulo].freeze
  OPTIONAL_HEADERS = %w[aluno_ra data_criacao questao_enunciado questao_tipo questao_peso questao_respostas resposta_colocada resposta_correta].freeze
  ALL_KNOWN_HEADERS = (REQUIRED_HEADERS + OPTIONAL_HEADERS).freeze

  HEADER_ALIASES = {
    'prova_titulo' => 'prova_titulo', 'titulo' => 'prova_titulo', 'Titulo' => 'prova_titulo',
    'PROVA_TITULO' => 'prova_titulo', 'Prova_Titulo' => 'prova_titulo', 'titulo_prova' => 'prova_titulo',
    'aluno_ra' => 'aluno_ra', 'ra' => 'aluno_ra', 'RA' => 'aluno_ra', 'Aluno_RA' => 'aluno_ra',
    'ALUNO_RA' => 'aluno_ra', 'ra_aluno' => 'aluno_ra',
    'data_criacao' => 'data_criacao', 'data' => 'data_criacao', 'Data' => 'data_criacao',
    'DATA_CRIACAO' => 'data_criacao', 'Data_Criacao' => 'data_criacao',
    'questao_enunciado' => 'questao_enunciado', 'enunciado' => 'questao_enunciado',
    'QUESTAO_ENUNCIADO' => 'questao_enunciado', 'Enunciado' => 'questao_enunciado',
    'questao_tipo' => 'questao_tipo', 'tipo' => 'questao_tipo', 'Tipo' => 'questao_tipo',
    'QUESTAO_TIPO' => 'questao_tipo',
    'questao_peso' => 'questao_peso', 'peso' => 'questao_peso', 'Peso' => 'questao_peso',
    'QUESTAO_PESO' => 'questao_peso',
    'questao_respostas' => 'questao_respostas', 'respostas' => 'questao_respostas',
    'QUESTAO_RESPOSTAS' => 'questao_respostas', 'Respostas' => 'questao_respostas',
    'alternativas' => 'questao_respostas', 'opcoes' => 'questao_respostas',
    'resposta_colocada' => 'resposta_colocada', 'resposta_aluno' => 'resposta_colocada',
    'RESPOSTA_COLOCADA' => 'resposta_colocada', 'Resposta_Colocada' => 'resposta_colocada',
    'resposta_correta' => 'resposta_correta', 'gabarito' => 'resposta_correta',
    'RESPOSTA_CORRETA' => 'resposta_correta', 'Resposta_Correta' => 'resposta_correta'
  }.freeze

  def initialize(usuario, csv_file)
    @usuario = usuario
    @csv_file = csv_file
  end

  def call
    validate_file!
    csv_content = read_and_normalize_encoding
    separator = detect_separator(csv_content)
    rows = parse_csv(csv_content, separator)
    import_provas(rows)
  rescue CSV::MalformedCSVError => e
    { success: false, message: "Arquivo CSV mal formatado: #{e.message}" }
  end

  private

  # --- Validação do arquivo ---

  def validate_file!
    raise ArgumentError, "Nenhum arquivo foi enviado." if @csv_file.blank?

    filename = @csv_file.original_filename.to_s.downcase
    unless filename.end_with?('.csv', '.txt')
      raise ArgumentError, "Formato de arquivo inválido. Envie um arquivo .csv"
    end
  end

  # --- Leitura e normalização de encoding ---

  def read_and_normalize_encoding
    raw = @csv_file.read.dup

    # Remover BOM (Byte Order Mark) do UTF-8 — comum em arquivos do Excel
    raw.sub!("\xEF\xBB\xBF".b, ''.b)

    encode_to_utf8(raw)
  end

  def encode_to_utf8(raw)
    if raw.force_encoding('UTF-8').valid_encoding?
      return raw.force_encoding('UTF-8')
    end

    %w[Windows-1252 ISO-8859-1].each do |enc|
      attempt = raw.dup.force_encoding(enc)
      if attempt.valid_encoding?
        return attempt.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end

    raw.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace, replace: '?')
  end

  # --- Detecção automática de separador ---

  def detect_separator(content)
    first_line = content.lines.first.to_s
    semicolons = first_line.count(';')
    commas = first_line.count(',')
    semicolons > commas ? ';' : ','
  end

  # --- Parse do CSV com validação de headers ---

  def parse_csv(content, separator)
    rows = CSV.parse(content, headers: true, col_sep: separator, liberal_parsing: true, skip_blanks: true)

    if rows.headers.compact.empty?
      raise ArgumentError, "Arquivo CSV vazio ou sem cabeçalho."
    end

    normalize_headers!(rows)

    missing = REQUIRED_HEADERS - rows.headers.map(&:to_s)
    if missing.any?
      raise ArgumentError, "Colunas obrigatórias não encontradas: #{missing.join(', ')}. Colunas encontradas: #{rows.headers.compact.join(', ')}"
    end

    rows
  end

  def normalize_headers!(rows)
    rows.each do |row|
      row.headers.each do |header|
        next if header.nil?
        normalized = HEADER_ALIASES[header.strip]
        if normalized && normalized != header
          row[normalized] = row[header] unless row[normalized]
        end
      end
    end
  end

  # --- Importação principal com transaction ---

  def import_provas(rows)
    if rows.empty?
      return { success: false, message: "Arquivo CSV vazio." }
    end

    provas_criadas = 0
    provas_existentes = 0
    questoes_criadas = 0
    gabaritos_criados = 0
    failed = []
    avisos = []

    provas_agrupadas = agrupar_por_prova(rows)

    ActiveRecord::Base.transaction do
      provas_agrupadas.each_with_index do |(prova_key, questoes_rows), idx|
        first_line = find_first_csv_line(rows, questoes_rows.first)
        result = process_prova(prova_key, questoes_rows, first_line)

        if result[:success]
          provas_criadas += result[:provas_criadas]
          provas_existentes += result[:provas_existentes]
          questoes_criadas += result[:questoes_criadas]
          gabaritos_criados += result[:gabaritos_criados]
          avisos.concat(result[:avisos]) if result[:avisos]&.any?
        else
          failed << result[:error]
        end
      end

      if failed.any?
        raise ActiveRecord::Rollback
      end
    end

    message = build_message(provas_criadas, provas_existentes, questoes_criadas, gabaritos_criados, avisos, failed)

    {
      success: failed.empty?,
      message: message
    }
  end

  def find_first_csv_line(all_rows, target_row)
    all_rows.each_with_index do |row, idx|
      return idx + 2 if row == target_row # +2: header é linha 1
    end
    2
  end

  # --- Agrupamento por prova ---

  def agrupar_por_prova(rows)
    grouped = {}

    rows.each do |row|
      titulo = row['prova_titulo']&.to_s&.strip
      aluno_ra = row['aluno_ra']&.to_s&.strip&.upcase.presence
      data_criacao = row['data_criacao']&.to_s&.strip.presence

      key = "#{titulo}|#{aluno_ra}|#{data_criacao}"
      grouped[key] ||= []
      grouped[key] << row
    end

    grouped
  end

  # --- Processamento de cada prova ---

  def process_prova(prova_key, questoes_rows, line_number)
    titulo, aluno_ra, data_criacao_str = prova_key.split('|')
    titulo = titulo&.strip
    aluno_ra = aluno_ra&.strip.presence
    data_criacao_str = data_criacao_str&.strip.presence

    avisos = []

    if titulo.blank?
      return {
        success: false,
        error: "Linha #{line_number}: Título da prova é obrigatório"
      }
    end

    # Validar aluno se fornecido
    if aluno_ra.present?
      aluno = @usuario.alunos.find_by(ra: aluno_ra)

      unless aluno
        return {
          success: false,
          error: "Linha #{line_number}: Aluno com RA '#{aluno_ra}' não encontrado. Cadastre o aluno antes de importar a prova."
        }
      end
    end

    # Parsear data com suporte a formato brasileiro
    data_criacao = parse_data(data_criacao_str, line_number, avisos)

    # Verificar se prova já existe
    prova = @usuario.provas.find_by(titulo: titulo, data_criacao: data_criacao, aluno_ra: aluno_ra)
    is_new_prova = prova.nil?

    unless prova
      prova_attrs = { titulo: titulo, data_criacao: data_criacao }
      prova_attrs[:aluno_ra] = aluno_ra if aluno_ra.present?

      prova = @usuario.provas.new(prova_attrs)
      prova.skip_validations = true
      unless prova.save
        return {
          success: false,
          error: "Linha #{line_number}: Erro ao criar prova '#{titulo}' — #{prova.errors.full_messages.join(', ')}"
        }
      end
    end

    questoes_criadas = 0
    gabaritos_criados = 0

    questoes_rows.each_with_index do |row, q_idx|
      q_line = line_number + q_idx
      result = process_questao_e_gabarito(prova, row, q_line)

      if result[:success]
        questoes_criadas += result[:questoes_criadas]
        gabaritos_criados += result[:gabaritos_criados]
      else
        return {
          success: false,
          error: result[:error]
        }
      end
    end

    {
      success: true,
      provas_criadas: is_new_prova ? 1 : 0,
      provas_existentes: is_new_prova ? 0 : 1,
      questoes_criadas: questoes_criadas,
      gabaritos_criados: gabaritos_criados,
      avisos: avisos
    }
  end

  # --- Parse de data com suporte a formatos BR ---

  def parse_data(data_str, line_number, avisos)
    return Date.current if data_str.blank?

    # Formato brasileiro: DD/MM/YYYY ou DD-MM-YYYY
    if data_str.match?(%r{\A\d{1,2}[/\-]\d{1,2}[/\-]\d{4}\z})
      parts = data_str.split(%r{[/\-]})
      begin
        return Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
      rescue Date::Error
        avisos << "Linha #{line_number}: Data '#{data_str}' inválida, usando data atual"
        return Date.current
      end
    end

    # Formato ISO: YYYY-MM-DD
    if data_str.match?(/\A\d{4}-\d{1,2}-\d{1,2}\z/)
      begin
        return Date.parse(data_str)
      rescue Date::Error
        avisos << "Linha #{line_number}: Data '#{data_str}' inválida, usando data atual"
        return Date.current
      end
    end

    # Tentar parse genérico como último recurso
    begin
      Date.parse(data_str)
    rescue StandardError
      avisos << "Linha #{line_number}: Data '#{data_str}' não reconhecida, usando data atual"
      Date.current
    end
  end

  # --- Processamento de questão + gabarito ---

  def process_questao_e_gabarito(prova, row, line_number)
    enunciado = row['questao_enunciado']&.to_s&.strip
    tipo = row['questao_tipo']&.to_s&.strip&.downcase
    peso_str = row['questao_peso']&.to_s&.strip
    respostas_raw = row['questao_respostas']&.to_s&.strip
    resposta_colocada = row['resposta_colocada']&.to_s&.strip
    resposta_correta = row['resposta_correta']&.to_s&.strip

    # Se não tiver enunciado, pular silenciosamente
    return { success: true, questoes_criadas: 0, gabaritos_criados: 0 } if enunciado.blank?

    peso = peso_str.present? ? peso_str.to_f : 1.0

    # Converter respostas: "A) 3 | B) 4 | C) 5" → "A) 3\nB) 4\nC) 5"
    respostas = convert_respostas(respostas_raw)

    questao = prova.questoes.build(
      tipo: tipo.presence || 'multipla_escolha',
      enunciado: enunciado,
      peso: peso,
      respostas: respostas,
      resposta_colocada: resposta_colocada.presence
    )

    unless questao.save
      return {
        success: false,
        error: "Linha #{line_number}: Erro ao criar questão '#{enunciado.truncate(40)}' — #{questao.errors.full_messages.join(', ')}"
      }
    end

    if resposta_correta.present?
      gabarito = questao.build_gabarito(
        prova_id: prova.id,
        resposta_correta: resposta_correta
      )

      unless gabarito.save
        return {
          success: false,
          error: "Linha #{line_number}: Erro ao criar gabarito para '#{enunciado.truncate(40)}' — #{gabarito.errors.full_messages.join(', ')}"
        }
      end

      return {
        success: true,
        questoes_criadas: 1,
        gabaritos_criados: 1
      }
    end

    { success: true, questoes_criadas: 1, gabaritos_criados: 0 }
  end

  # --- Conversão de formato de respostas ---

  def convert_respostas(raw)
    return nil if raw.blank?

    # Se já tem quebras de linha, manter como está
    return raw if raw.include?("\n")

    # Converter separador | para quebra de linha
    if raw.include?('|')
      return raw.split('|').map(&:strip).reject(&:blank?).join("\n")
    end

    raw
  end

  # --- Mensagem final ---

  def build_message(provas_criadas, provas_existentes, questoes_criadas, gabaritos_criados, avisos, failed)
    parts = []
    parts << "#{provas_criadas} prova(s) criada(s)" if provas_criadas > 0
    parts << "#{provas_existentes} prova(s) já existente(s) atualizada(s)" if provas_existentes > 0
    parts << "#{questoes_criadas} questão(ões) criada(s)" if questoes_criadas > 0
    parts << "#{gabaritos_criados} gabarito(s) criado(s)" if gabaritos_criados > 0

    message = if parts.any?
                "Importação concluída:\n- #{parts.join("\n- ")}"
              else
                "Nenhum dado foi importado."
              end

    if avisos&.any?
      message += "\n\n⚠️ Avisos:\n"
      message += avisos.first(5).join("\n")
      message += "\n... e mais #{avisos.length - 5} aviso(s)" if avisos.length > 5
    end

    if failed.any?
      error_count = failed.length
      displayed_errors = failed.first(5)

      message += "\n\n❌ Erros encontrados (#{error_count} total) — nenhum registro foi salvo:\n"
      message += displayed_errors.join("\n")
      message += "\n... e mais #{error_count - 5} erro(s)" if error_count > 5
    end

    message
  end
end

