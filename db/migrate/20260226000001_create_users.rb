# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string  :cpf,         null: false
      t.string  :name
      t.string  :email
      t.string :trust_level, null: false

      t.timestamps
    end

    add_index :users, :cpf, unique: true
  end
end
