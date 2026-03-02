# Plan: Contact Model (TDD)

## Context

Implement a `Contact` model that belongs to `User`. Contacts hold Brazilian document (CPF/CNPJ) and contact info (phone/email) with algorithmic validation. The task enforces TDD — specs are written first.

**Key codebase facts:**
- Rails 8.1, PostgreSQL + `pgcrypto` (already enabled), UUID primary keys
- `shoulda-matchers` is in the Gemfile but **not configured** — needs a support file
- `spec/models/` is empty (no model specs yet)
- `app/validators/` does not exist yet
- `spec/rails_helper.rb` auto-loads all `spec/support/**/*.rb`

---

## Step-by-Step Plan

### Step 1 — Configure shoulda-matchers
**File:** `spec/support/shoulda_matchers.rb` (NEW)

```ruby
# frozen_string_literal: true

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library        :rails
  end
end
```

---

### Step 2 — Write the model spec (TDD red phase)
**File:** `spec/models/contact_spec.rb` (NEW)

Cover:
- `belong_to(:user)` (shoulda-matchers)
- `validate_presence_of(:name)` (shoulda-matchers)
- `validate_presence_of(:user_id)` (shoulda-matchers)
- CPF OR CNPJ must be present → `errors[:base]` includes `'CPF ou CNPJ deve ser informado'`
- Phone OR Email must be present → `errors[:base]` includes `'Telefone ou e-mail deve ser informado'`
- Valid CPF (`01234567890`) passes; invalid (`11111111111`) fails with `errors[:cpf]`
- Formatted CPF (`012.345.678-90`) passes after normalization
- Valid CNPJ (`00394460005887`) passes; invalid (`11111111111111`) fails with `errors[:cnpj]`
- Formatted CNPJ (`00.394.460/0058-87`) passes after normalization
- Valid email passes; malformed email fails with `errors[:email]`
- Valid phone `11987654321` passes; `(11) 98765-4321` passes after normalization; invalid pattern fails with `errors[:phone]`
- Normalization side-effects: assert that `contact.cpf`, `contact.cnpj`, `contact.phone` contain digits-only after `valid?`

---

### Step 3 — Write the factory
**File:** `spec/factories/contacts.rb` (NEW)

```ruby
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
      cnpj  { '00394460005887' }
    end
  end
end
```

Default factory is valid (cpf + phone + email set, cnpj nil). Tests that need CNPJ-only override with `cpf: nil, cnpj: '00394460005887'`.

---

### Step 4 — Create the migration
**File:** `db/migrate/20260302000002_create_contacts.rb` (NEW)

```ruby
# frozen_string_literal: true

class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string     :name,  null: false
      t.string     :cpf
      t.string     :cnpj
      t.string     :phone
      t.string     :email
      t.references :user,  null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
```

> **Note:** `type: :uuid` on `t.references` is required — users PK is UUID; omitting it causes a PostgreSQL type mismatch. Do NOT call `enable_extension 'pgcrypto'` — already active from users migration.

Run: `bundle exec rails db:migrate`

---

### Step 5 — CPF validator
**File:** `app/validators/cpf_validator.rb` (NEW — also creates `app/validators/` dir)

```ruby
# frozen_string_literal: true

class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if valid_cpf?(value)

    record.errors.add(attribute, :invalid, message: options[:message] || 'não é um CPF válido')
  end

  private

  def valid_cpf?(cpf)
    digits = cpf.to_s.gsub(/\D/, '')
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
```

---

### Step 6 — CNPJ validator
**File:** `app/validators/cnpj_validator.rb` (NEW)

```ruby
# frozen_string_literal: true

class CnpjValidator < ActiveModel::EachValidator
  FIRST_WEIGHTS  = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze
  SECOND_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze

  def validate_each(record, attribute, value)
    return if value.blank?
    return if valid_cnpj?(value)

    record.errors.add(attribute, :invalid, message: options[:message] || 'não é um CNPJ válido')
  end

  private

  def valid_cnpj?(cnpj)
    digits = cnpj.to_s.gsub(/\D/, '')
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
```

---

### Step 7 — Contact model
**File:** `app/models/contact.rb` (NEW)

```ruby
# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :user

  before_validation :normalize_fields

  validates :name,    presence: true
  validates :user_id, presence: true
  validates :cpf,     cpf:  true, allow_blank: true
  validates :cnpj,    cnpj: true, allow_blank: true
  validates :email,   format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone,   format: { with: /\A\d{2}9\d{8}\z/, message: 'deve conter DDD + 9 + 8 dígitos' },
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
    value&.gsub(/\D/, '')
  end

  def cpf_or_cnpj_present
    errors.add(:base, 'CPF ou CNPJ deve ser informado') unless cpf.present? || cnpj.present?
  end

  def phone_or_email_present
    errors.add(:base, 'Telefone ou e-mail deve ser informado') unless phone.present? || email.present?
  end
end
```

---

### Step 8 — Add `has_many` to User model
**File:** `app/models/user.rb` (MODIFY)

Add one line after the `enum` declaration:

```ruby
has_many :contacts, dependent: :destroy
```

---

## Verification

```bash
bundle exec rails db:migrate
bundle exec rspec spec/models/contact_spec.rb
```

All examples should pass (green). Then run the full suite to ensure no regressions:

```bash
bundle exec rspec
```
