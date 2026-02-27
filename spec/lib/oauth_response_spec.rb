# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OauthResponse do
  let(:header) { "eyJhbGciOiJIUzI1NiJ9" }

  let(:prata_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "12345678900", name: "Joao da Silva", email: "joao@example.com",
        confiabilidade: { nivel: "prata" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:ouro_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "12345678900", name: "Joao da Silva", email: "joao@example.com",
        confiabilidade: { nivel: "ouro" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:bronze_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "98765432100", name: "Maria Bronze", email: "maria@example.com",
        confiabilidade: { nivel: "bronze" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:no_cpf_token) do
    payload = Base64.urlsafe_encode64(
      { sub: nil, name: "No CPF", email: "nocpf@example.com",
        confiabilidade: { nivel: "prata" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  describe "#cpf" do
    it "extracts sub from JWT payload" do
      expect(described_class.new(id_token: prata_token).cpf).to eq("12345678900")
    end
  end

  describe "#name" do
    it "extracts name from JWT payload" do
      expect(described_class.new(id_token: prata_token).name).to eq("Joao da Silva")
    end
  end

  describe "#email" do
    it "extracts email from JWT payload" do
      expect(described_class.new(id_token: prata_token).email).to eq("joao@example.com")
    end
  end

  describe "#trust_level" do
    it "extracts nivel from confiabilidade" do
      expect(described_class.new(id_token: prata_token).trust_level).to eq("prata")
    end
  end

  describe "with a malformed id_token" do
    it "raises Errors::InvalidToken when token is nil" do
      expect { described_class.new(id_token: nil) }.to raise_error(Errors::InvalidToken)
    end

    it "raises Errors::InvalidToken when token has wrong number of parts" do
      expect { described_class.new(id_token: "only.two") }.to raise_error(Errors::InvalidToken)
    end

    it "raises Errors::InvalidToken when payload segment is not valid base64" do
      expect { described_class.new(id_token: "header.!!!invalid!!!.signature") }.to raise_error(Errors::InvalidToken)
    end

    it "raises Errors::InvalidToken when decoded payload is not valid JSON" do
      invalid_json = Base64.urlsafe_encode64("not-valid-json", padding: false)
      expect { described_class.new(id_token: "header.#{invalid_json}.signature") }.to raise_error(Errors::InvalidToken)
    end
  end

  describe "#valid?" do
    it "returns true when trust level is prata" do
      expect(described_class.new(id_token: prata_token)).to be_valid
    end

    it "returns true when trust level is ouro" do
      expect(described_class.new(id_token: ouro_token)).to be_valid
    end

    it "returns false when trust level is bronze" do
      expect(described_class.new(id_token: bronze_token)).not_to be_valid
    end

    it "returns false when cpf is nil" do
      expect(described_class.new(id_token: no_cpf_token)).not_to be_valid
    end
  end
end
