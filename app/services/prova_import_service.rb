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

    provas_criadas = 0
    questoes_criadas = 0
    gabaritos_criados = 0
    failed = []

    # Agrupar linhas por prova
    provas_agrupadas = agrupar_por_prova(rows)

    provas_agrupadas.each_with_index do |(prova_key, questoes_rows), idx|
      result = process_prova(prova_key, questoes_rows, idx + 2)
      
      if result[:success]
        provas_criadas += result[:provas_criadas]
        questoes_criadas += result[:questoes_criadas]
        gabaritos_criados += result[:gabaritos_criados]
      else
        failed << result[:error]
      end
    end

    message = build_message(provas_criadas, questoes_criadas, gabaritos_criados, failed)
    
    { 
      success: failed.empty?, 
      message: message
    }
  end

  def agrupar_por_prova(rows)
    grouped = {}
    
    rows.each do |row|
      titulo = row['prova_titulo']&.to_s&.strip
      aluno_ra = row['aluno_ra']&.to_s&.strip&.upcase
      data_criacao = row['data_criacao']&.to_s&.strip
      
      key = "#{titulo}|#{aluno_ra}|#{data_criacao}"
      grouped[key] ||= []
      grouped[key] << row
    end
    
    grouped
  end

  def process_prova(prova_key, questoes_rows, line_number)
    titulo, aluno_ra, data_criacao_str = prova_key.split('|')
    titulo = titulo&.strip
    aluno_ra = aluno_ra&.strip.presence
    data_criacao_str = data_criacao_str&.strip.presence

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
          error: "Linha #{line_number}: Aluno com RA '#{aluno_ra}' não encontrado"
        }
      end
    end

    # Parsear data
    data_criacao = if data_criacao_str.present?
                     begin
                       Date.parse(data_criacao_str)
                     rescue StandardError
                       Date.current
                     end
                   else
                     Date.current
                   end

    # Criar prova com atributos iniciais e depois salvar
    prova_attrs = { titulo: titulo, data_criacao: data_criacao }
    prova_attrs[:aluno_ra] = aluno_ra if aluno_ra.present?
    
    prova = @usuario.provas.find_by(titulo: titulo, data_criacao: data_criacao)
    
    unless prova
      prova = @usuario.provas.new(prova_attrs)
      prova.skip_validations = true
      unless prova.save
        return {
          success: false,
          error: "Linha #{line_number}: Erro ao criar prova - #{prova.errors.full_messages.join(', ')}"
        }
      end
    end

    questoes_criadas = 0
    gabaritos_criados = 0
    
    questoes_rows.each do |row|
      result = process_questao_e_gabarito(prova, row, line_number)
      
      if result[:success]
        questoes_criadas += result[:questoes_criadas]
        gabaritos_criados += result[:gabaritos_criados]
      end
    end

    { 
      success: true,
      provas_criadas: 1,
      questoes_criadas: questoes_criadas,
      gabaritos_criados: gabaritos_criados
    }
  end

  def process_questao_e_gabarito(prova, row, line_number)
    enunciado = row['questao_enunciado']&.to_s&.strip
    tipo = row['questao_tipo']&.to_s&.strip&.downcase
    peso_str = row['questao_peso']&.to_s&.strip
    respostas = row['questao_respostas']&.to_s&.strip
    resposta_colocada = row['resposta_colocada']&.to_s&.strip
    resposta_correta = row['resposta_correta']&.to_s&.strip

    # Se não tiver enunciado, pular
    return { success: true, questoes_criadas: 0, gabaritos_criados: 0 } if enunciado.blank?

    peso = peso_str.present? ? peso_str.to_f : 1.0

    questao = prova.questoes.create(
      tipo: tipo.presence || 'multipla_escolha',
      enunciado: enunciado,
      peso: peso,
      respostas: respostas,
      resposta_colocada: resposta_colocada
    )

    if questao.persisted? && resposta_correta.present?
      gabarito = questao.create_gabarito(
        prova_id: prova.id,
        resposta_correta: resposta_correta
      )
      
      return { 
        success: true, 
        questoes_criadas: 1,
        gabaritos_criados: gabarito.persisted? ? 1 : 0
      }
    end

    { success: true, questoes_criadas: questao.persisted? ? 1 : 0, gabaritos_criados: 0 }
  end

  def build_message(provas_criadas, questoes_criadas, gabaritos_criados, failed)
    message = "Importação concluída:\n"
    message += "- #{provas_criadas} prova(s) criada(s)\n"
    message += "- #{questoes_criadas} questão(ões) criada(s)\n"
    message += "- #{gabaritos_criados} gabarito(s) criado(s)"
    
    if failed.any?
      error_count = failed.length
      displayed_errors = failed.first(5)
      
      message += "\n\nErros encontrados (#{error_count} total):\n"
      message += displayed_errors.join("\n")
      message += "\n... e mais #{error_count - 5} erro(s)" if error_count > 5
    end

    message
  end
end

