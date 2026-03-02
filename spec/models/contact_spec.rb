# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, type: :model do
  let(:user)         { create(:user) }
  subject(:contact) { build(:contact, user: user) }

  # ── Associations ────────────────────────────────────────────────────────────
  it { is_expected.to belong_to(:user) }

  # ── Presence validations ─────────────────────────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }

  # ── CPF or CNPJ must be present ──────────────────────────────────────────────
  context 'when both cpf and cnpj are blank' do
    it 'is invalid and adds a base error' do
      contact.cpf  = nil
      contact.cnpj = nil
      contact.valid?
      expect(contact.errors[:base]).to include('CPF ou CNPJ deve ser informado')
    end
  end

  context 'when only cpf is present' do
    it 'does not add cpf_or_cnpj base error' do
      contact.cpf  = '01234567890'
      contact.cnpj = nil
      contact.valid?
      expect(contact.errors[:base]).not_to include('CPF ou CNPJ deve ser informado')
    end
  end

  context 'when only cnpj is present' do
    it 'does not add cpf_or_cnpj base error' do
      contact.cpf  = nil
      contact.cnpj = '00394460005887'
      contact.valid?
      expect(contact.errors[:base]).not_to include('CPF ou CNPJ deve ser informado')
    end
  end

  # ── Phone or Email must be present ───────────────────────────────────────────
  context 'when both phone and email are blank' do
    it 'is invalid and adds a base error' do
      contact.phone = nil
      contact.email = nil
      contact.valid?
      expect(contact.errors[:base]).to include('Telefone ou e-mail deve ser informado')
    end
  end

  context 'when only phone is present' do
    it 'does not add phone_or_email base error' do
      contact.phone = '11987654321'
      contact.email = nil
      contact.valid?
      expect(contact.errors[:base]).not_to include('Telefone ou e-mail deve ser informado')
    end
  end

  context 'when only email is present' do
    it 'does not add phone_or_email base error' do
      contact.phone = nil
      contact.email = 'valid@example.com'
      contact.valid?
      expect(contact.errors[:base]).not_to include('Telefone ou e-mail deve ser informado')
    end
  end

  # ── CPF validation ───────────────────────────────────────────────────────────
  describe 'CPF validation' do
    context 'with a valid CPF (digits only)' do
      it 'is valid' do
        contact.cpf = '01234567890'
        expect(contact).to be_valid
      end
    end

    context 'with a valid CPF (formatted)' do
      it 'passes after normalization' do
        contact.cpf = '012.345.678-90'
        contact.valid?
        expect(contact.errors[:cpf]).to be_empty
      end
    end

    context 'with an invalid CPF (all same digits)' do
      it 'adds an error on :cpf' do
        contact.cpf = '11111111111'
        contact.valid?
        expect(contact.errors[:cpf]).not_to be_empty
      end
    end
  end

  # ── CNPJ validation ──────────────────────────────────────────────────────────
  describe 'CNPJ validation' do
    context 'with a valid CNPJ (digits only)' do
      it 'is valid' do
        contact.cpf  = nil
        contact.cnpj = '00394460005887'
        expect(contact).to be_valid
      end
    end

    context 'with a valid CNPJ (formatted)' do
      it 'passes after normalization' do
        contact.cpf  = nil
        contact.cnpj = '00.394.460/0058-87'
        contact.valid?
        expect(contact.errors[:cnpj]).to be_empty
      end
    end

    context 'with an invalid CNPJ (all same digits)' do
      it 'adds an error on :cnpj' do
        contact.cpf  = nil
        contact.cnpj = '11111111111111'
        contact.valid?
        expect(contact.errors[:cnpj]).not_to be_empty
      end
    end
  end

  # ── Email validation ─────────────────────────────────────────────────────────
  describe 'email validation' do
    context 'with a valid email' do
      it 'is valid' do
        contact.email = 'user@example.com'
        expect(contact).to be_valid
      end
    end

    context 'with a malformed email' do
      it 'adds an error on :email' do
        contact.email = 'not-an-email'
        contact.valid?
        expect(contact.errors[:email]).not_to be_empty
      end
    end
  end

  # ── Phone validation ─────────────────────────────────────────────────────────
  describe 'phone validation' do
    context 'with a valid phone (digits only)' do
      it 'is valid' do
        contact.phone = '11987654321'
        expect(contact).to be_valid
      end
    end

    context 'with a valid phone (formatted)' do
      it 'passes after normalization' do
        contact.phone = '(11) 98765-4321'
        contact.valid?
        expect(contact.errors[:phone]).to be_empty
      end
    end

    context 'with an invalid phone pattern' do
      it 'adds an error on :phone' do
        contact.phone = '123'
        contact.valid?
        expect(contact.errors[:phone]).not_to be_empty
      end
    end
  end

  # ── Normalization side-effects ────────────────────────────────────────────────
  describe 'field normalization' do
    it 'strips non-digits from cpf before validation' do
      contact.cpf = '012.345.678-90'
      contact.valid?
      expect(contact.cpf).to eq('01234567890')
    end

    it 'strips non-digits from cnpj before validation' do
      contact.cpf  = nil
      contact.cnpj = '00.394.460/0058-87'
      contact.valid?
      expect(contact.cnpj).to eq('00394460005887')
    end

    it 'strips non-digits from phone before validation' do
      contact.phone = '(11) 98765-4321'
      contact.valid?
      expect(contact.phone).to eq('11987654321')
    end
  end
end
