# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    association :user
    association :client, factory: :contact

    service_description { Faker::Lorem.sentence }
    amount_cents        { Faker::Number.between(from: 100, to: 100_000) }
    status              { :draft }
  end
end
