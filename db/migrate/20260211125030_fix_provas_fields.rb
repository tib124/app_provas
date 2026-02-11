# frozen_string_literal: true

class FixProvasFields < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:provas, :usuario_id)
      add_reference :provas, :usuario, null: false, foreign_key: { to_table: :users }, index: true
    end

    unless column_exists?(:provas, :titulo)
      add_column :provas, :titulo, :string, null: false
    end

    unless column_exists?(:provas, :data_criacao)
      add_column :provas, :data_criacao, :date, null: false, default: -> { "CURRENT_DATE" }
    end

    add_index :provas, [ :usuario_id, :data_criacao ] unless index_exists?(:provas, [ :usuario_id, :data_criacao ])
  end
end
