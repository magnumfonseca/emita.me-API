# frozen_string_literal: true

class FetchEstablishmentsJob < ApplicationJob
  queue_as :default

  def perform(user_id, access_token)
    user = User.find(user_id)
    GovBr::FetchEstablishments.call(user: user, access_token: access_token)
  end
end
