# frozen_string_literal: true

class CreateEstablishments < ActiveRecord::Migration[8.1]
  def change
    create_table :establishments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :cnpj,             null: false
      t.string  :razao_social,     null: false
      t.string  :nome_fantasia
      t.string  :municipio_codigo
      t.string  :uf
      t.text    :perfis, array: true, default: []
      t.boolean :authorized, null: false, default: false
      t.timestamps
    end
    add_index :establishments, [ :user_id, :cnpj ], unique: true
  end
end
