class FixAlunosTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :alunos, if_exists: true

    create_table :alunos, id: :string, primary_key: :ra do |t|
      t.references :usuario, null: false, foreign_key: { to_table: :users }
      t.string :nome, null: false
      t.string :email, null: false
      t.timestamps
    end

    add_index :alunos, :usuario_id unless index_exists?(:alunos, :usuario_id)
    add_index :alunos, :email unless index_exists?(:alunos, :email)

    add_index :provas, :aluno_ra unless index_exists?(:provas, :aluno_ra)
    add_foreign_key :provas, :alunos, column: :aluno_ra, primary_key: :ra unless foreign_key_exists?(:provas, :alunos, column: :aluno_ra)
  end

  def down
    remove_foreign_key :provas, column: :aluno_ra if foreign_key_exists?(:provas, :alunos, column: :aluno_ra)
    remove_index :provas, :aluno_ra if index_exists?(:provas, :aluno_ra)

    drop_table :alunos, if_exists: true
    create_table :alunos do |t|
      t.timestamps
    end
  end
end
