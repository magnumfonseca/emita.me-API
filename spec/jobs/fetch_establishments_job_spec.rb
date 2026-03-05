# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FetchEstablishmentsJob, type: :job do
  let(:user)         { create(:user) }
  let(:access_token) { "FAKE_TOKEN" }

  it "calls GovBr::FetchEstablishments with the correct arguments" do
    allow(GovBr::FetchEstablishments).to receive(:call)
    described_class.new.perform(user.id, access_token)
    expect(GovBr::FetchEstablishments).to have_received(:call)
      .with(user: user, access_token: access_token)
  end

  it "is enqueued on the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
