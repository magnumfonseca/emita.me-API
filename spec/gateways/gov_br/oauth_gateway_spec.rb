# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GovBr::OauthGateway do
  subject(:gateway) { described_class.new }

  before do
    stub_const("ENV", ENV.to_h.merge(
      "GOVBR_CLIENT_ID"     => "test_client_id",
      "GOVBR_CLIENT_SECRET" => "test_client_secret",
      "GOVBR_REDIRECT_URI"  => "http://localhost/callback"
    ))
  end

  describe "#fetch_token" do
    context "when Gov.br returns 200 with prata user",
            vcr: { cassette_name: "govbr/success" } do
      it "returns an OauthResponse" do
        expect(gateway.fetch_token(code: "auth_code")).to be_a(OauthResponse)
      end

      it "returns a valid response" do
        expect(gateway.fetch_token(code: "auth_code")).to be_valid
      end

      it "maps cpf from the JWT sub claim" do
        expect(gateway.fetch_token(code: "auth_code").cpf).to eq("12345678900")
      end
    end

    context "when Gov.br returns 200 with bronze user",
            vcr: { cassette_name: "govbr/bronze" } do
      it "returns an OauthResponse" do
        expect(gateway.fetch_token(code: "auth_code")).to be_a(OauthResponse)
      end

      it "returns an invalid response" do
        expect(gateway.fetch_token(code: "auth_code")).not_to be_valid
      end
    end

    context "when Gov.br returns 500",
            vcr: { cassette_name: "govbr/server_error" } do
      it "raises Errors::GatewayError" do
        expect { gateway.fetch_token(code: "auth_code") }
          .to raise_error(Errors::GatewayError)
      end
    end
  end
end
