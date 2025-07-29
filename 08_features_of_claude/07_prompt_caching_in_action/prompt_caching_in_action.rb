require "dotenv/load"
require "anthropic"

CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    role: "user",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: "assistant",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil, thinking: false, thinking_budget: 1024)
  params = {
    model: MODEL,
    max_tokens: 4000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  if thinking
    params[:thinking] = {
      type: "enabled",
      budget_tokens: thinking_budget
    }
  end

  if tools
    tools_clone = tools.dup
    last_tool = tools_clone.last.dup
    last_tool[:cache_control] = {type: "ephemeral"}
    tools_clone[-1] = last_tool
    params[:tools] = tools_clone
  end

  if system
    params["system"] = [
      {
        type: "text",
        text: system,
        cache_control: {type: "ephemeral"}
      }
    ]
  end

  CLIENT.messages.create(**params)
end

def text_from_message(message)
  message.content.select { |block| block.type == "text" }.map(&:text).join("\n")
end

# Prompt with ~6k Tokens
CODE_PROMPT = File.read(File.join(__dir__, "code_prompt.txt"))

# Tool Schemas, ~1.7k tokens
require_relative "tool_schemas"

tools = [
  DB_QUERY_SCHEMA,
  ADD_DURATION_TO_DATETIME_SCHEMA,
  SET_REMINDER_SCHEMA,
  GET_CURRENT_DATETIME_SCHEMA
]
messages = []

add_user_message(messages, "what's 1+1")

puts chat(messages, tools: tools, system: CODE_PROMPT)
