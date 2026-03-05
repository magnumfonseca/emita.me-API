# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FetchEstablishmentsJob, type: :job do
  let(:user) { create(:user, gov_br_access_token: "FAKE_TOKEN") }

  it "calls GovBr::FetchEstablishments with the token stored on the user" do
    allow(GovBr::FetchEstablishments).to receive(:call)
    described_class.new.perform(user.id)
    expect(GovBr::FetchEstablishments).to have_received(:call)
      .with(user: user, access_token: "FAKE_TOKEN")
  end

  it "clears the token from the user after calling the service" do
    allow(GovBr::FetchEstablishments).to receive(:call)
    described_class.new.perform(user.id)
    expect(user.reload.gov_br_access_token).to be_nil
  end

  it "is enqueued on the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
