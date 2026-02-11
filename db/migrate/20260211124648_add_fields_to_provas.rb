# frozen_string_literal: true

class AddFieldsToProvas < ActiveRecord::Migration[8.0]
  def change
    add_reference :provas, :usuario, foreign_key: { to_table: :users }, index: true
    add_column :provas, :titulo, :string
    add_column :provas, :data_criacao, :date, default: -> { "CURRENT_DATE" }, null: false

    add_index :provas, [ :usuario_id, :data_criacao ]

    reversible do |dir|
      dir.up do
        result = execute("SELECT COUNT(*) AS count FROM provas")
        count = result.first["count"].to_i
        if count.positive?
          raise ActiveRecord::IrreversibleMigration,
                "Existem provas antigas sem usuario_id/titulo. Faça um backfill antes de aplicar NOT NULL."
        end

        change_column_null :provas, :usuario_id, false
        change_column_null :provas, :titulo, false
      end
    end
  end
end
