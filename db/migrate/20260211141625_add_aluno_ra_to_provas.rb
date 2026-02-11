class AddAlunoRaToProvas < ActiveRecord::Migration[8.0]
  def change
    add_column :provas, :aluno_ra, :string

    add_index :provas, :aluno_ra
    add_foreign_key :provas, :alunos, column: :aluno_ra, primary_key: :ra
  end
end
