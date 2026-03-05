# frozen_string_literal: true

class FetchEstablishmentsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    GovBr::FetchEstablishments.call(user: user, access_token: user.gov_br_access_token)
    user.update!(gov_br_access_token: nil)
  end
end
