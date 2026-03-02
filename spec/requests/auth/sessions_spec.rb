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
                 success: { type: :boolean, example: true },
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
                 },
                 token:   { type: :string, description: 'JWT Bearer token for subsequent authenticated requests' },
                 message: { type: :string }
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
                 success: { type: :boolean, example: false },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: ErrorCodes::INSUFFICIENT_TRUST_LEVEL },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:body) { { code: 'bronze_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("insufficient_trust_level"))
        end

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq(ErrorCodes::INSUFFICIENT_TRUST_LEVEL)
        end
      end

      response '503', 'Gov.br unavailable' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: ErrorCodes::GATEWAY_ERROR },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:body) { { code: 'any_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("gateway_error"))
        end

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq(ErrorCodes::GATEWAY_ERROR)
        end
      end

      response '401', 'invalid or malformed token returned by Gov.br' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: ErrorCodes::INVALID_TOKEN },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:body) { { code: 'malformed_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("invalid_token"))
        end

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq(ErrorCodes::INVALID_TOKEN)
        end
      end

      response '422', 'missing code parameter' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: ErrorCodes::MISSING_CODE },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:body) { {} }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq(ErrorCodes::MISSING_CODE)
        end
      end
    end
  end
end
