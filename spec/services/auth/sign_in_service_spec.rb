# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::SignInService do
  let(:prata_oauth) do
    instance_double(OauthResponse,
      valid?: true, cpf: "12345678900",
      name: "Joao da Silva", email: "joao@example.com",
      trust_level: "prata")
  end
  let(:bronze_oauth) { instance_double(OauthResponse, valid?: false) }
  let(:gateway)      { instance_double(GovBr::OauthGateway) }

  subject(:service)  { described_class.new(code: "auth_code", gateway: gateway) }

  describe "#call" do
    context "when trust level is prata" do
      before { allow(gateway).to receive(:fetch_token).and_return(prata_oauth) }

      it "returns Result.success" do
        expect(service.call).to be_success
      end

      it "creates a new user for the CPF" do
        expect { service.call }.to change(User, :count).by(1)
      end

      it "returns the user in result.data" do
        result = service.call
        expect(result.data).to be_a(User)
        expect(result.data.cpf).to eq("12345678900")
      end

      it "does not create a duplicate when CPF is already registered" do
        create(:user, cpf: "12345678900")
        expect { service.call }.not_to change(User, :count)
      end

      it "returns the existing user when CPF is already registered" do
        existing = create(:user, cpf: "12345678900")
        expect(service.call.data).to eq(existing)
      end

      it "persists trust_level on the user" do
        result = service.call
        expect(result.data.trust_level).to eq("prata")
      end

      it "does not issue a redundant UPDATE when creating a new user" do
        expect_any_instance_of(User).not_to receive(:update!)
        service.call
      end

      it "updates trust_level on re-authentication" do
        existing = create(:user, cpf: "12345678900", trust_level: :prata)
        allow(gateway).to receive(:fetch_token).and_return(
          instance_double(OauthResponse,
            valid?: true, cpf: "12345678900",
            name: "Joao da Silva", email: "joao@example.com",
            trust_level: "ouro")
        )
        expect { service.call }.to change { existing.reload.trust_level }.from("prata").to("ouro")
      end
    end

    context "when trust level is bronze" do
      before { allow(gateway).to receive(:fetch_token).and_return(bronze_oauth) }

      it "returns Result.failure" do
        expect(service.call).to be_failure
      end

      it "sets error to insufficient_trust_level" do
        expect(service.call.error).to eq("insufficient_trust_level")
      end

      it "does not create a user" do
        expect { service.call }.not_to change(User, :count)
      end
    end

    context "when Gov.br is down" do
      before { allow(gateway).to receive(:fetch_token).and_raise(Errors::GatewayError) }

      it "returns Result.failure" do
        expect(service.call).to be_failure
      end

      it "sets error to gateway_error" do
        expect(service.call.error).to eq("gateway_error")
      end
    end

    context "when the id_token is malformed" do
      before { allow(gateway).to receive(:fetch_token).and_raise(Errors::InvalidToken) }

      it "returns Result.failure" do
        expect(service.call).to be_failure
      end

      it "sets error to invalid_token" do
        expect(service.call.error).to eq("invalid_token")
      end
    end
  end
end
