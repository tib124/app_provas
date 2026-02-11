class AddRespostasToQuestoes < ActiveRecord::Migration[8.0]
  def change
    add_column :questoes, :respostas, :text
    add_column :questoes, :resposta_colocada, :text
  end
end
