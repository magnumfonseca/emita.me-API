# frozen_string_literal: true

class User < ApplicationRecord
  enum :trust_level, prata: "prata", ouro: "ouro"

  has_many :contacts,       dependent: :destroy
  has_many :establishments, dependent: :destroy

  validates :cpf,         presence: true, uniqueness: true
  validates :trust_level, presence: true
end
