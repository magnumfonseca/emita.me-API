# frozen_string_literal: true

class User < ApplicationRecord
  enum :trust_level, %w[prata ouro]

  validates :cpf,         presence: true, uniqueness: true
  validates :trust_level, presence: true
end
