# frozen_string_literal: true

class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if valid_cpf?(value)

    record.errors.add(attribute, :invalid, message: options[:message] || "não é um CPF válido")
  end

  private

  def valid_cpf?(cpf)
    digits = cpf.to_s.gsub(/\D/, "")
    return false unless digits.length == 11
    return false if digits.chars.uniq.length == 1

    first_digit_valid?(digits) && second_digit_valid?(digits)
  end

  def first_digit_valid?(digits)
    check_digit(weighted_sum(digits[0..8], 10.downto(2).to_a)) == digits[9].to_i
  end

  def second_digit_valid?(digits)
    check_digit(weighted_sum(digits[0..9], 11.downto(2).to_a)) == digits[10].to_i
  end

  def weighted_sum(digits_slice, weights)
    digits_slice.chars.zip(weights).sum { |d, w| d.to_i * w }
  end

  def check_digit(sum)
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end
end
