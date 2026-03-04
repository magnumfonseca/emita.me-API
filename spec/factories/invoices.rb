# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    association :user

    service_description { Faker::Lorem.sentence }
    amount_cents        { Faker::Number.between(from: 100, to: 100_000) }

    after(:build) do |invoice|
      invoice.client ||= build(:contact, user: invoice.user)
    end
  end
end
