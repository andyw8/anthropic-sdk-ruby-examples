require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<X-API-KEY>') { |interaction| interaction.request.headers['X-Api-Key']&.first }
end

def with_vcr(&block)
  cassette = Pathname(__FILE__).split.last.to_s.sub(".rb", "")
  VCR.use_cassette(cassette) do
    yield
  end
end
