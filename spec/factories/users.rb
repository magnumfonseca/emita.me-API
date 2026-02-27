# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    cpf         { Faker::Number.number(digits: 11).to_s }
    name        { Faker::Name.name }
    email       { Faker::Internet.email }
    trust_level { :prata }
  end
end
