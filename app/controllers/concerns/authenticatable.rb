# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def current_user
    @current_user ||= find_user_from_token
  end

  private

  def authenticate_user!
    render_unauthorized unless current_user
  end

  def find_user_from_token
    token = request.headers["Authorization"]&.split(" ")&.last
    return unless token

    payload = JwtEncoder.decode(token)
    User.find_by(id: payload["user_id"]) if payload
  end

  def render_unauthorized
    render json: {
      success: false,
      data: nil,
      error: { code: ErrorCodes::UNAUTHORIZED, message: "Unauthorized", details: [] }
    }, status: :unauthorized
  end
end
