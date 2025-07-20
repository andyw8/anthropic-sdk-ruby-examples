require "dotenv/load"
require "anthropic"

CLIENT = Anthropic::Client.new
MODEL = "claude-3-7-sonnet-latest"

def add_user_message(messages, message)
  user_message = {
    role: :user,
    content: message.is_a?(Anthropic::Messages::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: :assistant,
    content: message.is_a?(Anthropic::Messages::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil)
  params = {
    model: MODEL,
    max_tokens: 1000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  params[:tools] = tools if tools
  params[:system] = system if system

  CLIENT.messages(parameters: params)
end

def text_from_message(message)
  message.content
    .select { |block| block.type == "text" }
    .map(&:text)
    .join("\n")
end

require "date"

def add_duration_to_datetime(datetime_str, duration: 0, unit: "days", input_format: "%Y-%m-%d")
  date = Date.strptime(datetime_str, input_format)

  case unit
  when "seconds"
    date + Rational(duration, 86400) # seconds to days
  when "minutes"
    date + Rational(duration, 1440) # minutes to days
  when "hours"
    date + Rational(duration, 24) # hours to days
  when "days"
    date + duration
  else
    raise ArgumentError, "Unsupported unit: #{unit}"
  end
end