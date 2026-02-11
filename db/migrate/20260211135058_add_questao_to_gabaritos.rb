# frozen_string_literal: true

class AddQuestaoToGabaritos < ActiveRecord::Migration[8.0]
  def change
    add_reference :gabaritos, :questao, null: true, foreign_key: true, index: { unique: true }
  end
end
