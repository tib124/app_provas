# frozen_string_literal: true

class RenameQuestaosToQuestoes < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:questoes)
    return unless table_exists?(:questaos)

    rename_table :questaos, :questoes
  end
end
