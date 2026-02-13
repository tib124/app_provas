# frozen_string_literal: true

# Configura a API key do Groq para correção de questões dissertativas com IA.
#
# Para configurar, defina a variável de ambiente GROQ_API_KEY:
#   export GROQ_API_KEY="sua-chave-aqui"
#
# Obtenha sua chave gratuita em: https://console.groq.com/keys
#
Rails.application.config.groq_api_key = ENV["GROQ_API_KEY"]
