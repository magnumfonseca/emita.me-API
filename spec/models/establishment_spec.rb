# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Establishment, type: :model do
  subject { build(:establishment) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:cnpj) }
    it { is_expected.to validate_presence_of(:razao_social) }
    it { is_expected.to validate_uniqueness_of(:cnpj).scoped_to(:user_id).ignoring_case_sensitivity }
  end

  describe "before_save :set_authorized" do
    it "sets authorized true when perfis includes EMISSOR" do
      e = build(:establishment, perfis: [ "EMISSOR", "CONSULTA" ])
      e.save!
      expect(e.authorized).to be true
    end

    it "sets authorized false when perfis does not include EMISSOR" do
      e = build(:establishment, :consulta_only)
      e.save!
      expect(e.authorized).to be false
    end

    it "updates authorized on re-save when perfis change" do
      e = create(:establishment, perfis: [ "EMISSOR" ])
      e.update!(perfis: [ "CONSULTA" ])
      expect(e.reload.authorized).to be false
    end
  end
end
