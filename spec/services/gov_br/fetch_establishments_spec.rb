# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GovBr::FetchEstablishments do
  let(:user)         { create(:user) }
  let(:access_token) { "FAKE_TOKEN" }
  let(:client)       { instance_double(GovBr::ContribuintesClient) }

  subject(:service) { described_class.new(user: user, access_token: access_token, client: client) }

  let(:success_response) do
    double("HTTParty::Response",
      server_error?: false,
      unauthorized?: false,
      parsed_response: {
        "cpf" => "12345678900",
        "estabelecimentos" => [
          {
            "cnpj"        => "00394460005887",
            "razaoSocial" => "Empresa Exemplo LTDA",
            "nomeFantasia" => "Exemplo",
            "municipio"   => "3550308",
            "uf"          => "SP",
            "perfis"      => [ "EMISSOR", "CONSULTA" ]
          },
          {
            "cnpj"        => "11222333000181",
            "razaoSocial" => "Prestadora Servicos ME",
            "nomeFantasia" => "Servicos ME",
            "municipio"   => "3304557",
            "uf"          => "RJ",
            "perfis"      => [ "EMISSOR" ]
          }
        ]
      }
    )
  end

  let(:empty_response) do
    double("HTTParty::Response",
      server_error?: false,
      unauthorized?: false,
      parsed_response: { "cpf" => "12345678900", "estabelecimentos" => [] }
    )
  end

  let(:unauthorized_response) do
    double("HTTParty::Response",
      server_error?: false,
      unauthorized?: true,
      parsed_response: { "error" => "unauthorized" }
    )
  end

  let(:server_error_response) do
    double("HTTParty::Response",
      server_error?: true,
      unauthorized?: false,
      parsed_response: { "error" => "internal_server_error" }
    )
  end

  describe "#call" do
    context "when API returns establishments" do
      before { allow(client).to receive(:fetch_establishments).and_return(success_response) }

      it "returns Result.success" do
        expect(service.call).to be_success
      end

      it "persists all establishments" do
        expect { service.call }.to change(Establishment, :count).by(2)
      end

      it "sets authorized true for establishments with EMISSOR" do
        service.call
        expect(Establishment.find_by(cnpj: "00394460005887").authorized).to be true
      end

      it "upserts on re-fetch without duplicating records" do
        service.call
        expect { service.call }.not_to change(Establishment, :count)
      end
    end

    context "when API returns empty list" do
      before { allow(client).to receive(:fetch_establishments).and_return(empty_response) }

      it "returns Result.success with empty array" do
        result = service.call
        expect(result).to be_success
        expect(result.data).to eq([])
      end
    end

    context "when API returns 401" do
      before { allow(client).to receive(:fetch_establishments).and_return(unauthorized_response) }

      it "returns Result.failure with unauthorized" do
        expect(service.call.error).to eq("unauthorized")
      end
    end

    context "when API returns 500" do
      before { allow(client).to receive(:fetch_establishments).and_return(server_error_response) }

      it "returns Result.failure with gateway_error" do
        expect(service.call.error).to eq("gateway_error")
      end
    end
  end
end
