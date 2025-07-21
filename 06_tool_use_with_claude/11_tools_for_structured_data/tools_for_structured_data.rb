require "dotenv/load"
require "anthropic"
require "json"

# Load env variables and create client
CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    role: :user,
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: :assistant,
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil, tool_choice: nil)
  params = {
    model: MODEL,
    max_tokens: 1000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  params[:tool_choice] = tool_choice if tool_choice
  params[:tools] = tools if tools
  params[:system] = system if system

  CLIENT.messages.create(**params)
end

def text_from_message(message)
  message.content.select { |block| block.type == :text }.map(&:text).join("\n")
end

# Tools and Schemas
ARTICLE_SUMMARY_SCHEMA = {
  name: "article_summary",
  description: "Creates a summary of an article with its key insights. Use this tool when you need to generate a structured summary of an article, research paper, or any textual content. The tool requires the article's title, author name, and a list of the most important insights or takeaways from the content. Each insight should be a concise statement capturing a significant point from the article.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "The title of the article being summarized."
      },
      author: {
        type: "string",
        description: "The name of the author who wrote the article."
      },
      key_insights: {
        type: "array",
        items: {type: "string"},
        description: "A list of the most important takeaways or insights from the article. Each insight should be a complete, concise statement."
      }
    },
    required: %w[title author key_insights]
  }
}

# Example usage
if __FILE__ == $0
  messages = []
  add_user_message(
    messages,
    "Write a one-paragraph scholarly article about computer science. Include a title and author name."
  )
  response = chat(messages)
  article_text = text_from_message(response)
  puts "Article text: #{article_text}"

  # Example usage with article summary tool
  messages = []
  add_user_message(messages, article_text)
  response = chat(
    messages,
    tools: [ARTICLE_SUMMARY_SCHEMA],
    tool_choice: {type: "tool", name: "article_summary"}
  )
  puts response.content[0].input
end
