# frozen_string_literal: true

require 'csv'

class AlunoImportService
  REQUIRED_HEADERS = %w[ra nome email].freeze
  HEADER_ALIASES = {
    'ra' => 'ra', 'RA' => 'ra', 'Ra' => 'ra', 'matricula' => 'ra', 'registro' => 'ra',
    'nome' => 'nome', 'Nome' => 'nome', 'NOME' => 'nome', 'name' => 'nome',
    'email' => 'email', 'Email' => 'email', 'EMAIL' => 'email', 'e-mail' => 'email', 'E-mail' => 'email'
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
    import_alunos(rows)
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

    # Tentar converter para UTF-8 com fallback chain
    encode_to_utf8(raw)
  end

  def encode_to_utf8(raw)
    # Se já é UTF-8 válido, retornar
    if raw.force_encoding('UTF-8').valid_encoding?
      return raw.force_encoding('UTF-8')
    end

    # Tentar encodings comuns do Windows/Excel brasileiro
    %w[Windows-1252 ISO-8859-1].each do |enc|
      attempt = raw.dup.force_encoding(enc)
      if attempt.valid_encoding?
        return attempt.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end

    # Último recurso: forçar UTF-8 substituindo bytes inválidos
    raw.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace, replace: '?')
  end

  # --- Detecção automática de separador ---

  def detect_separator(content)
    first_line = content.lines.first.to_s

    # Contar ocorrências de ; e , na primeira linha (header)
    semicolons = first_line.count(';')
    commas = first_line.count(',')

    # Se tem mais ponto-e-vírgula que vírgulas, usar ;
    semicolons > commas ? ';' : ','
  end

  # --- Parse do CSV com validação de headers ---

  def parse_csv(content, separator)
    rows = CSV.parse(content, headers: true, col_sep: separator, liberal_parsing: true, skip_blanks: true)

    if rows.headers.compact.empty?
      raise ArgumentError, "Arquivo CSV vazio ou sem cabeçalho."
    end

    # Normalizar headers usando aliases
    normalize_headers!(rows)

    # Validar headers obrigatórios
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

  # --- Importação com transaction ---

  def import_alunos(rows)
    if rows.empty?
      return { success: false, message: "Arquivo CSV vazio." }
    end

    created = 0
    updated = 0
    skipped = 0
    failed = []

    ActiveRecord::Base.transaction do
      rows.each_with_index do |row, index|
        line_number = index + 2 # +2 pois header é linha 1
        result = process_row(row, line_number)

        case result[:status]
        when :created  then created += 1
        when :updated  then updated += 1
        when :skipped  then skipped += 1
        when :failed   then failed << result[:error]
        end
      end

      # Se houver erros, fazer rollback de tudo
      if failed.any?
        raise ActiveRecord::Rollback
      end
    end

    message = build_message(created, updated, skipped, failed)

    {
      success: failed.empty?,
      message: message,
      created: created,
      updated: updated,
      skipped: skipped
    }
  end

  def process_row(row, line_number)
    ra = row['ra']&.to_s&.strip&.upcase
    nome = row['nome']&.to_s&.strip
    email = row['email']&.to_s&.strip&.downcase

    # Pular linhas completamente vazias
    if ra.blank? && nome.blank? && email.blank?
      return { status: :skipped }
    end

    # Validar campos obrigatórios
    campos_vazios = []
    campos_vazios << 'RA' if ra.blank?
    campos_vazios << 'Nome' if nome.blank?
    campos_vazios << 'Email' if email.blank?

    if campos_vazios.any?
      return {
        status: :failed,
        error: "Linha #{line_number}: #{campos_vazios.join(', ')} obrigatório(s) — RA: '#{ra}', Nome: '#{nome}'"
      }
    end

    aluno = @usuario.alunos.find_or_initialize_by(ra: ra)

    if aluno.new_record?
      aluno.assign_attributes(nome: nome, email: email)

      if aluno.save
        { status: :created }
      else
        { status: :failed, error: "Linha #{line_number} (#{ra}): #{aluno.errors.full_messages.join(', ')}" }
      end
    else
      if aluno.update(nome: nome, email: email)
        { status: :updated }
      else
        { status: :failed, error: "Linha #{line_number} (#{ra}): #{aluno.errors.full_messages.join(', ')}" }
      end
    end
  end

  def build_message(created, updated, skipped, failed)
    parts = []
    parts << "#{created} aluno(s) criado(s)" if created > 0
    parts << "#{updated} aluno(s) atualizado(s)" if updated > 0
    parts << "#{skipped} linha(s) vazia(s) ignorada(s)" if skipped > 0

    message = if parts.any?
                "Importação concluída: #{parts.join(', ')}."
              else
                "Nenhum aluno foi importado."
              end

    if failed.any?
      error_count = failed.length
      displayed_errors = failed.first(5)

      message += "\n\n⚠️ Erros encontrados (#{error_count} total) — nenhum registro foi salvo:\n"
      message += displayed_errors.join("\n")
      message += "\n... e mais #{error_count - 5} erro(s)" if error_count > 5
    end

    message
  end
end
