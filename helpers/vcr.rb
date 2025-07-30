require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<X-API-KEY>") { |interaction| interaction.request.headers["X-Api-Key"]&.first }
  config.filter_sensitive_data("<AUTHORIZATION>") { |interaction| interaction.request.headers["Authorization"]&.first }
end

def VCR.use_cassette(cassette_name, &block)
  VCR.use_cassette(cassette_name) do
    yield
  end
end
