# frozen_string_literal: true

require 'csv'

class ProvaImportService
  def initialize(usuario, csv_file)
    @usuario = usuario
    @csv_file = csv_file
  end

  def call
    validate_file!
    import_provas
  end

  private

  def validate_file!
    if @csv_file.content_type != 'text/csv'
      raise "Arquivo deve ser CSV. Tipo enviado: #{@csv_file.content_type}"
    end
  end

  def import_provas
    csv_content = @csv_file.read
    
    # Converter para UTF-8 se necessário
    if csv_content.encoding.name != 'UTF-8'
      csv_content = csv_content.force_encoding('UTF-8')
    end
    
    rows = CSV.parse(csv_content, headers: true)
    
    if rows.empty?
      return { success: false, message: "Arquivo CSV vazio." }
    end

    created = 0
    failed = []

    rows.each_with_index do |row, index|
      result = process_row(row, index + 2) # +2 pois começa na linha 2 (header é linha 1)
      
      if result[:success]
        created += 1
      else
        failed << result[:error]
      end
    end

    message = build_message(created, failed)
    
    { 
      success: failed.empty?, 
      message: message,
      created: created
    }
  end

  def process_row(row, line_number)
    titulo = row['titulo']&.to_s&.strip
    aluno_ra = row['aluno_ra']&.to_s&.strip&.upcase
    data_criacao_str = row['data_criacao']&.to_s&.strip

    if titulo.blank?
      return { 
        success: false, 
        error: "Linha #{line_number}: Título é obrigatório"
      }
    end

    # Se aluno_ra for fornecido, validar que existe
    if aluno_ra.present?
      aluno = @usuario.alunos.find_by(ra: aluno_ra)
      
      unless aluno
        return { 
          success: false, 
          error: "Linha #{line_number}: Aluno com RA '#{aluno_ra}' não encontrado"
        }
      end
    end

    # Parsear data ou usar a data atual
    data_criacao = if data_criacao_str.present?
                     begin
                       Date.parse(data_criacao_str)
                     rescue StandardError
                       Date.current
                     end
                   else
                     Date.current
                   end

    prova = @usuario.provas.new(
      titulo: titulo,
      aluno_ra: aluno_ra,
      data_criacao: data_criacao
    )

    if prova.save
      return { success: true }
    else
      return { 
        success: false, 
        error: "Linha #{line_number} (#{titulo}): #{prova.errors.full_messages.join(', ')}"
      }
    end
  end

  def build_message(created, failed)
    message = "Importação concluída: #{created} prova(s) criada(s)"
    
    if failed.any?
      message += "\n\nErros encontrados:\n"
      message += failed.join("\n")
    end

    message
  end
end
