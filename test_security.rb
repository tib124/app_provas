#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts "=" * 60
puts "TESTES DE SEGURANÇA - ROTAS DE PROVAS"
puts "=" * 60

# Setup
user1 = User.find(1)
user2 = User.find(2)
prova_user1 = Prova.where(usuario_id: 1).first
prova_user2 = Prova.where(usuario_id: 2).first

puts "\n📋 Dados de teste:"
puts "  User 1: #{user1.email}"
puts "  User 2: #{user2.email}"
puts "  Prova User 1: #{prova_user1&.titulo} (slug: #{prova_user1&.slug})"
puts "  Prova User 2: #{prova_user2&.titulo} (slug: #{prova_user2&.slug})"

# Test 1: Isolamento por usuário (Model Level)
puts "\n" + "=" * 60
puts "TESTE 1: Isolamento por usuário (Model Level)"
puts "=" * 60

puts "\n1.1 - User 1 tentando acessar prova de User 1 (slug: #{prova_user1.slug}):"
resultado = user1.provas.find_by(slug: prova_user1.slug)
if resultado
  puts "✅ SUCESSO: User 1 acessa prova de User 1"
else
  puts "❌ ERRO: User 1 não consegue acessar prova de User 1"
end

if prova_user2
  puts "\n1.2 - User 1 tentando acessar prova de User 2 (slug: #{prova_user2.slug}):"
  resultado = user1.provas.find_by(slug: prova_user2.slug)
  if resultado.nil?
    puts "✅ BLOQUEADO: User 1 NÃO consegue acessar prova de User 2"
  else
    puts "❌ VULNERABILIDADE: User 1 consegue acessar prova de User 2!"
  end
end

puts "\n1.3 - User 1 tentando acessar slug inválido:"
resultado = user1.provas.find_by(slug: "slug_invalido_123")
if resultado.nil?
  puts "✅ BLOQUEADO: Slug inválido retorna nil"
else
  puts "❌ ERRO: Slug inválido retornou dados"
end

# Test 2: SQL Injection
puts "\n" + "=" * 60
puts "TESTE 2: Proteção contra SQL Injection"
puts "=" * 60

malicious_slug = "'; DROP TABLE provas; --"
puts "Slug malicioso testado: #{malicious_slug}"
resultado = Prova.where(usuario_id: 1).find_by(slug: malicious_slug)
puts resultado.nil? ? "✅ SQL Injection bloqueada" : "❌ Possível vulnerabilidade!"

# Test 3: Verificar autenticação
puts "\n" + "=" * 60
puts "TESTE 3: Verificar autenticação no controller"
puts "=" * 60

source = File.read("app/controllers/provas_controller.rb")
puts "✅ Autenticação encontrada" if source.include?("authenticate_user!")
puts "✅ Slug lookup encontrado" if source.include?('find_by!(slug:')
puts "✅ Rescue para NotFound encontrado" if source.include?('RecordNotFound')

# Test 4: Verificar schema
puts "\n" + "=" * 60
puts "TESTE 4: Verificar schema do banco"
puts "=" * 60

slug_column = Prova.columns.find { |c| c.name == "slug" }
puts "✅ Coluna 'slug' existe" if slug_column
puts "✅ Slug é NOT NULL" if slug_column && !slug_column.null

has_unique_index = Prova.connection.indexes("provas").any? { |i| i.name.include?("slug") && i.unique }
puts "✅ Slug tem índice único" if has_unique_index

# Test 5: Verificar to_param
puts "\n" + "=" * 60
puts "TESTE 5: Verificar método to_param"
puts "=" * 60

prova = Prova.first
puts "Prova ID: #{prova.id}"
puts "Prova Slug: #{prova.slug}"
puts "Prova to_param: #{prova.to_param}"
if prova.to_param == prova.slug
  puts "✅ to_param retorna slug corretamente"
else
  puts "❌ to_param não retorna slug"
end
