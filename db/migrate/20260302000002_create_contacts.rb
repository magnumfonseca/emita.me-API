# frozen_string_literal: true

class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string     :name,  null: false
      t.string     :cpf
      t.string     :cnpj
      t.string     :phone
      t.string     :email
      t.references :user,  null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
