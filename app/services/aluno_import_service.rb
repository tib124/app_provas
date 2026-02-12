# frozen_string_literal: true

require 'csv'

class AlunoImportService
  def initialize(usuario, csv_file)
    @usuario = usuario
    @csv_file = csv_file
  end

  def call
    validate_file!
    import_alunos
  end

  private

  def validate_file!
    if @csv_file.content_type != 'text/csv'
      raise "Arquivo deve ser CSV. Tipo enviado: #{@csv_file.content_type}"
    end
  end

  def import_alunos
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
    updated = 0
    failed = []

    rows.each_with_index do |row, index|
      result = process_row(row, index + 2) # +2 pois começa na linha 2 (header é linha 1)
      
      if result[:success]
        created += result[:created]
        updated += result[:updated]
      else
        failed << result[:error]
      end
    end

    message = build_message(created, updated, failed)
    
    { 
      success: failed.empty?, 
      message: message,
      created: created,
      updated: updated
    }
  end

  def process_row(row, line_number)
    ra = row['ra']&.to_s&.strip
    nome = row['nome']&.to_s&.strip
    email = row['email']&.to_s&.strip

    if ra.blank? || nome.blank? || email.blank?
      return { 
        success: false, 
        error: "Linha #{line_number}: RA, Nome e Email são obrigatórios"
      }
    end

    aluno = @usuario.alunos.find_or_initialize_by(ra: ra)
    
    if aluno.new_record?
      aluno.assign_attributes(nome: nome, email: email)
      
      if aluno.save
        return { success: true, created: 1, updated: 0 }
      else
        return { 
          success: false, 
          error: "Linha #{line_number} (#{ra}): #{aluno.errors.full_messages.join(', ')}"
        }
      end
    else
      aluno.update(nome: nome, email: email)
      return { success: true, created: 0, updated: 1 }
    end
  end

  def build_message(created, updated, failed)
    message = "Importação concluída: "
    message += "#{created} alunos criados" if created > 0
    message += ", " if created > 0 && updated > 0
    message += "#{updated} alunos atualizados" if updated > 0
    
    if failed.any?
      message += "\n\nErros encontrados:\n"
      message += failed.join("\n")
    end

    message
  end
end
