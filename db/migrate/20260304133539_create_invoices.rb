# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Identification
      t.references :user,   null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: { to_table: :contacts }, type: :uuid

      t.text    :service_description, null: false
      t.integer :amount_cents,        null: false

      # Tax fields (optional, calculated later)
      t.decimal :ibs_rate,         precision: 5, scale: 4
      t.decimal :cbs_rate,         precision: 5, scale: 4
      t.integer :ibs_value_cents
      t.integer :cbs_value_cents

      # DPS (request)
      t.text :dps_xml
      t.text :signed_dps_xml
      t.text :compressed_dps_xml

      # NFS-e (response)
      t.string :access_key
      t.text   :nfse_xml
      t.text   :compressed_nfse_xml

      # URLs
      t.string :consultation_url
      t.string :pdf_url

      # Status tracking
      t.string   :status,        null: false, default: "draft"
      t.text     :error_message
      t.datetime :issued_at

      # Metadata
      t.jsonb :raw_response

      t.timestamps
    end

    add_index :invoices, :status
    add_index :invoices, :access_key
  end
end
