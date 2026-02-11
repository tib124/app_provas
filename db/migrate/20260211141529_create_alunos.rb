class CreateAlunos < ActiveRecord::Migration[8.0]
  def change
      create_table :alunos, id: :string, primary_key: :ra do |t|
        t.references :usuario, null: false, foreign_key: { to_table: :users }
        t.string :nome, null: false
        t.string :email, null: false
        t.timestamps
      end

      add_index :alunos, :usuario_id
      add_index :alunos, :email
  end
end
