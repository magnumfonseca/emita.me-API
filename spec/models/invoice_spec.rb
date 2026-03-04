# frozen_string_literal: true

require "rails_helper"

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
  it { is_expected.to define_enum_for(:status).backed_by_column_of_type(:string).with_values(draft: "draft", pending: "pending", issued: "issued", error: "error") }

  # ── Cross-tenant validation ───────────────────────────────────────────────────
  context "when client belongs to a different user" do
    subject(:invoice) { build(:invoice, user: user, client: build(:contact, user: create(:user))) }

    it "is invalid" do
      expect(invoice).not_to be_valid
      expect(invoice.errors[:client]).to be_present
    end
  end

  # ── Default status ────────────────────────────────────────────────────────────
  context "when status is not set" do
    subject(:invoice) { Invoice.new }

    it "defaults to draft" do
      expect(invoice.status).to eq("draft")
    end
  end
end
