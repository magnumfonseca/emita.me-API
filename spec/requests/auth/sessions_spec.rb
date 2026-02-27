# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth::Sessions', type: :request do
  path '/auth/callback' do
    post 'Authenticate with Gov.br OAuth code' do
      tags        'Authentication'
      consumes    'application/json'
      produces    'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          code: { type: :string, description: 'Authorization code from Gov.br' }
        },
        required: [ "code" ]
      }

      response '201', 'successful login — prata or ouro user' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id:   { type: :string },
                     type: { type: :string },
                     attributes: {
                       type: :object,
                       properties: {
                         name:        { type: :string },
                         email:       { type: :string },
                         cpf:         { type: :string },
                         trust_level: { type: :string }
                       }
                     }
                   }
                 }
               }

        let(:user) { create(:user) }
        let(:body) { { code: 'valid_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.success(user))
        end

        run_test!
      end

      response '403', 'insufficient trust level (bronze user)' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'insufficient_trust_level' }
               }

        let(:body) { { code: 'bronze_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("insufficient_trust_level"))
        end

        run_test!
      end

      response '503', 'Gov.br unavailable' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'gateway_error' }
               }

        let(:body) { { code: 'any_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("gateway_error"))
        end

        run_test!
      end
    end
  end
end
