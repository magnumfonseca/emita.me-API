# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    association :user
    name  { Faker::Name.name }
    cpf   { '01234567890' }
    cnpj  { nil }
    phone { '11987654321' }
    email { Faker::Internet.email }

    trait :with_cnpj do
      cpf  { nil }
      cnpj { '00394460005887' }
    end
  end
end
