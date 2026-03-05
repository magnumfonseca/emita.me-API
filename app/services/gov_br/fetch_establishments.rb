# frozen_string_literal: true

module GovBr
  class FetchEstablishments
    def self.call(user:, access_token:, client: nil)
      new(user: user, access_token: access_token, client: client).call
    end

    def initialize(user:, access_token:, client: nil)
      @user   = user
      @client = client || GovBr::ContribuintesClient.new(access_token: access_token)
    end

    def call
      response = @client.fetch_establishments
      return Result.failure("gateway_error") if response.server_error?
      return Result.failure("unauthorized")  if response.unauthorized?

      Result.success(persist_establishments(parse(response)))
    rescue StandardError
      Result.failure("gateway_error")
    end

    private

    def parse(response)
      response.parsed_response.fetch("estabelecimentos", [])
    end

    def persist_establishments(data)
      data.map { |attrs| upsert(attrs) }
    end

    def upsert(attrs)
      Establishment.find_or_initialize_by(user: @user, cnpj: attrs["cnpj"]).tap do |e|
        e.update!(establishment_attributes(attrs))
      end
    end

    def establishment_attributes(attrs)
      {
        razao_social:     attrs["razaoSocial"],
        nome_fantasia:    attrs["nomeFantasia"],
        municipio_codigo: attrs["municipio"],
        uf:               attrs["uf"],
        perfis:           attrs["perfis"] || []
      }
    end
  end
end
