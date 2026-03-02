# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :user

  scope :by_name, ->(name) { where("name ILIKE ?", "%#{sanitize_sql_like(name)}%") if name.present? }
  scope :by_cpf,  ->(cpf)  { where(cpf: cpf.gsub(/\D/, "")) if cpf.present? }
  scope :by_cnpj, ->(cnpj) { where(cnpj: cnpj.gsub(/\D/, "")) if cnpj.present? }

  before_validation :normalize_fields

  validates :user, presence: true
  validates :name, presence: true
  validates :cpf,     cpf:  true, allow_blank: true
  validates :cnpj,    cnpj: true, allow_blank: true
  validates :email,   format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone,   format: { with: /\A\d{2}9\d{8}\z/, message: "deve conter DDD + 9 + 8 dígitos" },
                      allow_blank: true

  validate :cpf_or_cnpj_present
  validate :phone_or_email_present

  private

  def normalize_fields
    self.cpf   = strip_non_digits(cpf)
    self.cnpj  = strip_non_digits(cnpj)
    self.phone = strip_non_digits(phone)
  end

  def strip_non_digits(value)
    value&.gsub(/\D/, "")
  end

  def cpf_or_cnpj_present
    errors.add(:base, "CPF ou CNPJ deve ser informado") unless cpf.present? || cnpj.present?
  end

  def phone_or_email_present
    errors.add(:base, "Telefone ou e-mail deve ser informado") unless phone.present? || email.present?
  end
end
