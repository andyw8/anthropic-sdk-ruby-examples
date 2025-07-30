require "bundler/setup"
require "dotenv/load"
require "anthropic"
require_relative "../../helpers/vcr"

client = Anthropic::Client.new
model = "claude-sonnet-4-0"

if __FILE__ == $0
  with_vcr do
    message = client.messages.create(
      model: model,
      max_tokens: 1000,
      messages: [
        {
          role: "user",
          content: "What is quantum computing? Answer in one sentence"
        }
      ]
    )

    puts message.content[0].text
  end
end
