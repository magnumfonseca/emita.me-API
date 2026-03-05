# frozen_string_literal: true

FactoryBot.define do
  factory :establishment do
    association :user
    cnpj             { "00394460005887" }
    razao_social     { "Empresa Exemplo LTDA" }
    nome_fantasia    { "Exemplo" }
    municipio_codigo { "3550308" }
    uf               { "SP" }
    perfis           { [ "EMISSOR", "CONSULTA" ] }

    trait :consulta_only do
      perfis { [ "CONSULTA" ] }
    end
  end
end
