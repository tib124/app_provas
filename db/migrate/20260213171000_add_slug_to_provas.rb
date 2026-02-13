# frozen_string_literal: true

class AddSlugToProvas < ActiveRecord::Migration[8.0]
  def change
    add_column :provas, :slug, :string

    reversible do |dir|
      dir.up do
        # Gerar slugs para provas existentes
        Prova.find_each do |prova|
          prova.update_column(:slug, SecureRandom.hex(6))
        end

        # Tornar o slug NOT NULL após preencher valores
        change_column_null :provas, :slug, false
        add_index :provas, :slug, unique: true
      end

      dir.down do
        remove_index :provas, :slug
        remove_column :provas, :slug
      end
    end
  end
end
