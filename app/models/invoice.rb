# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :client, class_name: "Contact"

  enum :status, { draft: "draft", pending: "pending", issued: "issued", error: "error" }

  validates :service_description, presence: true
  validates :amount_cents,        presence: true,
                                  numericality: { greater_than: 0 }
end
