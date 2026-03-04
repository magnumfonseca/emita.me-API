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

ActiveRecord::Schema[8.1].define(version: 2026_03_04_133539) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cnpj"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_contacts_on_user_id"
  end

  create_table "invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_key"
    t.integer "amount_cents", null: false
    t.decimal "cbs_rate", precision: 5, scale: 4
    t.integer "cbs_value_cents"
    t.uuid "client_id", null: false
    t.text "compressed_dps_xml"
    t.text "compressed_nfse_xml"
    t.string "consultation_url"
    t.datetime "created_at", null: false
    t.text "dps_xml"
    t.text "error_message"
    t.decimal "ibs_rate", precision: 5, scale: 4
    t.integer "ibs_value_cents"
    t.datetime "issued_at"
    t.text "nfse_xml"
    t.string "pdf_url"
    t.jsonb "raw_response"
    t.text "service_description", null: false
    t.text "signed_dps_xml"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["access_key"], name: "index_invoices_on_access_key"
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cpf", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "trust_level", null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
  end

  add_foreign_key "contacts", "users"
  add_foreign_key "invoices", "contacts", column: "client_id"
  add_foreign_key "invoices", "users"
end
