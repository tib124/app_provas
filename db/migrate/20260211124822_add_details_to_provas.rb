# frozen_string_literal: true

class AddDetailsToProvas < ActiveRecord::Migration[8.0]
  def change
    add_reference :provas, :usuario, null: false, foreign_key: { to_table: :users }, index: true
    add_column :provas, :titulo, :string, null: false
    add_column :provas, :data_criacao, :date, null: false, default: -> { "CURRENT_DATE" }

    add_index :provas, [ :usuario_id, :data_criacao ]
  end
end
