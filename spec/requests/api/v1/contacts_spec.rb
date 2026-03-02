# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Contacts", type: :request do
  let(:user) { create(:user) }
  let(:token) do
    now = Time.current.to_i
    JWT.encode({ user_id: user.id, iat: now, exp: now + 24.hours.to_i }, ENV.fetch("JWT_SECRET"), "HS256")
  end

  path "/api/v1/contacts" do
    get "List contacts for the current user" do
      tags     "Contacts"
      produces "application/json"
      security [ { bearerAuth: [] } ]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer JWT token"
      parameter name: :page, in: :query, type: :integer, required: false, description: "Page number"
      parameter name: :name, in: :query, type: :string,  required: false, description: "Filter by name"
      parameter name: :cpf,  in: :query, type: :string,  required: false, description: "Filter by CPF"
      parameter name: :cnpj, in: :query, type: :string,  required: false, description: "Filter by CNPJ"

      response "401", "returns unauthorized when Authorization header is missing" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string, example: "UNAUTHORIZED" },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:Authorization) { nil }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end

      response "401", "returns unauthorized when token is invalid" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:Authorization) { "Bearer invalid.token.here" }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end

      response "200", "returns contacts for page 1" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array, items: { type: :object } },
                 meta: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages:  { type: :integer },
                     total_count:  { type: :integer }
                   }
                 },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }

        before { create_list(:contact, 3, user: user) }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"].length).to eq(3)
          expect(body["meta"]["current_page"]).to eq(1)
        end
      end

      response "200", "returns contacts for page 2" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array, items: { type: :object } },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:page) { 2 }

        before { create_list(:contact, 30, user: user) }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["meta"]["current_page"]).to eq(2)
        end
      end

      response "200", "returns empty list when current user has no contacts" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"]).to be_empty
        end
      end

      response "200", "filters contacts by name" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array, items: { type: :object } },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:name) { "Alice" }

        before do
          create(:contact, user: user, name: "Alice Smith")
          create(:contact, user: user, name: "Bob Jones")
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"].length).to eq(1)
          expect(body["data"].first.dig("attributes", "name")).to include("Alice")
        end
      end

      response "200", "filters contacts by cpf" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array, items: { type: :object } },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:cpf) { "01234567890" }

        before do
          create(:contact, user: user, cpf: "01234567890")
          create(:contact, user: user, cpf: nil, cnpj: "00394460005887")
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"].length).to eq(1)
          expect(body["data"].first.dig("attributes", "cpf")).to eq("01234567890")
        end
      end

      response "200", "filters contacts by cnpj" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array, items: { type: :object } },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:cnpj) { "00394460005887" }

        before do
          create(:contact, user: user, cpf: "01234567890")
          create(:contact, user: user, cpf: nil, cnpj: "00394460005887")
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"].length).to eq(1)
          expect(body["data"].first.dig("attributes", "cnpj")).to eq("00394460005887")
        end
      end

      response "200", "returns empty when filter has no match" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :array },
                 meta:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:name) { "Nonexistent Name" }

        before { create(:contact, user: user, name: "Alice Smith") }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"]).to be_empty
        end
      end
    end

    post "Create a contact for the current user" do
      tags     "Contacts"
      consumes "application/json"
      produces "application/json"
      security [ { bearerAuth: [] } ]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer JWT token"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          contact: {
            type: :object,
            properties: {
              name:  { type: :string },
              email: { type: :string },
              phone: { type: :string },
              cpf:   { type: :string },
              cnpj:  { type: :string }
            },
            required: %w[name]
          }
        }
      }

      response "201", "creates a contact with name, email, cpf" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object },
                 message: { type: :string }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Alice Smith", email: "alice@example.com", cpf: "01234567890" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
          expect(parsed["data"]["attributes"]["name"]).to eq("Alice Smith")
        end
      end

      response "201", "creates a contact with name, phone, cnpj" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object },
                 message: { type: :string }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Bob Jones", phone: "11987654321", cnpj: "00394460005887" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
          expect(parsed["data"]["attributes"]["cnpj"]).to eq("00394460005887")
        end
      end

      response "422", "returns error when name is empty" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error: {
                   type: :object,
                   properties: {
                     code:    { type: :string },
                     message: { type: :string },
                     details: { type: :array, items: { type: :string } }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "", email: "alice@example.com", cpf: "01234567890" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response "422", "returns error when cpf and cnpj are empty" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Alice Smith", email: "alice@example.com" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response "422", "returns error when email and phone are empty" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Alice Smith", cpf: "01234567890" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response "422", "returns error when cpf is invalid" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Alice Smith", email: "alice@example.com", cpf: "00000000000" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response "422", "returns validation error(s) for invalid or missing contact fields (e.g. cpf/cnpj, phone, email)" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "Bob Jones", phone: "11987654321", cnpj: "00000000000000" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end
    end
  end

  path "/api/v1/contacts/{id}" do
    parameter name: :id, in: :path, type: :string, required: true, description: "Contact UUID"

    get "Show a contact" do
      tags     "Contacts"
      produces "application/json"
      security [ { bearerAuth: [] } ]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer JWT token"

      response "200", "returns a contact" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object },
                 message: { type: :string, nullable: true }
               }

        let(:contact) { create(:contact, user: user) }
        let(:id) { contact.id }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
          expect(parsed["data"]["id"]).to eq(contact.id)
        end
      end

      response "404", "returns error when contact is not found" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:id) { "00000000-0000-0000-0000-000000000000" }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("NOT_FOUND")
        end
      end
    end

    patch "Update a contact" do
      tags     "Contacts"
      consumes "application/json"
      produces "application/json"
      security [ { bearerAuth: [] } ]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer JWT token"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          contact: {
            type: :object,
            properties: {
              name:  { type: :string },
              email: { type: :string },
              phone: { type: :string },
              cpf:   { type: :string },
              cnpj:  { type: :string }
            }
          }
        }
      }

      response "200", "updates a contact successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object },
                 message: { type: :string }
               }

        let(:contact) { create(:contact, user: user, name: "Old Name") }
        let(:id) { contact.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { name: "New Name" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
          expect(parsed["data"]["attributes"]["name"]).to eq("New Name")
        end
      end

      response "422", "returns error when cpf or cnpj becomes invalid" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:contact) { create(:contact, user: user) }
        let(:id) { contact.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { cpf: "00000000000" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response "422", "returns error when update removes phone or email leaving both empty" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 error:   { type: :object }
               }

        let(:contact) { create(:contact, user: user, phone: "11987654321", email: nil) }
        let(:id) { contact.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { contact: { phone: "", email: "" } } }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be false
          expect(parsed["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end
    end

    delete "Delete a contact" do
      tags     "Contacts"
      produces "application/json"
      security [ { bearerAuth: [] } ]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer JWT token"

      response "200", "returns success when deleting a found contact" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 message: { type: :string }
               }

        let(:contact) { create(:contact, user: user) }
        let(:id) { contact.id }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
        end
      end

      response "200", "returns success when deleting a not found contact" do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 data:    { type: :object, nullable: true },
                 message: { type: :string }
               }

        let(:id) { "00000000-0000-0000-0000-000000000000" }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(parsed["success"]).to be true
        end
      end
    end
  end
end
