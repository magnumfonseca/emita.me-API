# Plan: Invoice Model & Migration (NFS-e National)

## Context
The project needs to store fiscal data for Brazilian NFS-e National invoices. This requires a new `Invoice` model covering the full lifecycle: draft creation → DPS XML → signed/compressed XML → API submission → NFS-e XML storage → PDF/consultation URL generation.

---

## Key Constraints from Exploration

- **UUID PKs everywhere**: all tables use `id: :uuid, default: -> { "gen_random_uuid()" }` with pgcrypto
- **"client" = Contact**: the task says `belongs_to :client`, but the model is `Contact` → use `belongs_to :client, class_name: "Contact"`
- **TDD first**: spec before implementation
- **shoulda-matchers**: used for association and presence validations (one-liners)
- **Enum pattern**: `enum :status, draft: "draft", pending: "pending", ...` (Rails 8 style)

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `db/migrate/<timestamp>_create_invoices.rb` | Create |
| `app/models/invoice.rb` | Create |
| `spec/models/invoice_spec.rb` | Create (TDD first) |
| `spec/factories/invoices.rb` | Create |

---

## Step-by-Step Implementation

### Step 1 — Write the model spec (TDD first)

**`spec/models/invoice_spec.rb`**

```ruby
# frozen_string_literal: true

RSpec.describe Invoice, type: :model do
  let(:user)    { create(:user) }
  let(:contact) { create(:contact, user: user) }
  subject(:invoice) { build(:invoice, user: user, client: contact) }

  # ── Associations ─────────────────────────────────────────────────────────────
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:client).class_name("Contact") }

  # ── Presence validations ──────────────────────────────────────────────────────
  it { is_expected.to validate_presence_of(:service_description) }
  it { is_expected.to validate_presence_of(:amount_cents) }

  # ── Numericality validations ──────────────────────────────────────────────────
  it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }

  # ── Enum ──────────────────────────────────────────────────────────────────────
  it { is_expected.to define_enum_for(:status).with_values(draft: "draft", pending: "pending", issued: "issued", error: "error") }

  # ── Default status ────────────────────────────────────────────────────────────
  context "when status is not set" do
    subject(:invoice) { build(:invoice, user: user, client: contact, status: nil) }

    it "defaults to draft" do
      expect(invoice.status).to eq("draft")
    end
  end
end
```

### Step 2 — Create the factory

**`spec/factories/invoices.rb`**

```ruby
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
```

> Note: `association :client, factory: :contact` maps the `client` association to the `contacts` factory.

### Step 3 — Create the migration

```bash
bin/rails generate migration CreateInvoices
```

**`db/migrate/<timestamp>_create_invoices.rb`**

```ruby
class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Identification
      t.references :user,   null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: { to_table: :contacts }, type: :uuid

      t.text    :service_description, null: false
      t.integer :amount_cents,        null: false

      # Tax fields (optional, calculated later)
      t.decimal :ibs_rate,         precision: 5, scale: 4
      t.decimal :cbs_rate,         precision: 5, scale: 4
      t.integer :ibs_value_cents
      t.integer :cbs_value_cents

      # DPS (request)
      t.text :dps_xml
      t.text :signed_dps_xml
      t.text :compressed_dps_xml

      # NFS-e (response)
      t.string :access_key
      t.text   :nfse_xml
      t.text   :compressed_nfse_xml

      # URLs
      t.string :consultation_url
      t.string :pdf_url

      # Status tracking
      t.string   :status,        null: false, default: "draft"
      t.text     :error_message
      t.datetime :issued_at

      # Metadata
      t.jsonb :raw_response

      t.timestamps
    end

    add_index :invoices, :status
    add_index :invoices, :access_key
  end
end
```

### Step 4 — Create the model

**`app/models/invoice.rb`**

```ruby
# frozen_string_literal: true

class Invoice < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :user
  belongs_to :client, class_name: "Contact"

  # ── Enums ────────────────────────────────────────────────────────────────────
  enum :status, { draft: "draft", pending: "pending", issued: "issued", error: "error" }

  # ── Validations ───────────────────────────────────────────────────────────────
  validates :service_description, presence: true
  validates :amount_cents,        presence: true,
                                  numericality: { greater_than: 0 }
end
```

---

## Decision Notes

- **`client` vs `contact`**: kept as `client` (task requirement) using `class_name: "Contact"` — semantically meaningful in the invoice domain
- **`default: "draft"`**: set at DB level (`null: false, default: "draft"`) so records are always valid without explicit status
- **Tax fields optional**: no `null: false` on tax columns — they're populated later in the workflow
- **Indexes**: added on `status` (for filtering) and `access_key` (for lookup after API response)
- **No business logic in model**: XML generation, signing, compression, and API submission will live in service objects (future tasks)

---

## Verification

```bash
# Run migration
bin/rails db:migrate

# Run model spec
bundle exec rspec spec/models/invoice_spec.rb

# Verify schema
bin/rails db:schema:dump
```

All 5 spec assertions should pass after implementing step 4.
