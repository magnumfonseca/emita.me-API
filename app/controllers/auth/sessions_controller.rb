# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    ERROR_STATUS_MAP = {
      "insufficient_trust_level" => :forbidden,
      "gateway_error"            => :service_unavailable,
      "invalid_token"            => :unauthorized,
      "missing_code"             => :unprocessable_entity
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
      render json: UserSerializer.new(user).serializable_hash, status: :created
    end

    def render_failure(error)
      render json: { error: error }, status: ERROR_STATUS_MAP.fetch(error, :internal_server_error)
    end
  end
end
