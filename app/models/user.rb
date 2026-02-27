# frozen_string_literal: true

class User < ApplicationRecord
  enum :trust_level, { prata: "prata", ouro: "ouro" }

  validates :cpf,         presence: true, uniqueness: true
  validates :trust_level, presence: true
end
