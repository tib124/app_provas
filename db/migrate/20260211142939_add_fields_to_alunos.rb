class AddFieldsToAlunos < ActiveRecord::Migration[8.0]
  def up
    execute "TRUNCATE TABLE alunos RESTART IDENTITY CASCADE" if table_exists?(:alunos)

    add_column :alunos, :ra, :string, null: false
    add_column :alunos, :nome, :string, null: false
    add_column :alunos, :email, :string, null: false
    add_reference :alunos, :usuario, null: false, foreign_key: { to_table: :users }

    add_index :alunos, :ra, unique: true unless index_exists?(:alunos, :ra, unique: true)
    add_index :alunos, :email unless index_exists?(:alunos, :email)

    add_index :provas, :aluno_ra unless index_exists?(:provas, :aluno_ra)
    add_foreign_key :provas, :alunos, column: :aluno_ra, primary_key: :ra unless foreign_key_exists?(:provas, :alunos, column: :aluno_ra)
  end

  def down
    remove_foreign_key :provas, column: :aluno_ra if foreign_key_exists?(:provas, :alunos, column: :aluno_ra)
    remove_index :provas, :aluno_ra if index_exists?(:provas, :aluno_ra)

    remove_index :alunos, :email if index_exists?(:alunos, :email)
    remove_index :alunos, :ra if index_exists?(:alunos, :ra)

    remove_reference :alunos, :usuario if column_exists?(:alunos, :usuario_id)
    remove_column :alunos, :email if column_exists?(:alunos, :email)
    remove_column :alunos, :nome if column_exists?(:alunos, :nome)
    remove_column :alunos, :ra if column_exists?(:alunos, :ra)
  end
end
