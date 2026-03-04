# frozen_string_literal: true

module Nfse
  class Client
    include HTTParty

    def initialize(cert_path: ENV.fetch("NFSE_CERT_PATH"),
                   cert_password: ENV.fetch("NFSE_CERT_PASSWORD"))
      @cert_path     = cert_path
      @cert_password = cert_password
    end

    def post(payload)
      self.class.post(
        ENV.fetch("NFSE_API_URL"),
        body:         payload.to_json,
        headers:      { "Content-Type" => "application/json" },
        p12:          File.read(@cert_path),
        p12_password: @cert_password
      )
    end
  end
end
