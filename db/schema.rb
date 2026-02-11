# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_11_142939) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alunos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ra", null: false
    t.string "nome", null: false
    t.string "email", null: false
    t.bigint "usuario_id", null: false
    t.index ["email"], name: "index_alunos_on_email"
    t.index ["ra"], name: "index_alunos_on_ra", unique: true
    t.index ["usuario_id"], name: "index_alunos_on_usuario_id"
  end

  create_table "gabaritos", force: :cascade do |t|
    t.bigint "prova_id", null: false
    t.string "tipo"
    t.text "enunciado"
    t.text "resposta_correta"
    t.decimal "peso"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "questao_id"
    t.index ["prova_id"], name: "index_gabaritos_on_prova_id"
    t.index ["questao_id"], name: "index_gabaritos_on_questao_id", unique: true
  end

  create_table "provas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "usuario_id", null: false
    t.string "titulo", null: false
    t.date "data_criacao", default: -> { "CURRENT_DATE" }, null: false
    t.string "aluno_ra"
    t.index ["aluno_ra"], name: "index_provas_on_aluno_ra"
    t.index ["usuario_id", "data_criacao"], name: "index_provas_on_usuario_id_and_data_criacao"
    t.index ["usuario_id"], name: "index_provas_on_usuario_id"
  end

  create_table "questoes", id: :bigint, default: -> { "nextval('questaos_id_seq'::regclass)" }, force: :cascade do |t|
    t.bigint "prova_id", null: false
    t.string "tipo"
    t.text "enunciado"
    t.decimal "peso"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "respostas"
    t.text "resposta_colocada"
    t.index ["prova_id"], name: "index_questaos_on_prova_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "alunos", "users", column: "usuario_id"
  add_foreign_key "gabaritos", "provas"
  add_foreign_key "gabaritos", "questoes"
  add_foreign_key "provas", "alunos", column: "aluno_ra", primary_key: "ra"
  add_foreign_key "provas", "users", column: "usuario_id"
  add_foreign_key "questoes", "provas"
end
