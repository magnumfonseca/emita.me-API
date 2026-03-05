# frozen_string_literal: true

class Establishment < ApplicationRecord
  belongs_to :user

  validates :cnpj, presence: true, cnpj: true, uniqueness: { scope: :user_id }
  validates :razao_social, presence: true

  before_save :set_authorized

  private

  def set_authorized
    self.authorized = Array(perfis).include?("EMISSOR")
  end
end
