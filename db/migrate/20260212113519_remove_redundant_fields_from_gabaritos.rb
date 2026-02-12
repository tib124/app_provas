class RemoveRedundantFieldsFromGabaritos < ActiveRecord::Migration[8.0]
  def change
    remove_column :gabaritos, :tipo, :string
    remove_column :gabaritos, :enunciado, :text
    remove_column :gabaritos, :peso, :decimal
  end
end
