# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    ERROR_MAP = {
      "insufficient_trust_level" => { code: ErrorCodes::INSUFFICIENT_TRUST_LEVEL, status: :forbidden,            message: "Insufficient trust level" },
      "gateway_error"            => { code: ErrorCodes::GATEWAY_ERROR,            status: :service_unavailable,  message: "External service unavailable" },
      "invalid_token"            => { code: ErrorCodes::INVALID_TOKEN,            status: :unauthorized,          message: "Invalid or malformed token" },
      "missing_code"             => { code: ErrorCodes::MISSING_CODE,             status: :unprocessable_entity,  message: "Authorization code is required" }
    }.freeze

    before_action :require_code_param, only: :create

    def create
      result = Auth::SignInService.new(code: params[:code]).call
      result.success? ? render_success(result.data) : render_failure(result.error)
    end

    private

    def require_code_param
      render_failure("missing_code") if params[:code].blank?
    end

    def render_success(user)
      enqueue_establishments_fetch(user)
      render json: success_payload(user), status: :created
    end

    def enqueue_establishments_fetch(user)
      FetchEstablishmentsJob.perform_later(user.id)
    end

    def success_payload(user)
      {
        success: true,
        data: UserSerializer.new(user).serializable_hash[:data],
        token: JwtEncoder.encode(user.id),
        message: "Authenticated successfully"
      }
    end

    def render_failure(error_key)
      mapping = ERROR_MAP.fetch(error_key, { code: ErrorCodes::INTERNAL_SERVER_ERROR, status: :internal_server_error, message: "An unexpected error occurred" })
      render json: {
        success: false,
        data: nil,
        error: { code: mapping[:code], message: mapping[:message], details: [] }
      }, status: mapping[:status]
    end
  end
end
