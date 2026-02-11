# frozen_string_literal: true

class ForceRenameQuestaosToQuestoes < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:questaos)
    return if table_exists?(:questoes)

    rename_table :questaos, :questoes
  end

  def down
    return unless table_exists?(:questoes)
    return if table_exists?(:questaos)

    rename_table :questoes, :questaos
  end
end
