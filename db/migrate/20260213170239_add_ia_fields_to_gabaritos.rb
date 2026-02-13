class AddIaFieldsToGabaritos < ActiveRecord::Migration[8.0]
  def change
    add_column :gabaritos, :avaliacao_ia, :string
    add_column :gabaritos, :justificativa_ia, :text
  end
end
