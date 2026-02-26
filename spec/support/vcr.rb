# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body]
  }

  # Filter sensitive data
  config.filter_sensitive_data("<GITHUB_TOKEN>") { ENV.fetch("GITHUB_TOKEN", nil) }
  config.filter_sensitive_data("<BEARER_TOKEN>") do |interaction|
    interaction.request.headers["Authorization"]&.first&.sub(/^Bearer /, "")
  end
end
