# frozen_string_literal: true

class CnpjValidator < ActiveModel::EachValidator
  FIRST_WEIGHTS  = [ 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze
  SECOND_WEIGHTS = [ 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze

  def validate_each(record, attribute, value)
    return if value.blank?
    return if valid_cnpj?(value)

    record.errors.add(attribute, :invalid, message: options[:message] || "não é um CNPJ válido")
  end

  private

  def valid_cnpj?(cnpj)
    digits = cnpj.to_s.gsub(/\D/, "")
    return false unless digits.length == 14
    return false if digits.chars.uniq.length == 1

    first_digit_valid?(digits) && second_digit_valid?(digits)
  end

  def first_digit_valid?(digits)
    check_digit(weighted_sum(digits[0..11], FIRST_WEIGHTS)) == digits[12].to_i
  end

  def second_digit_valid?(digits)
    check_digit(weighted_sum(digits[0..12], SECOND_WEIGHTS)) == digits[13].to_i
  end

  def weighted_sum(digits_slice, weights)
    digits_slice.chars.zip(weights).sum { |d, w| d.to_i * w }
  end

  def check_digit(sum)
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end
end
