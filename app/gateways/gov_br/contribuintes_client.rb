# frozen_string_literal: true

module GovBr
  class ContribuintesClient
    include HTTParty

    def initialize(access_token:,
                   cert_path: ENV.fetch("NFSE_CERT_PATH"),
                   cert_password: ENV.fetch("NFSE_CERT_PASSWORD"))
      @access_token  = access_token
      @cert          = File.read(cert_path)
      @cert_password = cert_password
    end

    def fetch_establishments
      self.class.get(
        "#{base_url}/contribuintes/v1/estabelecimentos",
        headers:      request_headers,
        p12:          @cert,
        p12_password: @cert_password
      )
    end

    private

    def base_url
      ENV.fetch("GOVBR_CONTRIBUINTES_API_URL", "https://adn.producaorestrita.nfse.gov.br")
    end

    def request_headers
      {
        "Authorization" => "Bearer #{@access_token}",
        "Accept"        => "application/json",
        "Content-Type"  => "application/json"
      }
    end
  end
end
