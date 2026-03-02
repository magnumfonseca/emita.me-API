# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JwtEncoder do
  include ActiveSupport::Testing::TimeHelpers

  describe ".encode" do
    it "returns a JWT token string" do
      token = described_class.encode(42)
      expect(token).to be_a(String)
    end

    it "embeds the user_id in the payload" do
      token = described_class.encode(42)
      payload = described_class.decode(token)
      expect(payload["user_id"]).to eq(42)
    end

    it "sets expiry 24 hours from now" do
      travel_to(Time.current) do
        token = described_class.encode(42)
        payload = described_class.decode(token)
        expect(payload["exp"]).to eq(24.hours.from_now.to_i)
      end
    end
  end

  describe ".decode" do
    it "returns the full payload for a valid token" do
      token = described_class.encode(99)
      payload = described_class.decode(token)
      expect(payload).to include("user_id" => 99, "iat" => anything, "exp" => anything)
    end

    it "returns nil for an invalid token" do
      expect(described_class.decode("invalid.token.here")).to be_nil
    end

    it "returns nil for an expired token" do
      token = described_class.encode(42)
      travel_to(25.hours.from_now) do
        expect(described_class.decode(token)).to be_nil
      end
    end
  end
end
