# frozen_string_literal: true

class CreateGabaritos < ActiveRecord::Migration[8.0]
  def change
    create_table :gabaritos do |t|
      t.references :prova, null: false, foreign_key: true
      t.string :tipo, null: false
      t.text :enunciado, null: false
      t.text :resposta_correta, null: false
      t.decimal :peso, null: false, default: 1.0, precision: 8, scale: 2

      t.timestamps null: false
    end

    add_index :gabaritos, [ :prova_id, :tipo ]
  end
end
